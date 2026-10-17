package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

type OrcaWorktree struct {
	Path            string          `json:"path"`
	Repo            string          `json:"repo"`
	DisplayName     string          `json:"displayName"`
	IsMainWorktree  bool            `json:"isMainWorktree"`
	WorkspaceStatus string          `json:"workspaceStatus"`
	Comment         string          `json:"comment"`
	Unread          bool            `json:"unread"`
	LinkedIssue     json.RawMessage `json:"linkedIssue"`
	Status          string          `json:"status"`
}

// IssueNumber reads linkedIssue, which Orca stores either as a bare number or
// as an object carrying "number".
func (w OrcaWorktree) IssueNumber() int {
	raw := bytes.TrimSpace(w.LinkedIssue)
	if len(raw) == 0 || string(raw) == "null" {
		return 0
	}
	var n int
	if json.Unmarshal(raw, &n) == nil {
		return n
	}
	var s string
	if json.Unmarshal(raw, &s) == nil {
		n, _ = strconv.Atoi(s)
		return n
	}
	var o struct {
		Number int `json:"number"`
	}
	if json.Unmarshal(raw, &o) == nil {
		return o.Number
	}
	return 0
}

func orcaBin() string {
	if p := os.Getenv("BOARD_ORCA"); p != "" {
		return p
	}
	if p, err := exec.LookPath("orca"); err == nil {
		return p
	}
	return "/usr/local/bin/orca"
}

func runOrca(args ...string) ([]byte, error) {
	cmd := exec.Command(orcaBin(), args...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = strings.TrimSpace(string(out))
		}
		return out, fmt.Errorf("orca %s: %v: %s", strings.Join(args[:min(2, len(args))], " "), err, msg)
	}
	return out, nil
}

func orcaPS() ([]OrcaWorktree, error) {
	out, err := runOrca("worktree", "ps", "--json")
	if err != nil {
		return nil, err
	}
	var resp struct {
		OK     bool `json:"ok"`
		Result struct {
			Worktrees []OrcaWorktree `json:"worktrees"`
		} `json:"result"`
	}
	if err := json.Unmarshal(out, &resp); err != nil {
		return nil, fmt.Errorf("parse orca worktree ps: %w", err)
	}
	return resp.Result.Worktrees, nil
}

// worktreeFor finds the dispatched worktree of issue n in repo.
func worktreeFor(wts []OrcaWorktree, repoShort string, n int) *OrcaWorktree {
	for i := range wts {
		w := &wts[i]
		if w.IsMainWorktree || w.IssueNumber() != n {
			continue
		}
		if w.Repo != "" && w.Repo != repoShort {
			continue
		}
		return w
	}
	return nil
}

// findPath returns the first "path" string in a JSON document; the shape of
// `orca worktree create --json` nests the worktree under result.
func findPath(v any) string {
	switch t := v.(type) {
	case map[string]any:
		if p, ok := t["path"].(string); ok && p != "" {
			return p
		}
		for _, k := range []string{"result", "worktree"} {
			if p := findPath(t[k]); p != "" {
				return p
			}
		}
		for _, x := range t {
			if p := findPath(x); p != "" {
				return p
			}
		}
	case []any:
		for _, x := range t {
			if p := findPath(x); p != "" {
				return p
			}
		}
	}
	return ""
}

type card struct {
	Status  string
	Comment string
	Unread  bool
}

func orcaSetCard(path string, c card) error {
	args := []string{"worktree", "set", "--worktree", "path:" + path, "--workspace-status", c.Status, "--comment", c.Comment}
	if c.Unread {
		args = append(args, "--unread")
	} else {
		args = append(args, "--read")
	}
	_, err := runOrca(args...)
	return err
}
