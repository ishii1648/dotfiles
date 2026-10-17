package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

var errAlreadyDispatched = errors.New("already dispatched")

// withLock serializes dispatch and cleanup across the master, the board
// server and the dispatch button, so one Issue never gets two workers.
func withLock(fn func() error) error {
	if err := ensureStateDir(); err != nil {
		return err
	}
	f, err := os.OpenFile(filepath.Join(stateDir(), "dispatch.lock"), os.O_CREATE|os.O_RDWR, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		return err
	}
	defer syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
	return fn()
}

func workerCommand(cfg Config, n int) string {
	name := cfg.WorkerName(n)
	// Typed into the login shell (fish) by Orca, so keep it to plain words.
	return fmt.Sprintf("env BOARD_BY=%s BOARD_ISSUE=%d claude --name %s --permission-mode auto '/worker %d'", name, n, name, n)
}

// dispatch creates and locks the Issue's worktree, starts its worker in an
// Orca terminal and records the dispatched event. It returns the worktree path.
func dispatch(cfg Config, n int, by string) (string, error) {
	var wtPath string
	err := withLock(func() error {
		evs, err := readAllEvents()
		if err != nil {
			return err
		}
		if hasDispatched(evs, n) {
			return errAlreadyDispatched
		}
		wts, err := orcaPS()
		if err != nil {
			return err
		}
		if w := worktreeFor(wts, cfg.Short(), n); w != nil {
			return fmt.Errorf("issue %d already has a worktree without a dispatched event: %s", n, w.Path)
		}
		out, err := runOrca("worktree", "create",
			"--repo", "path:"+cfg.RepoPath,
			"--issue", fmt.Sprint(n),
			"--name", fmt.Sprintf("issue-%d", n),
			"--no-parent", "--json")
		if err != nil {
			return err
		}
		var doc any
		if err := json.Unmarshal(out, &doc); err != nil {
			return fmt.Errorf("parse orca worktree create: %w", err)
		}
		wtPath = findPath(doc)
		if wtPath == "" {
			return fmt.Errorf("orca worktree create returned no path: %s", strings.TrimSpace(string(out)))
		}
		lock := exec.Command("git", "-C", wtPath, "worktree", "lock", "--reason", fmt.Sprintf("%s#%d open", cfg.Repo, n), wtPath)
		if b, err := lock.CombinedOutput(); err != nil {
			return fmt.Errorf("git worktree lock: %v: %s", err, strings.TrimSpace(string(b)))
		}
		if _, err := runOrca("terminal", "create",
			"--worktree", "path:"+wtPath,
			"--title", fmt.Sprintf("%s#%d", cfg.Short(), n),
			"--command", workerCommand(cfg, n),
			"--json"); err != nil {
			return fmt.Errorf("worktree %s is created and locked, but the worker did not start: %w", wtPath, err)
		}
		return appendEvent(Event{Issue: n, By: by, Type: "dispatched"})
	})
	return wtPath, err
}

// cleanup runs after an Issue is closed: it removes the nested .repos/*
// worktrees without --force (so uncommitted work stops it) and then unlocks
// the origin worktree for the regular 72h removal.
func cleanup(cfg Config, n int) ([]string, error) {
	var done []string
	err := withLock(func() error {
		state, err := fetchIssueState(cfg.Repo, n)
		if err != nil {
			return err
		}
		if state != "closed" {
			return fmt.Errorf("issue %d is %s; cleanup runs only after it is closed", n, state)
		}
		wts, err := orcaPS()
		if err != nil {
			return err
		}
		w := worktreeFor(wts, cfg.Short(), n)
		if w == nil {
			return fmt.Errorf("issue %d has no worktree", n)
		}
		nested, _ := filepath.Glob(filepath.Join(w.Path, ".repos", "*"))
		for _, dir := range nested {
			if st, err := os.Stat(dir); err != nil || !st.IsDir() {
				continue
			}
			status, err := exec.Command("git", "-C", dir, "status", "--porcelain").Output()
			if err != nil {
				return fmt.Errorf("git status %s: %w", dir, err)
			}
			if len(strings.TrimSpace(string(status))) > 0 {
				return fmt.Errorf("%s has uncommitted changes; commit or discard them, then run cleanup again", dir)
			}
			common, err := exec.Command("git", "-C", dir, "rev-parse", "--path-format=absolute", "--git-common-dir").Output()
			if err != nil {
				return fmt.Errorf("git rev-parse %s: %w", dir, err)
			}
			mainRepo := filepath.Dir(strings.TrimSpace(string(common)))
			// unlock fails harmlessly when the worker never locked it.
			_ = exec.Command("git", "-C", mainRepo, "worktree", "unlock", dir).Run()
			if b, err := exec.Command("git", "-C", mainRepo, "worktree", "remove", dir).CombinedOutput(); err != nil {
				return fmt.Errorf("git worktree remove %s: %v: %s", dir, err, strings.TrimSpace(string(b)))
			}
			done = append(done, "removed "+dir)
		}
		if b, err := exec.Command("git", "-C", w.Path, "worktree", "unlock", w.Path).CombinedOutput(); err != nil {
			msg := strings.TrimSpace(string(b))
			if !strings.Contains(msg, "is not locked") {
				return fmt.Errorf("git worktree unlock %s: %v: %s", w.Path, err, msg)
			}
		}
		done = append(done, "unlocked "+w.Path)
		return nil
	})
	return done, err
}
