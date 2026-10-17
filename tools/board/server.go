package main

import (
	"bytes"
	"crypto/rand"
	"crypto/subtle"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

//go:embed ui/index.html
var indexHTML string

const (
	githubEvery = 60 * time.Second
	orcaEvery   = 10 * time.Second
	eventsEvery = time.Second
	retryAfter  = 10 * time.Minute
)

type server struct {
	cfg   Config
	token string

	mu          sync.Mutex
	tail        *tailer
	events      []Event
	issues      map[int]*Issue
	githubAt    time.Time
	githubErr   string
	wts         []OrcaWorktree
	orcaErr     string
	applied     map[string]card
	attempts    map[int]time.Time
	notices     map[int]string
	dispatching bool
	snapshot    []byte
	subs        map[chan []byte]struct{}
}

func newServer(cfg Config) (*server, error) {
	b := make([]byte, 24)
	if _, err := rand.Read(b); err != nil {
		return nil, err
	}
	return &server{
		cfg:      cfg,
		token:    hex.EncodeToString(b),
		tail:     &tailer{path: eventsPath()},
		applied:  map[string]card{},
		attempts: map[int]time.Time{},
		notices:  map[int]string{},
		subs:     map[chan []byte]struct{}{},
	}, nil
}

func serve(cfg Config) error {
	if err := ensureStateDir(); err != nil {
		return err
	}
	s, err := newServer(cfg)
	if err != nil {
		return err
	}
	s.pollEvents()
	s.pollOrca()
	s.pollGitHub()
	s.refresh()
	go s.loop()

	addr := fmt.Sprintf("127.0.0.1:%d", cfg.Port)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	log.Printf("board: listening on http://%s/", addr)
	return http.Serve(ln, s.handler())
}

func (s *server) loop() {
	ev := time.NewTicker(eventsEvery)
	or := time.NewTicker(orcaEvery)
	gh := time.NewTicker(githubEvery)
	for {
		select {
		case <-ev.C:
			if !s.pollEvents() {
				continue
			}
		case <-or.C:
			s.pollOrca()
		case <-gh.C:
			s.pollGitHub()
		}
		s.refresh()
	}
}

func (s *server) pollEvents() bool {
	evs, reset, err := s.tail.read()
	s.mu.Lock()
	defer s.mu.Unlock()
	if err != nil {
		log.Printf("board: read events: %v", err)
		return false
	}
	if reset {
		s.events = nil
	}
	s.events = append(s.events, evs...)
	return reset || len(evs) > 0
}

func (s *server) pollOrca() {
	wts, err := orcaPS()
	s.mu.Lock()
	defer s.mu.Unlock()
	if err != nil {
		s.orcaErr = err.Error()
		return
	}
	s.wts, s.orcaErr = wts, ""
}

func (s *server) pollGitHub() {
	issues, err := fetchIssues(s.cfg.Repo)
	s.mu.Lock()
	defer s.mu.Unlock()
	if err != nil {
		s.githubErr = err.Error()
		return
	}
	s.issues, s.githubAt, s.githubErr = issues, time.Now(), ""
}

// refresh rebuilds the snapshot, pushes it to SSE clients, reflects it on the
// Orca cards and starts ready Epic children.
func (s *server) refresh() {
	s.mu.Lock()
	issues := s.issues
	evs := append([]Event(nil), s.events...)
	wts := s.wts
	now := time.Now()
	if issues == nil {
		issues = map[int]*Issue{}
	}
	snap := build(issues, evs, wts, s.cfg.Short(), now)
	snap.GitHubAt, snap.GitHubError, snap.OrcaError = s.githubAt, s.githubErr, s.orcaErr
	if s.tail.bad > 0 {
		snap.Notices = append(snap.Notices, fmt.Sprintf("events.jsonl に読めない行が %d 行ある（読み飛ばした）", s.tail.bad))
	}
	for n, msg := range s.notices {
		snap.Notices = append(snap.Notices, fmt.Sprintf("#%d: %s", n, msg))
	}
	b, _ := json.Marshal(snap)
	changed := !bytes.Equal(b, s.snapshot)
	s.snapshot = b
	if changed {
		for ch := range s.subs {
			select {
			case ch <- b:
			default:
			}
		}
	}
	var cards map[string]card
	if s.orcaErr == "" && s.issues != nil {
		cards = desiredCards(issues, evs, wts, s.cfg.Short(), now)
	}
	var ready []int
	if s.issues != nil && s.githubErr == "" && s.orcaErr == "" && !snap.Held && !s.dispatching {
		for _, n := range snap.AutoDispatch {
			if t, ok := s.attempts[n]; ok && now.Sub(t) < retryAfter {
				continue
			}
			ready = append(ready, n)
		}
	}
	if len(ready) > 0 {
		s.dispatching = true
		for _, n := range ready {
			s.attempts[n] = now
		}
	}
	s.mu.Unlock()

	for path, c := range cards {
		s.mu.Lock()
		prev, ok := s.applied[path]
		s.mu.Unlock()
		if ok && prev == c {
			continue
		}
		if err := orcaSetCard(path, c); err != nil {
			log.Printf("board: set card %s: %v", path, err)
			continue
		}
		s.mu.Lock()
		s.applied[path] = c
		s.mu.Unlock()
	}
	if len(ready) > 0 {
		go s.autoDispatch(ready)
	}
}

func (s *server) autoDispatch(ns []int) {
	for _, n := range ns {
		_, err := dispatch(s.cfg, n, "board")
		s.mu.Lock()
		switch {
		case err == nil, errors.Is(err, errAlreadyDispatched):
			delete(s.notices, n)
		default:
			s.notices[n] = "自動 dispatch に失敗: " + err.Error()
			log.Printf("board: auto dispatch #%d: %v", n, err)
		}
		s.mu.Unlock()
	}
	s.mu.Lock()
	s.dispatching = false
	s.mu.Unlock()
	s.pollEvents()
	s.pollOrca()
	s.refresh()
}

func (s *server) allowedHost(host string) bool {
	return host == fmt.Sprintf("127.0.0.1:%d", s.cfg.Port) || host == fmt.Sprintf("localhost:%d", s.cfg.Port)
}

func (s *server) handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		fmt.Fprint(w, strings.Replace(indexHTML, "{{TOKEN}}", s.token, 1))
	})
	mux.HandleFunc("/api/tasks", func(w http.ResponseWriter, r *http.Request) {
		s.mu.Lock()
		b := s.snapshot
		s.mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		w.Write(b)
	})
	mux.HandleFunc("/events", s.handleSSE)
	mux.HandleFunc("/api/dispatch/", s.handleDispatch)
	// Host is checked on every request: a DNS-rebound page could otherwise read
	// GET / and with it the dispatch token.
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !s.allowedHost(r.Host) {
			http.Error(w, "forbidden host", http.StatusForbidden)
			return
		}
		mux.ServeHTTP(w, r)
	})
}

func (s *server) handleSSE(w http.ResponseWriter, r *http.Request) {
	fl, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming unsupported", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-store")
	ch := make(chan []byte, 4)
	s.mu.Lock()
	s.subs[ch] = struct{}{}
	first := s.snapshot
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		delete(s.subs, ch)
		s.mu.Unlock()
	}()
	fmt.Fprintf(w, "retry: 3000\ndata: %s\n\n", first)
	fl.Flush()
	ping := time.NewTicker(25 * time.Second)
	defer ping.Stop()
	for {
		select {
		case <-r.Context().Done():
			return
		case b := <-ch:
			fmt.Fprintf(w, "data: %s\n\n", b)
			fl.Flush()
		case <-ping.C:
			fmt.Fprint(w, ": ping\n\n")
			fl.Flush()
		}
	}
}

// checkDispatchRequest guards the only write API. The server listens on
// 127.0.0.1, but any page open in a browser can still POST to localhost, so
// the request must come from the board page itself and carry its token.
func (s *server) checkDispatchRequest(r *http.Request) (int, error) {
	if r.Method != http.MethodPost {
		return 0, errors.New("POST only")
	}
	origin := r.Header.Get("Origin")
	if origin != "http://"+r.Host {
		return 0, fmt.Errorf("origin %q is not the board", origin)
	}
	if site := r.Header.Get("Sec-Fetch-Site"); site != "" && site != "same-origin" {
		return 0, fmt.Errorf("sec-fetch-site %q", site)
	}
	if subtle.ConstantTimeCompare([]byte(r.Header.Get("X-Board-Token")), []byte(s.token)) != 1 {
		return 0, errors.New("bad token")
	}
	n, err := strconv.Atoi(strings.TrimPrefix(r.URL.Path, "/api/dispatch/"))
	if err != nil || n <= 0 {
		return 0, errors.New("bad issue number")
	}
	return n, nil
}

func (s *server) handleDispatch(w http.ResponseWriter, r *http.Request) {
	n, err := s.checkDispatchRequest(r)
	if err != nil {
		http.Error(w, err.Error(), http.StatusForbidden)
		return
	}
	// Re-check against fresh data: the button may be stale.
	s.pollEvents()
	s.pollOrca()
	s.pollGitHub()
	s.mu.Lock()
	issues := s.issues
	evs := append([]Event(nil), s.events...)
	wts := s.wts
	s.mu.Unlock()
	if issues == nil {
		http.Error(w, "GitHub の情報をまだ取得できていない", http.StatusServiceUnavailable)
		return
	}
	snap := build(issues, evs, wts, s.cfg.Short(), time.Now())
	allowed := false
	for _, row := range snap.Rows {
		if row.Number == n && row.Kind == "task" && row.CanDispatch {
			allowed = true
		}
	}
	if !allowed {
		http.Error(w, fmt.Sprintf("#%d は未着手の Task ではない", n), http.StatusConflict)
		return
	}
	path, err := dispatch(s.cfg, n, "human")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	s.pollEvents()
	s.pollOrca()
	s.refresh()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"issue": n, "worktree": path})
}
