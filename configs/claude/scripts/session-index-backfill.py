#!/usr/bin/env python3
"""
Stop フックで pr_urls が空の場合に gh pr view で補完する
Usage: session-index-backfill.py <session_id> <branch> <cwd>
"""
import sys, os, subprocess

session_id = sys.argv[1] if len(sys.argv) > 1 else ""
branch = sys.argv[2] if len(sys.argv) > 2 else ""
cwd = sys.argv[3] if len(sys.argv) > 3 else ""

if not session_id or not branch or not cwd:
    sys.exit(0)

try:
    result = subprocess.run(
        ["gh", "pr", "view", branch, "--json", "url", "-q", ".url"],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=8,
    )
    url = result.stdout.strip()
    if result.returncode == 0 and "github.com" in url:
        update_script = os.path.expanduser("~/.claude/scripts/session-index-update.py")
        subprocess.run([sys.executable, update_script, session_id, url])
except Exception:
    sys.exit(0)
