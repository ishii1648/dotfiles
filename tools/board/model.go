package main

import (
	"fmt"
	"sort"
	"strings"
	"time"
)

// Board states. The UI and the Orca cards both derive from these.
const (
	stWorking  = "working" // 作業中
	stWaiting  = "waiting" // 確認待ち
	stBlocked  = "blocked" // 依存待ち
	stTodo     = "todo"    // 未着手
	stDone     = "done"    // 完了
	staleAfter = 72 * time.Hour
	// autoDispatchHold: this many or more Epic children becoming ready at once
	// waits for the human instead of starting automatically.
	autoDispatchHold = 5
)

type Progress struct {
	Done  int `json:"done"`
	Total int `json:"total"`
}

type Row struct {
	Number       int       `json:"number"`
	Title        string    `json:"title"`
	URL          string    `json:"url"`
	Kind         string    `json:"kind"`
	Research     bool      `json:"research,omitempty"`
	State        string    `json:"state"`
	Reason       string    `json:"reason,omitempty"`
	Parent       int       `json:"parent,omitempty"`
	ParentTitle  string    `json:"parentTitle,omitempty"`
	Project      int       `json:"project,omitempty"`
	TodayCount   int       `json:"todayCount"`
	LastProgress time.Time `json:"lastProgress"`
	Stale        bool      `json:"stale,omitempty"`
	Progress     *Progress `json:"progress,omitempty"`
	Note         string    `json:"note,omitempty"`
	CanDispatch  bool      `json:"canDispatch,omitempty"`
	Worktree     string    `json:"worktree,omitempty"`
	Children     []Row     `json:"children,omitempty"`
}

type ProjectItem struct {
	Number   int       `json:"number"`
	Title    string    `json:"title"`
	Kind     string    `json:"kind"`
	State    string    `json:"state"`
	Reason   string    `json:"reason,omitempty"`
	Progress *Progress `json:"progress,omitempty"`
}

type ProjectView struct {
	Number       int           `json:"number"`
	Title        string        `json:"title"`
	URL          string        `json:"url"`
	Phase        int           `json:"phase"` // 0 調査, 1 分割案の確認, 2 実行, 3 目標の確認
	Goal         string        `json:"goal,omitempty"`
	NextLabel    string        `json:"nextLabel,omitempty"`
	Next         string        `json:"next,omitempty"`
	LastProgress time.Time     `json:"lastProgress"`
	Stale        bool          `json:"stale,omitempty"`
	Waiting      bool          `json:"waiting,omitempty"`
	TodayCount   int           `json:"todayCount"`
	Items        []ProjectItem `json:"items"`
}

type Snapshot struct {
	Generated   time.Time     `json:"generated"`
	GitHubAt    time.Time     `json:"githubAt"`
	GitHubError string        `json:"githubError,omitempty"`
	OrcaError   string        `json:"orcaError,omitempty"`
	Notices     []string      `json:"notices,omitempty"`
	Rows        []Row         `json:"rows"`
	Projects    []ProjectView `json:"projects"`
	// AutoDispatch lists Epic children that are ready to start; when Held is
	// true there are too many and they wait for the human.
	AutoDispatch []int `json:"autoDispatch,omitempty"`
	Held         bool  `json:"held,omitempty"`
}

type issueEvents struct {
	last       *Event
	lastAt     time.Time
	today      bool
	dispatched bool
}

func indexEvents(evs []Event, now time.Time) map[int]*issueEvents {
	m := map[int]*issueEvents{}
	y, mo, d := now.Date()
	for i := range evs {
		e := &evs[i]
		ie := m[e.Issue]
		if ie == nil {
			ie = &issueEvents{}
			m[e.Issue] = ie
		}
		ie.last = e
		if e.At.After(ie.lastAt) {
			ie.lastAt = e.At
		}
		if ey, emo, ed := e.At.In(now.Location()).Date(); ey == y && emo == mo && ed == d {
			ie.today = true
		}
		if e.Type == "dispatched" {
			ie.dispatched = true
		}
	}
	return m
}

func openBlockers(i *Issue) []int {
	var ns []int
	for _, b := range i.BlockedBy {
		if b.State == "OPEN" {
			ns = append(ns, b.Number)
		}
	}
	return ns
}

func waitingReason(e *Event) string {
	switch e.Type {
	case "question":
		return "質問: " + e.Text
	case "blocked":
		return "blocked: " + e.Text
	case "pr":
		if e.URL != "" {
			return "レビュー: " + e.URL
		}
		return "レビュー"
	case "result":
		return "受け入れ待ち"
	}
	return ""
}

// taskState decides a Task's board state. Closed wins, then open blockers,
// then the latest event.
func taskState(i *Issue, ie *issueEvents) (state, reason, note string) {
	if !i.Open() {
		return stDone, "", ""
	}
	if bs := openBlockers(i); len(bs) > 0 {
		parts := make([]string, len(bs))
		for k, b := range bs {
			parts[k] = fmt.Sprintf("#%d", b)
		}
		return stBlocked, "", strings.Join(parts, "・") + " の完了待ち"
	}
	if ie == nil || ie.last == nil {
		return stTodo, "", ""
	}
	switch ie.last.Type {
	case "question", "blocked", "pr", "result":
		return stWaiting, waitingReason(ie.last), ""
	}
	return stWorking, "", ""
}

func cardFor(state string, e *Event) card {
	switch state {
	case stDone:
		return card{Status: "completed", Comment: "完了"}
	case stWaiting:
		c := card{Status: "in-progress", Comment: waitingReason(e), Unread: true}
		if e.Type == "pr" || e.Type == "result" {
			c.Status = "in-review"
		}
		return c
	}
	comment := ""
	if e != nil && e.Text != "" {
		comment = e.Text
	}
	return card{Status: "in-progress", Comment: comment}
}

// heading returns the first non-empty line under "## name" in a Markdown body.
func heading(body string, names ...string) (string, string) {
	lines := strings.Split(strings.ReplaceAll(body, "\r\n", "\n"), "\n")
	for _, name := range names {
		for k, l := range lines {
			t := strings.TrimSpace(l)
			if !strings.HasPrefix(t, "## ") || strings.TrimSpace(t[3:]) != name {
				continue
			}
			for _, nl := range lines[k+1:] {
				nt := strings.TrimSpace(nl)
				if strings.HasPrefix(nt, "#") {
					break
				}
				if nt != "" {
					return name, strings.TrimLeft(nt, "-* ")
				}
			}
		}
	}
	return "", ""
}

func build(issues map[int]*Issue, evs []Event, wts []OrcaWorktree, repoShort string, now time.Time) Snapshot {
	idx := indexEvents(evs, now)
	snap := Snapshot{Generated: now}

	children := map[int][]*Issue{}
	for _, i := range issues {
		if i.Parent != 0 {
			children[i.Parent] = append(children[i.Parent], i)
		}
	}
	for _, cs := range children {
		sort.Slice(cs, func(a, b int) bool { return cs[a].Number < cs[b].Number })
	}

	lastProgress := func(i *Issue) time.Time {
		if ie := idx[i.Number]; ie != nil && !ie.lastAt.IsZero() {
			return ie.lastAt
		}
		return i.CreatedAt
	}
	projectOf := func(i *Issue) int {
		for p, hops := i.Parent, 0; p != 0 && hops < 3; hops++ {
			pi := issues[p]
			if pi == nil {
				return 0
			}
			if pi.Kind() == "project" {
				return p
			}
			p = pi.Parent
		}
		return 0
	}

	// Ready Epic children decide auto-dispatch and the "起動の確認" hold.
	for _, i := range issues {
		if !i.Open() || i.Kind() != "task" || i.Parent == 0 {
			continue
		}
		if p := issues[i.Parent]; p == nil || p.Kind() != "epic" || !p.Open() {
			continue
		}
		if ie := idx[i.Number]; ie != nil && ie.dispatched {
			continue
		}
		if len(openBlockers(i)) > 0 || worktreeFor(wts, repoShort, i.Number) != nil {
			continue
		}
		snap.AutoDispatch = append(snap.AutoDispatch, i.Number)
	}
	sort.Ints(snap.AutoDispatch)
	snap.Held = len(snap.AutoDispatch) >= autoDispatchHold
	held := map[int]bool{}
	if snap.Held {
		for _, n := range snap.AutoDispatch {
			held[n] = true
		}
	}

	taskRow := func(i *Issue) Row {
		ie := idx[i.Number]
		st, reason, note := taskState(i, ie)
		if st == stTodo && held[i.Number] {
			st, reason = stWaiting, "起動の確認"
		}
		r := Row{
			Number: i.Number, Title: i.Title, URL: i.URL, Kind: "task",
			Research: i.HasLabel(labelResearch), State: st, Reason: reason, Note: note,
			Parent: i.Parent, Project: projectOf(i), LastProgress: lastProgress(i),
		}
		if p := issues[i.Parent]; p != nil {
			r.ParentTitle = p.Title
		}
		if ie != nil && ie.today {
			r.TodayCount = 1
		}
		r.Stale = st != stDone && now.Sub(r.LastProgress) >= staleAfter
		r.CanDispatch = st == stTodo && i.Open()
		if w := worktreeFor(wts, repoShort, i.Number); w != nil {
			r.Worktree = w.Path
		}
		return r
	}

	epicRow := func(i *Issue) Row {
		r := Row{
			Number: i.Number, Title: i.Title, URL: i.URL, Kind: "epic",
			Parent: i.Parent, Project: projectOf(i), LastProgress: i.CreatedAt,
		}
		if p := issues[i.Parent]; p != nil {
			r.ParentTitle = p.Title
		}
		prog := &Progress{}
		for _, s := range i.SubIssues {
			prog.Total++
			if s.State == "CLOSED" {
				prog.Done++
			}
		}
		r.Progress = prog
		var states []string
		for _, c := range children[i.Number] {
			cr := taskRow(c)
			if c.Open() || now.Sub(derefTime(c.ClosedAt)) < 7*24*time.Hour {
				r.Children = append(r.Children, cr)
			}
			states = append(states, cr.State)
			r.TodayCount += cr.TodayCount
			if cr.LastProgress.After(r.LastProgress) {
				r.LastProgress = cr.LastProgress
			}
		}
		has := func(s string) bool {
			for _, x := range states {
				if x == s {
					return true
				}
			}
			return false
		}
		switch {
		case !i.Open():
			r.State = stDone
		case has(stWaiting):
			r.State = stWaiting
		case has(stWorking):
			r.State = stWorking
		case prog.Total > 0 && prog.Done == prog.Total:
			r.State, r.Reason = stWaiting, "子 Task がすべて完了"
		case has(stTodo):
			r.State = stTodo
		case has(stBlocked):
			r.State = stBlocked
		default:
			r.State = stTodo
		}
		r.Stale = r.State != stDone && now.Sub(r.LastProgress) >= staleAfter
		return r
	}

	for _, i := range issues {
		switch i.Kind() {
		case "epic":
			snap.Rows = append(snap.Rows, epicRow(i))
		case "task":
			if p := issues[i.Parent]; p != nil && p.Kind() == "epic" {
				continue
			}
			snap.Rows = append(snap.Rows, taskRow(i))
		}
	}
	sort.Slice(snap.Rows, func(a, b int) bool { return snap.Rows[a].Number > snap.Rows[b].Number })

	rowByNumber := map[int]Row{}
	for _, r := range snap.Rows {
		rowByNumber[r.Number] = r
	}
	for _, i := range issues {
		if i.Kind() != "project" {
			continue
		}
		pv := ProjectView{Number: i.Number, Title: i.Title, URL: i.URL, LastProgress: lastProgress(i)}
		_, pv.Goal = heading(i.Body, "目標")
		pv.NextLabel, pv.Next = heading(i.Body, "次の節目", "次に決めること")
		var research, work []ProjectItem
		researchWaiting := false
		for _, c := range children[i.Number] {
			r, ok := rowByNumber[c.Number]
			if !ok {
				r = taskRow(c)
			}
			item := ProjectItem{Number: r.Number, Title: r.Title, Kind: r.Kind, State: r.State, Reason: r.Reason, Progress: r.Progress}
			if r.LastProgress.After(pv.LastProgress) {
				pv.LastProgress = r.LastProgress
			}
			pv.TodayCount += r.TodayCount
			if r.State == stWaiting {
				pv.Waiting = true
			}
			if c.Kind() == "task" && c.HasLabel(labelResearch) {
				research = append(research, item)
				if r.State == stWaiting && r.Reason == "受け入れ待ち" {
					researchWaiting = true
				}
			} else {
				work = append(work, item)
			}
		}
		allClosed := len(work) > 0
		for _, w := range work {
			if w.State != stDone {
				allClosed = false
			}
		}
		switch {
		case len(work) > 0 && allClosed:
			pv.Phase, pv.Items = 3, work
		case len(work) > 0:
			pv.Phase, pv.Items = 2, work
		case researchWaiting:
			pv.Phase, pv.Items = 1, research
		default:
			pv.Phase, pv.Items = 0, research
		}
		if pv.Items == nil {
			pv.Items = []ProjectItem{}
		}
		pv.Stale = i.Open() && now.Sub(pv.LastProgress) >= staleAfter
		if i.Open() {
			snap.Projects = append(snap.Projects, pv)
		}
	}
	sort.Slice(snap.Projects, func(a, b int) bool { return snap.Projects[a].Number > snap.Projects[b].Number })
	if snap.Rows == nil {
		snap.Rows = []Row{}
	}
	if snap.Projects == nil {
		snap.Projects = []ProjectView{}
	}
	return snap
}

func derefTime(t *time.Time) time.Time {
	if t == nil {
		return time.Time{}
	}
	return *t
}

// desiredCards maps worktree path to the card the board wants Orca to show.
func desiredCards(issues map[int]*Issue, evs []Event, wts []OrcaWorktree, repoShort string, now time.Time) map[string]card {
	idx := indexEvents(evs, now)
	out := map[string]card{}
	for _, w := range wts {
		n := w.IssueNumber()
		if w.IsMainWorktree || n == 0 || (w.Repo != "" && w.Repo != repoShort) {
			continue
		}
		i := issues[n]
		ie := idx[n]
		if i == nil || ie == nil || !ie.dispatched {
			continue
		}
		st, _, _ := taskState(i, ie)
		out[w.Path] = cardFor(st, ie.last)
	}
	return out
}
