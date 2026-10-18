package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path"
	"path/filepath"
)

const defaultPort = 7342

type Config struct {
	// Repo is the origin repository as owner/name. Every Issue lives here.
	Repo string `json:"repo"`
	// RepoPath is the main checkout of Repo; dispatch cuts worktrees from it.
	RepoPath string `json:"repo_path"`
	Port     int    `json:"port"`
}

func homeDir() string {
	h, err := os.UserHomeDir()
	if err != nil {
		return "."
	}
	return h
}

func configPath() string {
	if p := os.Getenv("BOARD_CONFIG"); p != "" {
		return p
	}
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(homeDir(), ".config")
	}
	return filepath.Join(base, "board", "config.json")
}

func stateDir() string {
	if p := os.Getenv("BOARD_STATE_DIR"); p != "" {
		return p
	}
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		base = filepath.Join(homeDir(), ".local", "state")
	}
	return filepath.Join(base, "board")
}

func eventsPath() string { return filepath.Join(stateDir(), "events.jsonl") }

func loadConfig() (Config, error) {
	var c Config
	p := configPath()
	b, err := os.ReadFile(p)
	if err != nil {
		return c, fmt.Errorf("read %s: %w (setup.sh の board component が作る)", p, err)
	}
	if err := json.Unmarshal(b, &c); err != nil {
		return c, fmt.Errorf("parse %s: %w", p, err)
	}
	if c.Repo == "" || c.RepoPath == "" {
		return c, fmt.Errorf("%s: repo と repo_path が必要", p)
	}
	if c.Port == 0 {
		c.Port = defaultPort
	}
	return c, nil
}

// Short is the repository name used in worker names (hub-42) and titles (hub#42).
func (c Config) Short() string { return path.Base(c.Repo) }

func (c Config) WorkerName(n int) string { return fmt.Sprintf("%s-%d", c.Short(), n) }
