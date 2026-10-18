package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

type orcaTerminal struct {
	Handle        string `json:"handle"`
	WorktreePath  string `json:"worktreePath"`
	Connected     bool   `json:"connected"`
	AgentIdentity string `json:"agentIdentity"`
	LastOutputAt  int64  `json:"lastOutputAt"`
}

// openWorker brings the worker terminal of Issue n to the front in Orca.
// Handles change when Orca restarts, so they are looked up every time.
func openWorker(cfg Config, n int) error {
	wts, err := orcaPS()
	if err != nil {
		return err
	}
	w := worktreeFor(wts, cfg.Short(), n)
	if w == nil {
		return fmt.Errorf("#%d has no worktree", n)
	}
	best, err := bestTerminal(w.Path)
	if err != nil {
		return err
	}
	if best == nil {
		return fmt.Errorf("#%d has no open terminal in %s", n, w.Path)
	}
	if _, err := runOrca("terminal", "switch", "--terminal", best.Handle); err != nil {
		return err
	}
	_ = exec.Command("open", "-b", "com.stablyai.orca").Run()
	return nil
}

// bestTerminal picks the connected terminal of the worktree at path, preferring
// the Claude terminal and then the most recently active one. It is nil when the
// worktree has none.
func bestTerminal(path string) (*orcaTerminal, error) {
	out, err := runOrca("terminal", "list", "--worktree", "path:"+path, "--json")
	if err != nil {
		return nil, err
	}
	var resp struct {
		Result struct {
			Terminals []orcaTerminal `json:"terminals"`
		} `json:"result"`
	}
	if err := json.Unmarshal(out, &resp); err != nil {
		return nil, fmt.Errorf("parse orca terminal list: %w", err)
	}
	var best *orcaTerminal
	for i := range resp.Result.Terminals {
		t := &resp.Result.Terminals[i]
		if t.WorktreePath != path || !t.Connected {
			continue
		}
		better := best == nil ||
			(t.AgentIdentity == "claude" && best.AgentIdentity != "claude") ||
			((t.AgentIdentity == "claude") == (best.AgentIdentity == "claude") && t.LastOutputAt > best.LastOutputAt)
		if better {
			best = t
		}
	}
	return best, nil
}

// openControlRoom brings the Control Room tab of the main worktree to the front
// in Orca, opening one there when it is gone.
func openControlRoom(cfg Config) error {
	url := fmt.Sprintf("http://127.0.0.1:%d/", cfg.Port)
	wt := "path:" + cfg.RepoPath
	out, err := runOrca("tab", "list", "--worktree", wt, "--json")
	if err != nil {
		return err
	}
	var list struct {
		Result struct {
			Tabs []struct {
				Page string `json:"browserPageId"`
				URL  string `json:"url"`
			} `json:"tabs"`
		} `json:"result"`
	}
	if err := json.Unmarshal(out, &list); err != nil {
		return fmt.Errorf("parse orca tab list: %w", err)
	}
	page := ""
	for _, t := range list.Result.Tabs {
		if strings.HasPrefix(t.URL, url) || strings.HasPrefix(t.URL, fmt.Sprintf("http://localhost:%d/", cfg.Port)) {
			page = t.Page
			break
		}
	}
	if page == "" {
		out, err := runOrca("tab", "create", "--worktree", wt, "--url", url, "--json")
		if err != nil {
			return err
		}
		var created struct {
			Result struct {
				Page string `json:"browserPageId"`
			} `json:"result"`
		}
		if err := json.Unmarshal(out, &created); err != nil || created.Result.Page == "" {
			return fmt.Errorf("parse orca tab create: %v", err)
		}
		page = created.Result.Page
	}
	// tab switch --focus only surfaces the tab when the main worktree is already
	// the one on screen, so switch to one of its terminals first.
	if t, err := bestTerminal(cfg.RepoPath); err != nil {
		return err
	} else if t != nil {
		if _, err := runOrca("terminal", "switch", "--terminal", t.Handle); err != nil {
			return err
		}
	}
	if _, err := runOrca("tab", "switch", "--page", page, "--worktree", wt, "--focus"); err != nil {
		return err
	}
	_ = exec.Command("open", "-b", "com.stablyai.orca").Run()
	return nil
}
