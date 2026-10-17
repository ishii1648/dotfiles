package main

import (
	"encoding/json"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"
)

var now = time.Date(2026, 10, 18, 12, 0, 0, 0, time.Local)

func ev(issue int, typ string, at time.Time) Event {
	return Event{At: at, Issue: issue, By: "t", Type: typ}
}

func issue(n int, labels ...string) *Issue {
	return &Issue{Number: n, Title: "t", State: "OPEN", Labels: labels, CreatedAt: now.Add(-24 * time.Hour)}
}

func findRow(t *testing.T, rows []Row, n int) Row {
	t.Helper()
	for _, r := range rows {
		if r.Number == n {
			return r
		}
		for _, c := range r.Children {
			if c.Number == n {
				return c
			}
		}
	}
	t.Fatalf("row #%d not found", n)
	return Row{}
}

func TestTaskStates(t *testing.T) {
	closed := issue(1)
	closed.State = "CLOSED"
	blocked := issue(2)
	blocked.BlockedBy = []IssueRef{{Number: 9, State: "OPEN"}}
	issues := map[int]*Issue{1: closed, 2: blocked, 3: issue(3), 4: issue(4), 5: issue(5), 6: issue(6)}
	evs := []Event{
		ev(2, "dispatched", now), // open blocker still wins
		ev(4, "dispatched", now), ev(4, "question", now),
		ev(5, "dispatched", now), ev(5, "pr", now), ev(5, "revise", now),
		ev(6, "dispatched", now.Add(-4*24*time.Hour)),
	}
	snap := build(issues, evs, nil, "hub", now)
	cases := map[int]string{1: stDone, 2: stBlocked, 3: stTodo, 4: stWaiting, 5: stWorking, 6: stWorking}
	for n, want := range cases {
		if got := findRow(t, snap.Rows, n).State; got != want {
			t.Errorf("#%d state = %s, want %s", n, got, want)
		}
	}
	if !findRow(t, snap.Rows, 6).Stale {
		t.Error("#6 should be stale after 4 days without events")
	}
	if !findRow(t, snap.Rows, 3).CanDispatch || findRow(t, snap.Rows, 4).CanDispatch {
		t.Error("only untouched open tasks can be dispatched")
	}
	if findRow(t, snap.Rows, 4).TodayCount != 1 {
		t.Error("#4 moved today")
	}
}

func TestEpicAutoDispatchAndHold(t *testing.T) {
	epic := issue(10, labelEpic)
	issues := map[int]*Issue{10: epic}
	for n := 11; n <= 13; n++ {
		c := issue(n)
		c.Parent = 10
		issues[n] = c
		epic.SubIssues = append(epic.SubIssues, IssueRef{Number: n, State: "OPEN"})
	}
	issues[13].BlockedBy = []IssueRef{{Number: 12, State: "OPEN"}}
	snap := build(issues, []Event{ev(11, "dispatched", now)}, nil, "hub", now)
	if len(snap.AutoDispatch) != 1 || snap.AutoDispatch[0] != 12 || snap.Held {
		t.Fatalf("auto dispatch = %v held=%v, want [12]", snap.AutoDispatch, snap.Held)
	}
	r := findRow(t, snap.Rows, 10)
	if r.Kind != "epic" || len(r.Children) != 3 || r.State != stWorking {
		t.Fatalf("epic row = %+v", r)
	}

	for n := 20; n < 25; n++ {
		c := issue(n)
		c.Parent = 10
		issues[n] = c
	}
	snap = build(issues, nil, nil, "hub", now)
	if !snap.Held {
		t.Fatalf("%d ready children should be held", len(snap.AutoDispatch))
	}
	if got := findRow(t, snap.Rows, 20); got.State != stWaiting || got.Reason != "起動の確認" {
		t.Fatalf("held child = %s %q", got.State, got.Reason)
	}
}

func TestProjectPhase(t *testing.T) {
	p := issue(80, labelProject)
	p.Body = "## 目標\n\n地図の読み込みを改善する\n\n## 次に決めること\n- 分割案を確認する\n"
	research := issue(81, labelResearch)
	research.Parent = 80
	issues := map[int]*Issue{80: p, 81: research}
	snap := build(issues, []Event{ev(81, "dispatched", now), ev(81, "result", now)}, nil, "hub", now)
	pv := snap.Projects[0]
	if pv.Phase != 1 || pv.Goal != "地図の読み込みを改善する" || pv.NextLabel != "次に決めること" || pv.Next != "分割案を確認する" {
		t.Fatalf("project = %+v", pv)
	}
	epic := issue(82, labelEpic)
	epic.Parent = 80
	issues[82] = epic
	if got := build(issues, nil, nil, "hub", now).Projects[0].Phase; got != 2 {
		t.Fatalf("phase with open epic = %d, want 2", got)
	}
	epic.State = "CLOSED"
	if got := build(issues, nil, nil, "hub", now).Projects[0].Phase; got != 3 {
		t.Fatalf("phase with all work closed = %d, want 3", got)
	}
}

func TestDesiredCards(t *testing.T) {
	issues := map[int]*Issue{42: issue(42), 57: issue(57)}
	wts := []OrcaWorktree{
		{Path: "/w/42", Repo: "hub", LinkedIssue: json.RawMessage("42")},
		{Path: "/w/57", Repo: "hub", LinkedIssue: json.RawMessage(`{"number":57}`)},
	}
	evs := []Event{ev(42, "dispatched", now), {At: now, Issue: 42, Type: "question", Text: "出力先は?"},
		ev(57, "dispatched", now), {At: now, Issue: 57, Type: "pr", URL: "https://x/pr/1"}}
	cards := desiredCards(issues, evs, wts, "hub", now)
	if c := cards["/w/42"]; c.Status != "in-progress" || !c.Unread || c.Comment != "質問: 出力先は?" {
		t.Errorf("question card = %+v", c)
	}
	if c := cards["/w/57"]; c.Status != "in-review" || !c.Unread {
		t.Errorf("pr card = %+v", c)
	}
}

func TestTailerSkipsBadLinesAndWaitsForNewline(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "events.jsonl")
	os.WriteFile(p, []byte(`{"at":"2026-10-18T10:00:00Z","issue":1,"by":"a","type":"started"}`+"\nnot json\n"+`{"issue":2,"type":"pr"`), 0o644)
	tl := &tailer{path: p}
	evs, _, err := tl.read()
	if err != nil || len(evs) != 1 || tl.bad != 1 {
		t.Fatalf("evs=%v bad=%d err=%v", evs, tl.bad, err)
	}
	f, _ := os.OpenFile(p, os.O_APPEND|os.O_WRONLY, 0)
	f.WriteString(`,"at":"2026-10-18T10:00:00Z","by":"b"}` + "\n")
	f.Close()
	if evs, _, _ = tl.read(); len(evs) != 1 || evs[0].Issue != 2 {
		t.Fatalf("completed line not read: %v", evs)
	}
	os.WriteFile(p, []byte{}, 0o644)
	if _, reset, _ := tl.read(); !reset {
		t.Fatal("truncation should reset")
	}
}

func TestDispatchRequestGuard(t *testing.T) {
	s := &server{cfg: Config{Port: 7342}, token: "secret"}
	cases := []struct {
		name, method, origin, site, token string
		ok                                bool
	}{
		{"board page", "POST", "http://127.0.0.1:7342", "same-origin", "secret", true},
		{"no fetch metadata", "POST", "http://127.0.0.1:7342", "", "secret", true},
		{"other page", "POST", "https://evil.example", "cross-site", "secret", false},
		{"missing origin", "POST", "", "", "secret", false},
		{"bad token", "POST", "http://127.0.0.1:7342", "same-origin", "nope", false},
		{"cross-site with token", "POST", "http://127.0.0.1:7342", "cross-site", "secret", false},
		{"GET", "GET", "http://127.0.0.1:7342", "same-origin", "secret", false},
	}
	for _, c := range cases {
		r := httptest.NewRequest(c.method, "http://127.0.0.1:7342/api/dispatch/42", nil)
		if c.origin != "" {
			r.Header.Set("Origin", c.origin)
		}
		if c.site != "" {
			r.Header.Set("Sec-Fetch-Site", c.site)
		}
		r.Header.Set("X-Board-Token", c.token)
		n, err := s.checkActionRequest(r, "/api/dispatch/")
		if (err == nil) != c.ok || (c.ok && n != 42) {
			t.Errorf("%s: n=%d err=%v", c.name, n, err)
		}
	}
	if s.allowedHost("evil.example:7342") || !s.allowedHost("localhost:7342") {
		t.Error("host check")
	}
}

func TestSplitArgs(t *testing.T) {
	opts, pos, err := splitArgs([]string{"42", "pr", "--url", "https://x", "要約", "--by=hub-42"}, "url", "by")
	if err != nil || opts["url"] != "https://x" || opts["by"] != "hub-42" || len(pos) != 3 {
		t.Fatalf("opts=%v pos=%v err=%v", opts, pos, err)
	}
}

func TestResearchBodyPutsSummaryFirst(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "a.md"), []byte("A"), 0o644)
	os.WriteFile(filepath.Join(dir, "summary.md"), []byte("S"), 0o644)
	os.WriteFile(filepath.Join(dir, ".synced"), nil, 0o644)
	body, err := researchBody(42, dir)
	if err != nil {
		t.Fatal(err)
	}
	si, ai := indexOf(body, "### summary.md"), indexOf(body, "### a.md")
	if si < 0 || ai < 0 || si > ai || indexOf(body, researchMarker(42)) != 0 {
		t.Fatalf("body = %q", body)
	}
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}

func TestWaitingAlertsOncePerEvent(t *testing.T) {
	s := &server{issues: map[int]*Issue{42: issue(42)}}
	s.events = []Event{ev(42, "dispatched", now), ev(42, "question", now)}
	snap := build(s.issues, s.events, nil, "hub", now)
	if got := s.waitingAlerts(snap); len(got) != 0 {
		t.Fatalf("first snapshot must not notify: %v", got)
	}
	s.events = append(s.events, ev(42, "answer", now.Add(time.Minute)), ev(42, "question", now.Add(2*time.Minute)))
	snap = build(s.issues, s.events, nil, "hub", now.Add(2*time.Minute))
	if got := s.waitingAlerts(snap); len(got) != 1 || got[0].number != 42 {
		t.Fatalf("new question should notify once: %v", got)
	}
	if got := s.waitingAlerts(snap); len(got) != 0 {
		t.Fatalf("same event must not notify again: %v", got)
	}
}
