#!/usr/bin/env python3
import json, sys, re, subprocess, os

data = json.loads(sys.stdin.read())
session_id = data.get("session_id", "")
transcript_path = data.get("transcript_path", "")

if not session_id or not transcript_path:
    sys.exit(0)

pr_pattern = re.compile(r'https://github\.com/[^/\s"\']+/[^/\s"\']+/pull/\d+')
pr_urls = set()
try:
    with open(transcript_path, 'r') as f:
        for line in f:
            pr_urls.update(pr_pattern.findall(line))
except Exception:
    sys.exit(0)

if pr_urls:
    script = os.path.expanduser("~/.claude/scripts/session-index-update.py")
    subprocess.run([sys.executable, script, session_id] + sorted(pr_urls))
else:
    index_file = os.path.expanduser("~/.claude/session-index.jsonl")
    branch, cwd = "", ""
    if os.path.exists(index_file):
        try:
            with open(index_file, 'r') as f:
                for raw in f:
                    raw = raw.strip()
                    if not raw:
                        continue
                    entry = json.loads(raw)
                    if entry.get("session_id") == session_id:
                        if not entry.get("pr_urls"):
                            branch = entry.get("branch", "")
                            cwd = entry.get("cwd", "")
                        break
        except Exception:
            pass

    if branch and cwd:
        backfill_script = os.path.expanduser("~/.claude/scripts/session-index-backfill.py")
        subprocess.Popen(
            [sys.executable, backfill_script, session_id, branch, cwd],
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
