#!/usr/bin/env python3
import json, sys, re, subprocess, os

data = json.loads(sys.stdin.read())
session_id = data.get("session_id", "")
output = json.dumps(data.get("tool_response", {}))

pr_pattern = re.compile(r'https://github\.com/[^/\s"\']+/[^/\s"\']+/pull/\d+')
pr_urls = list(set(pr_pattern.findall(output)))

if session_id and pr_urls:
    script = os.path.expanduser("~/.claude/scripts/session-index-update.py")
    subprocess.run([sys.executable, script, session_id] + pr_urls)
