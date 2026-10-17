package main

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

const launchLabel = "com.user.board"

func plistPath() string {
	return filepath.Join(homeDir(), "Library", "LaunchAgents", launchLabel+".plist")
}

func xmlEscape(s string) string {
	var b bytes.Buffer
	xml.EscapeText(&b, []byte(s))
	return b.String()
}

// launchEnv is what `board serve` needs under launchd: gh is the ghtkn wrapper
// in ~/.local/bin, which runs aqua, which needs its config variables.
func launchEnv() map[string]string {
	env := map[string]string{"HOME": homeDir(), "PATH": os.Getenv("PATH")}
	for _, k := range []string{"AQUA_GLOBAL_CONFIG", "AQUA_ROOT_DIR", "XDG_CONFIG_HOME", "XDG_STATE_HOME", "BOARD_CONFIG", "BOARD_STATE_DIR"} {
		if v := os.Getenv(k); v != "" {
			env[k] = v
		}
	}
	return env
}

func renderPlist(bin string, env map[string]string) string {
	var b strings.Builder
	b.WriteString(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
`)
	fmt.Fprintf(&b, "  <key>Label</key><string>%s</string>\n", launchLabel)
	fmt.Fprintf(&b, "  <key>ProgramArguments</key>\n  <array><string>%s</string><string>serve</string></array>\n", xmlEscape(bin))
	b.WriteString("  <key>RunAtLoad</key><true/>\n  <key>KeepAlive</key><true/>\n")
	b.WriteString("  <key>EnvironmentVariables</key>\n  <dict>\n")
	keys := make([]string, 0, len(env))
	for k := range env {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		fmt.Fprintf(&b, "    <key>%s</key><string>%s</string>\n", xmlEscape(k), xmlEscape(env[k]))
	}
	b.WriteString("  </dict>\n")
	logPath := filepath.Join(stateDir(), "serve.log")
	fmt.Fprintf(&b, "  <key>StandardOutPath</key><string>%s</string>\n", xmlEscape(logPath))
	fmt.Fprintf(&b, "  <key>StandardErrorPath</key><string>%s</string>\n", xmlEscape(logPath))
	b.WriteString("</dict>\n</plist>\n")
	return b.String()
}

// setup writes the LaunchAgent with this binary's absolute path and the
// caller's environment, then (re)registers it. Re-running replaces it.
func setup(printOnly bool) error {
	if _, err := loadConfig(); err != nil {
		return err
	}
	bin, err := os.Executable()
	if err != nil {
		return err
	}
	if bin, err = filepath.Abs(bin); err != nil {
		return err
	}
	env := launchEnv()
	if _, ok := env["AQUA_GLOBAL_CONFIG"]; !ok {
		fmt.Fprintln(os.Stderr, "warning: AQUA_GLOBAL_CONFIG is not set; gh (aqua) may not start under launchd")
	}
	plist := renderPlist(bin, env)
	if printOnly {
		fmt.Print(plist)
		return nil
	}
	if err := ensureStateDir(); err != nil {
		return err
	}
	p := plistPath()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(p, []byte(plist), 0o644); err != nil {
		return err
	}
	domain := fmt.Sprintf("gui/%d", os.Getuid())
	_ = exec.Command("launchctl", "bootout", domain+"/"+launchLabel).Run()
	if b, err := exec.Command("launchctl", "bootstrap", domain, p).CombinedOutput(); err != nil {
		return fmt.Errorf("launchctl bootstrap: %v: %s", err, strings.TrimSpace(string(b)))
	}
	fmt.Printf("registered %s (%s)\n", launchLabel, p)
	return nil
}
