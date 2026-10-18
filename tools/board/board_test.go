package main

import (
	"encoding/json"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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
	review := issue(5)
	review.PRs = []PRRef{{Number: 7, URL: "https://x/pull/7", State: "OPEN"}}
	draft := issue(8)
	draft.PRs = []PRRef{{Number: 8, URL: "https://x/pull/8", State: "OPEN", IsDraft: true}, {Number: 6, URL: "https://x/pull/6", State: "MERGED"}}
	issues := map[int]*Issue{1: closed, 2: blocked, 3: issue(3), 4: issue(4), 5: review, 6: issue(6), 7: issue(7), 8: draft}
	issues[6].CreatedAt = now.Add(-5 * 24 * time.Hour)
	issues[7].CreatedAt = now.Add(-5 * 24 * time.Hour)
	evs := []Event{
		ev(2, "dispatched", now), // open blocker still wins
		ev(4, "dispatched", now),
		ev(6, "dispatched", now.Add(-4*24*time.Hour)),
		ev(8, "dispatched", now),
	}
	wts := []OrcaWorktree{{Path: "/w/7", Repo: "hub", LinkedIssue: json.RawMessage("7"), LastActivityAt: now.Add(-4 * 24 * time.Hour).UnixMilli()}}
	snap := build(issues, evs, wts, "hub", now)
	// #6 was dispatched days ago and its worktree is gone.
	cases := map[int]string{1: stDone, 2: stBlocked, 3: stTodo, 4: stWorking, 5: stReview, 6: stTodo, 7: stWorking, 8: stWorking}
	for n, want := range cases {
		if got := findRow(t, snap.Rows, n).State; got != want {
			t.Errorf("#%d state = %s, want %s", n, got, want)
		}
	}
	if !findRow(t, snap.Rows, 6).Stale || !findRow(t, snap.Rows, 7).Stale {
		t.Error("#6 and #7 should be stale after 4 days without progress")
	}
	if !findRow(t, snap.Rows, 3).CanDispatch || findRow(t, snap.Rows, 4).CanDispatch || findRow(t, snap.Rows, 7).CanDispatch {
		t.Error("only untouched open tasks can be dispatched")
	}
	if r := findRow(t, snap.Rows, 6); !r.CanDispatch || !r.Resume || r.Reason != "worktree が見つからない" {
		t.Errorf("lost worktree row = %+v", r)
	}
	if r := findRow(t, snap.Rows, 4); r.Resume {
		t.Error("#4 was dispatched just now; its worktree may not be listed yet")
	}
	if findRow(t, snap.Rows, 4).TodayCount != 1 {
		t.Error("#4 moved today")
	}

	// Recent activity in the worktree or on GitHub counts as progress.
	wts[0].LastActivityAt = now.Add(-time.Hour).UnixMilli()
	issues[6].UpdatedAt = now.Add(-time.Hour)
	snap = build(issues, evs, wts, "hub", now)
	if findRow(t, snap.Rows, 6).Stale || findRow(t, snap.Rows, 7).Stale || findRow(t, snap.Rows, 7).TodayCount != 1 {
		t.Error("#6 and #7 moved today")
	}
}

func TestRowPRs(t *testing.T) {
	a, b, c := issue(31), issue(32), issue(33)
	a.URL, b.URL, c.URL = "https://github.com/me/hub/issues/31", "https://github.com/me/hub/issues/32", "https://github.com/me/hub/issues/33"
	shared := PRRef{Number: 41, URL: "https://github.com/me/hub/pull/41", State: "OPEN"}
	a.PRs = []PRRef{shared}
	b.PRs = []PRRef{shared, {Number: 9, URL: "https://github.com/you/lib/pull/9", State: "MERGED"}}
	c.PRs = []PRRef{{Number: 43, URL: "https://github.com/me/dotfiles/pull/43", State: "OPEN", IsDraft: true}}
	snap := build(map[int]*Issue{31: a, 32: b, 33: c}, nil, nil, "hub", now)
	got := func(n int) []RowPR { return findRow(t, snap.Rows, n).PRs }
	if p := got(31); len(p) != 1 || p[0].Label != "hub#41" || p[0].State != "open" || len(p[0].Also) != 1 || p[0].Also[0] != 32 {
		t.Errorf("#31 prs = %+v", p)
	}
	if p := got(32); len(p) != 2 || p[0].Also[0] != 31 || p[1].Label != "you/lib#9" || p[1].State != "merged" || p[1].Also != nil {
		t.Errorf("#32 prs = %+v", p)
	}
	if p := got(33); len(p) != 1 || p[0].Label != "dotfiles#43" || p[0].State != "draft" {
		t.Errorf("#33 prs = %+v", p)
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
	if got := findRow(t, snap.Rows, 20); got.State != stDecide || got.Reason != "起動の確認" {
		t.Fatalf("held child = %s %q", got.State, got.Reason)
	}
}

func TestProjectPhase(t *testing.T) {
	p := issue(80, labelProject)
	p.Body = "## 目標\n\n地図の読み込みを改善する\n\n## 次に決めること\n- 分割案を確認する\n"
	research := issue(81, labelResearch)
	research.Parent = 80
	issues := map[int]*Issue{80: p, 81: research}
	if got := build(issues, []Event{ev(81, "dispatched", now)}, nil, "hub", now).Projects[0].Phase; got != 0 {
		t.Fatalf("phase while researching = %d, want 0", got)
	}
	research.PRs = []PRRef{{Number: 3, State: "OPEN"}}
	snap := build(issues, []Event{ev(81, "dispatched", now)}, nil, "hub", now)
	pv := snap.Projects[0]
	if pv.Phase != 1 || !pv.Waiting || pv.Goal != "地図の読み込みを改善する" || pv.NextLabel != "次に決めること" || pv.Next != "分割案を確認する" {
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
	pr := issue(57)
	pr.PRs = []PRRef{{Number: 1, State: "OPEN"}}
	issues := map[int]*Issue{42: issue(42), 57: pr}
	wts := []OrcaWorktree{
		{Path: "/w/42", Repo: "hub", LinkedIssue: json.RawMessage("42")},
		{Path: "/w/57", Repo: "hub", LinkedIssue: json.RawMessage(`{"number":57}`)},
	}
	evs := []Event{ev(42, "dispatched", now), ev(57, "dispatched", now)}
	cards := desiredCards(issues, evs, wts, "hub")
	if c := cards["/w/42"]; c != (card{Status: "in-progress"}) {
		t.Errorf("working card = %+v", c)
	}
	if c := cards["/w/57"]; c != (card{Status: "in-review"}) {
		t.Errorf("pr card = %+v", c)
	}
}

func TestControlRoomCard(t *testing.T) {
	epic := issue(10, labelEpic)
	epic.SubIssues = []IssueRef{{Number: 11, State: "OPEN"}, {Number: 12, State: "OPEN"}}
	c11, c12, c20 := issue(11), issue(12), issue(20)
	c11.Parent, c12.Parent = 10, 10
	c11.PRs = []PRRef{{Number: 1, State: "OPEN"}}
	c20.PRs = []PRRef{{Number: 2, State: "OPEN"}}
	issues := map[int]*Issue{10: epic, 11: c11, 12: c12, 20: c20, 21: issue(21)}
	evs := []Event{ev(11, "dispatched", now), ev(12, "dispatched", now), ev(20, "dispatched", now)}
	c := controlRoomCard(build(issues, evs, nil, "hub", now))
	if c != (card{Name: "Control room", Comment: "レビュー待ち 2 / 作業中 1"}) {
		t.Errorf("busy card = %+v", c)
	}
	epic.SubIssues = []IssueRef{{Number: 11, State: "CLOSED"}, {Number: 12, State: "CLOSED"}}
	c11.State, c12.State = "CLOSED", "CLOSED"
	if c := controlRoomCard(build(issues, evs, nil, "hub", now)); c.Comment != "判断待ち 1 / レビュー待ち 1 / 作業中 0" {
		t.Errorf("epic decision card = %+v", c)
	}
}

func TestTailerSkipsBadLinesAndWaitsForNewline(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "events.jsonl")
	os.WriteFile(p, []byte(`{"at":"2026-10-18T10:00:00Z","issue":1,"by":"a","type":"started"}`+"\nnot json\n"+`{"issue":2,"type":"started"`), 0o644)
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

func TestForgetMissingWorktrees(t *testing.T) {
	repo, wt := t.TempDir(), filepath.Join(t.TempDir(), "issue-1")
	git := func(args ...string) {
		t.Helper()
		cmd := exec.Command("git", append([]string{"-C", repo, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false"}, args...)...)
		if b, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("git %v: %v: %s", args, err, b)
		}
	}
	git("init", "-q")
	git("commit", "-q", "--allow-empty", "-m", "init")
	git("worktree", "add", "-q", "-b", "issue-1", wt)
	git("worktree", "lock", wt)
	if err := os.RemoveAll(wt); err != nil {
		t.Fatal(err)
	}
	missing, err := forgetMissingWorktrees(repo, "issue-1")
	if err != nil || len(missing) != 1 {
		t.Fatalf("missing = %v, err = %v", missing, err)
	}
	out, _ := exec.Command("git", "-C", repo, "worktree", "list", "--porcelain").Output()
	if strings.Contains(string(out), "issue-1") {
		t.Errorf("registration of the removed worktree remains:\n%s", out)
	}
	if !branchExists(repo, "issue-1") {
		t.Error("the branch must survive")
	}
}

func TestSplitArgs(t *testing.T) {
	opts, pos, err := splitArgs([]string{"42", "pr", "--url", "https://x", "要約", "--by=hub-42"}, "url", "by")
	if err != nil || opts["url"] != "https://x" || opts["by"] != "hub-42" || len(pos) != 3 {
		t.Fatalf("opts=%v pos=%v err=%v", opts, pos, err)
	}
}
