package main

import (
	"fmt"
	"sort"
	"strings"
	"time"
)

// Board states. The UI and the Orca cards both derive from these. A worker
// waiting for the person's answer is not a board state: Orca detects the idle
// agent and notifies (ADR-095).
const (
	stDecide   = "decide"  // 判断待ち: an Issue-level decision only the board shows
	stReview   = "review"  // レビュー待ち: an open, non-draft PR closes the Issue
	stWorking  = "working" // 作業中
	stBlocked  = "blocked" // 依存待ち
	stTodo     = "todo"    // 未着手
	stDone     = "done"    // 完了
	staleAfter = 72 * time.Hour
	// autoDispatchHold: this many or more Epic children becoming ready at once
	// waits for the human instead of starting automatically.
	autoDispatchHold = 5
	// dispatchGrace covers the delay before the board's next Orca poll (10s)
	// sees a freshly dispatched worktree.
	dispatchGrace = time.Minute
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
	Resume       bool      `json:"resume,omitempty"`
	Worktree     string    `json:"worktree,omitempty"`
	PRs          []RowPR   `json:"prs,omitempty"`
	Children     []Row     `json:"children,omitempty"`
}

type RowPR struct {
	Label string `json:"label"`
	URL   string `json:"url"`
	State string `json:"state"` // open, draft or merged
	// Also lists the other Issues the same PR closes.
	Also []int `json:"also,omitempty"`
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
	lastAt       time.Time
	dispatched   bool
	dispatchedAt time.Time
}

func indexEvents(evs []Event) map[int]*issueEvents {
	m := map[int]*issueEvents{}
	for i := range evs {
		e := &evs[i]
		ie := m[e.Issue]
		if ie == nil {
			ie = &issueEvents{}
			m[e.Issue] = ie
		}
		if e.At.After(ie.lastAt) {
			ie.lastAt = e.At
		}
		if e.Type == "dispatched" {
			ie.dispatched = true
			if e.At.After(ie.dispatchedAt) {
				ie.dispatchedAt = e.At
			}
		}
	}
	return m
}

func sameDay(a, b time.Time) bool {
	ay, am, ad := a.In(b.Location()).Date()
	by, bm, bd := b.Date()
	return ay == by && am == bm && ad == bd
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

// taskState decides a Task's board state from GitHub and whether a worker was
// started. Closed wins, then open blockers, then an open PR ready for review.
func taskState(i *Issue, started bool) (state, reason, note string) {
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
	for _, p := range i.PRs {
		if p.State == "OPEN" && !p.IsDraft {
			return stReview, "", ""
		}
	}
	if started {
		return stWorking, "", ""
	}
	return stTodo, "", ""
}

// cardFor leaves the comment to the worker, which knows what it is doing.
func cardFor(state string) card {
	switch state {
	case stDone:
		return card{Status: "completed"}
	case stReview:
		return card{Status: "in-review"}
	}
	return card{Status: "in-progress"}
}

// prLabel is "repo#N", or "owner/repo#N" when the PR lives under another owner
// than the Issue.
func prLabel(prURL, issueURL string) string {
	path := func(u string) []string { return strings.Split(strings.TrimPrefix(u, "https://github.com/"), "/") }
	p, i := path(prURL), path(issueURL)
	if len(p) < 4 {
		return prURL
	}
	if p[0] == i[0] {
		return p[1] + "#" + p[3]
	}
	return p[0] + "/" + p[1] + "#" + p[3]
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
	idx := indexEvents(evs)
	snap := Snapshot{Generated: now}

	closes := map[string][]int{}
	for _, i := range issues {
		for _, p := range i.PRs {
			closes[p.URL] = append(closes[p.URL], i.Number)
		}
	}
	for _, ns := range closes {
		sort.Ints(ns)
	}
	rowPRs := func(i *Issue) []RowPR {
		var out []RowPR
		for _, p := range i.PRs {
			rp := RowPR{Label: prLabel(p.URL, i.URL), URL: p.URL, State: "open"}
			switch {
			case p.State == "MERGED":
				rp.State = "merged"
			case p.IsDraft:
				rp.State = "draft"
			}
			for _, n := range closes[p.URL] {
				if n != i.Number {
					rp.Also = append(rp.Also, n)
				}
			}
			out = append(out, rp)
		}
		return out
	}

	children := map[int][]*Issue{}
	for _, i := range issues {
		if i.Parent != 0 {
			children[i.Parent] = append(children[i.Parent], i)
		}
	}
	for _, cs := range children {
		sort.Slice(cs, func(a, b int) bool { return cs[a].Number < cs[b].Number })
	}

	// Progress is the latest sign of work: board events, Issue and PR updates
	// on GitHub, and terminal activity in the worker's Orca worktree.
	lastProgress := func(i *Issue) time.Time {
		t := i.CreatedAt
		later := func(u time.Time) {
			if u.After(t) {
				t = u
			}
		}
		if ie := idx[i.Number]; ie != nil {
			later(ie.lastAt)
		}
		later(i.UpdatedAt)
		for _, p := range i.PRs {
			later(p.UpdatedAt)
		}
		if w := worktreeFor(wts, repoShort, i.Number); w != nil && w.LastActivityAt > 0 {
			later(time.UnixMilli(w.LastActivityAt))
		}
		return t
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
		wt := worktreeFor(wts, repoShort, i.Number)
		dispatched := ie != nil && ie.dispatched
		// A dispatched Task whose worktree is gone has no worker left; dispatching
		// it again brings the worktree back and resumes the worker's session.
		lost := dispatched && wt == nil && i.Open() && now.Sub(ie.dispatchedAt) >= dispatchGrace
		st, reason, note := taskState(i, wt != nil || (dispatched && !lost))
		if st == stTodo && held[i.Number] {
			st, reason = stDecide, "起動の確認"
		}
		if st == stTodo && lost {
			reason = "worktree が見つからない"
		}
		r := Row{
			Number: i.Number, Title: i.Title, URL: i.URL, Kind: "task",
			Research: i.HasLabel(labelResearch), State: st, Reason: reason, Note: note,
			Parent: i.Parent, Project: projectOf(i), LastProgress: lastProgress(i),
			PRs: rowPRs(i),
		}
		if p := issues[i.Parent]; p != nil {
			r.ParentTitle = p.Title
		}
		if st != stDone && sameDay(r.LastProgress, now) {
			r.TodayCount = 1
		}
		r.Stale = st != stDone && now.Sub(r.LastProgress) >= staleAfter
		r.CanDispatch = st == stTodo && i.Open() || lost
		r.Resume = lost
		if wt != nil {
			r.Worktree = wt.Path
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
		case has(stDecide):
			r.State = stDecide
		case has(stReview):
			r.State = stReview
		case has(stWorking):
			r.State = stWorking
		case prog.Total > 0 && prog.Done == prog.Total:
			r.State, r.Reason = stDecide, "子 Task がすべて完了"
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
			if r.State == stDecide || r.State == stReview {
				pv.Waiting = true
			}
			if c.Kind() == "task" && c.HasLabel(labelResearch) {
				research = append(research, item)
				if r.State == stReview {
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

// controlRoomCard is the card of the origin repository's main worktree, which
// stays in the Orca sidebar as the way into the Control Room.
func controlRoomCard(snap Snapshot) card {
	var decide, review, working int
	count := func(r Row) {
		switch {
		// An Epic needs a decision on its own only when it has a reason;
		// otherwise its state comes from children that are counted themselves.
		case r.Kind == "epic" && r.Reason == "":
		case r.State == stDecide:
			decide++
		case r.State == stReview:
			review++
		case r.State == stWorking && r.Kind == "task":
			working++
		}
	}
	for _, r := range snap.Rows {
		count(r)
		for _, c := range r.Children {
			count(c)
		}
	}
	comment := fmt.Sprintf("レビュー待ち %d / 作業中 %d", review, working)
	if decide > 0 {
		comment = fmt.Sprintf("判断待ち %d / %s", decide, comment)
	}
	return card{Name: "Control Room", Comment: comment}
}

// desiredCards maps worktree path to the card the board wants Orca to show.
func desiredCards(issues map[int]*Issue, evs []Event, wts []OrcaWorktree, repoShort string) map[string]card {
	idx := indexEvents(evs)
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
		st, _, _ := taskState(i, true)
		out[w.Path] = cardFor(st)
	}
	return out
}
