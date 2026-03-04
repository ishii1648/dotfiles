#!/usr/bin/env python3
"""
session-index.jsonl の pr_urls が空のエントリを (repo, branch) でグループ化し
gh pr view で一括補完するバッチスクリプト
Usage: python3 session-index-backfill-batch.py
"""
import json, os, subprocess, sys
from collections import defaultdict

INDEX_FILE = os.path.expanduser("~/.claude/session-index.jsonl")

if not os.path.exists(INDEX_FILE):
    sys.exit(0)

# pr_urls が空のエントリを収集
entries = []
try:
    with open(INDEX_FILE, 'r') as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                entry = json.loads(raw)
                if not entry.get("pr_urls"):
                    entries.append(entry)
            except Exception:
                pass
except Exception:
    sys.exit(0)

if not entries:
    sys.exit(0)

# (repo, branch) でグループ化し重複排除
# 同グループ最新エントリ（末尾）の cwd を使用
groups = defaultdict(list)
for entry in entries:
    repo = entry.get("repo", "")
    branch = entry.get("branch", "")
    if repo and branch:
        groups[(repo, branch)].append(entry)

update_script = os.path.expanduser("~/.claude/scripts/session-index-update.py")

for (repo, branch), group_entries in groups.items():
    # 最新エントリの cwd を使用
    cwd = group_entries[-1].get("cwd", "")
    if not cwd or not os.path.isdir(cwd):
        continue

    try:
        # open/closed/merged すべての状態を検索（マージ済みブランチ削除後も対応）
        result = subprocess.run(
            ["gh", "pr", "list", "--head", branch, "--state", "all", "--json", "url", "-q", ".[0].url"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=8,
        )
        url = result.stdout.strip()
        if result.returncode != 0 or "github.com" not in url:
            continue
    except Exception:
        continue

    # 同グループの全 session_id に補完
    for entry in group_entries:
        session_id = entry.get("session_id", "")
        if session_id:
            subprocess.run([sys.executable, update_script, session_id, url])
