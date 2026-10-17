package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
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
	out, err := runOrca("terminal", "list", "--worktree", "path:"+w.Path, "--json")
	if err != nil {
		return err
	}
	var resp struct {
		Result struct {
			Terminals []orcaTerminal `json:"terminals"`
		} `json:"result"`
	}
	if err := json.Unmarshal(out, &resp); err != nil {
		return fmt.Errorf("parse orca terminal list: %w", err)
	}
	var best *orcaTerminal
	for i := range resp.Result.Terminals {
		t := &resp.Result.Terminals[i]
		if t.WorktreePath != w.Path || !t.Connected {
			continue
		}
		// Prefer the Claude terminal, then the most recently active one.
		better := best == nil ||
			(t.AgentIdentity == "claude" && best.AgentIdentity != "claude") ||
			((t.AgentIdentity == "claude") == (best.AgentIdentity == "claude") && t.LastOutputAt > best.LastOutputAt)
		if better {
			best = t
		}
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

// notify shows a macOS notification whose click runs `board open <n>`.
func notify(n int, title, message string) {
	bin, err := os.Executable()
	if err != nil {
		return
	}
	bin, _ = filepath.Abs(bin)
	subtitle := fmt.Sprintf("#%d %s", n, title)
	if tn, err := exec.LookPath("terminal-notifier"); err == nil {
		_ = exec.Command(tn,
			"-title", "Control room",
			"-subtitle", subtitle,
			"-message", message,
			"-group", fmt.Sprintf("board-%d", n),
			"-execute", fmt.Sprintf("%q open %d", bin, n),
		).Run()
		return
	}
	esc := func(s string) string { return strings.ReplaceAll(strings.ReplaceAll(s, `\`, `\\`), `"`, `\"`) }
	_ = exec.Command("osascript", "-e", fmt.Sprintf(`display notification "%s" with title "Control room" subtitle "%s"`, esc(message), esc(subtitle))).Run()
}
