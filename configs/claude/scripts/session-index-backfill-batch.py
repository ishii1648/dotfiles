#!/usr/bin/env python3
"""
session-index.jsonl の pr_urls が空のエントリを (repo, branch) でグループ化し
gh pr list で一括補完するバッチスクリプト
Usage: python3 session-index-backfill-batch.py
"""
import json, os, subprocess, sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed

INDEX_FILE = os.path.expanduser("~/.claude/session-index.jsonl")

if not os.path.exists(INDEX_FILE):
    sys.exit(0)

# pr_urls が空 かつ backfill_checked でないエントリを収集
entries = []
try:
    with open(INDEX_FILE, 'r') as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                entry = json.loads(raw)
                if not entry.get("pr_urls") and not entry.get("backfill_checked"):
                    entries.append(entry)
            except Exception:
                pass
except Exception:
    sys.exit(0)

if not entries:
    sys.exit(0)

# (repo, branch) でグループ化し重複排除
groups = defaultdict(list)
for entry in entries:
    repo = entry.get("repo", "")
    branch = entry.get("branch", "")
    if repo and branch:
        groups[(repo, branch)].append(entry)

update_script = os.path.expanduser("~/.claude/scripts/session-index-update.py")


def fetch_pr_url(repo_branch_entries):
    (repo, branch), group_entries = repo_branch_entries
    cwd = group_entries[-1].get("cwd", "")
    if not cwd or not os.path.isdir(cwd):
        return group_entries, None
    try:
        result = subprocess.run(
            ["gh", "pr", "list", "--head", branch, "--state", "all", "--json", "url", "-q", ".[0].url"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=8,
        )
        url = result.stdout.strip()
        if result.returncode != 0 or "github.com" not in url:
            return group_entries, None
        return group_entries, url
    except Exception:
        return group_entries, None


with ThreadPoolExecutor(max_workers=8) as executor:
    futures = [executor.submit(fetch_pr_url, item) for item in groups.items()]
    for future in as_completed(futures):
        group_entries, url = future.result()
        if url:
            for entry in group_entries:
                session_id = entry.get("session_id", "")
                if session_id:
                    subprocess.run([sys.executable, update_script, session_id, url])
        else:
            session_ids = [e.get("session_id", "") for e in group_entries if e.get("session_id")]
            if session_ids:
                subprocess.run([sys.executable, update_script, "--mark-checked"] + session_ids)
