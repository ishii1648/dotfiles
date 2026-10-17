// Command board tracks Issues handed to worker Claude Code sessions: an
// append-only event log, the Control room page for the Orca browser, and the
// commands sessions use to dispatch and report.
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

const usage = `usage:
  board serve                         run the board server (launchd runs this)
  board setup [--print]               write and register the LaunchAgent
  board dispatch <N> [--by NAME]      start a worker for Issue N
  board event <N> <type> [text] [--url URL] [--by NAME]
                                      append an event (types: dispatched started
                                      question answer blocked unblocked pr revise
                                      result accepted)
  board open <N>                      bring the worker terminal of Issue N to the front
  board tasks                         print the board snapshot as JSON
  board cleanup <N>                   after Issue N is closed: remove .repos/*
                                      and unlock its worktree
  board sync-research [N] [--if-older 30m]
                                      mirror research/<N>/*.md to the Issue

--by defaults to $BOARD_BY; N defaults to $BOARD_ISSUE where noted.`

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "board:", err)
		os.Exit(1)
	}
}

// splitArgs separates --flag value pairs from positionals so flags may appear
// anywhere, which is how skills tend to write them.
func splitArgs(args []string, flags ...string) (map[string]string, []string, error) {
	want := map[string]bool{}
	for _, f := range flags {
		want[f] = true
	}
	opts := map[string]string{}
	var pos []string
	for i := 0; i < len(args); i++ {
		a := args[i]
		if strings.HasPrefix(a, "--") {
			name, val, hasVal := strings.Cut(a[2:], "=")
			if !want[name] {
				return nil, nil, fmt.Errorf("unknown flag --%s", name)
			}
			if !hasVal {
				if name == "print" {
					val = "true"
				} else {
					if i+1 >= len(args) {
						return nil, nil, fmt.Errorf("--%s needs a value", name)
					}
					i++
					val = args[i]
				}
			}
			opts[name] = val
			continue
		}
		pos = append(pos, a)
	}
	return opts, pos, nil
}

func issueArg(pos []string, i int, envFallback bool) (int, error) {
	if len(pos) > i {
		n, err := strconv.Atoi(strings.TrimPrefix(pos[i], "#"))
		if err != nil || n <= 0 {
			return 0, fmt.Errorf("bad issue number %q", pos[i])
		}
		return n, nil
	}
	if envFallback {
		if v := os.Getenv("BOARD_ISSUE"); v != "" {
			return strconv.Atoi(v)
		}
		return 0, nil
	}
	return 0, errors.New("issue number required")
}

func byOf(opts map[string]string) string {
	if v := opts["by"]; v != "" {
		return v
	}
	if v := os.Getenv("BOARD_BY"); v != "" {
		return v
	}
	return "unknown"
}

func run(args []string) error {
	if len(args) == 0 {
		return errors.New(usage)
	}
	cmd, rest := args[0], args[1:]
	switch cmd {
	case "serve":
		cfg, err := loadConfig()
		if err != nil {
			return err
		}
		return serve(cfg)

	case "setup":
		opts, _, err := splitArgs(rest, "print")
		if err != nil {
			return err
		}
		return setup(opts["print"] == "true")

	case "dispatch":
		opts, pos, err := splitArgs(rest, "by")
		if err != nil {
			return err
		}
		n, err := issueArg(pos, 0, false)
		if err != nil {
			return err
		}
		cfg, err := loadConfig()
		if err != nil {
			return err
		}
		path, err := dispatch(cfg, n, byOf(opts))
		if errors.Is(err, errAlreadyDispatched) {
			fmt.Printf("#%d is already dispatched\n", n)
			return nil
		}
		if err != nil {
			return err
		}
		fmt.Printf("dispatched #%d: worker %s in %s\n", n, cfg.WorkerName(n), path)
		return nil

	case "event":
		opts, pos, err := splitArgs(rest, "url", "by")
		if err != nil {
			return err
		}
		if len(pos) < 2 {
			return errors.New("usage: board event <N> <type> [text] [--url URL] [--by NAME]")
		}
		n, err := issueArg(pos, 0, false)
		if err != nil {
			return err
		}
		return appendEvent(Event{Issue: n, By: byOf(opts), Type: pos[1], Text: strings.Join(pos[2:], " "), URL: opts["url"]})

	case "open":
		_, pos, err := splitArgs(rest)
		if err != nil {
			return err
		}
		n, err := issueArg(pos, 0, false)
		if err != nil {
			return err
		}
		cfg, err := loadConfig()
		if err != nil {
			return err
		}
		return openWorker(cfg, n)

	case "tasks":
		cfg, err := loadConfig()
		if err != nil {
			return err
		}
		evs, err := readAllEvents()
		if err != nil {
			return err
		}
		issues, err := fetchIssues(cfg.Repo)
		if err != nil {
			return err
		}
		snap := build(issues, evs, nil, cfg.Short(), time.Now())
		if wts, err := orcaPS(); err == nil {
			snap = build(issues, evs, wts, cfg.Short(), time.Now())
		} else {
			snap.OrcaError = err.Error()
		}
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		return enc.Encode(snap)

	case "cleanup":
		_, pos, err := splitArgs(rest)
		if err != nil {
			return err
		}
		n, err := issueArg(pos, 0, false)
		if err != nil {
			return err
		}
		cfg, err := loadConfig()
		if err != nil {
			return err
		}
		done, err := cleanup(cfg, n)
		for _, d := range done {
			fmt.Println(d)
		}
		return err

	case "sync-research":
		opts, pos, err := splitArgs(rest, "if-older")
		if err != nil {
			return err
		}
		n, err := issueArg(pos, 0, true)
		if err != nil || n == 0 {
			return err
		}
		var older time.Duration
		if v := opts["if-older"]; v != "" {
			if older, err = time.ParseDuration(v); err != nil {
				return err
			}
		}
		cfg, err := loadConfig()
		if err != nil {
			return err
		}
		return syncResearch(cfg, n, older)

	case "help", "-h", "--help":
		fmt.Println(usage)
		return nil
	}
	return fmt.Errorf("unknown command %q\n%s", cmd, usage)
}
