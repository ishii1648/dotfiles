#!/usr/bin/env python3
"""
session-index.jsonl の pr_urls フィールドを更新する共通ユーティリティ
Usage: session-index-update.py <session_id> <pr_url> [<pr_url> ...]
       session-index-update.py --mark-checked <session_id> [<session_id> ...]
"""
import json, sys, os

INDEX_FILE = os.path.expanduser("~/.claude/session-index.jsonl")

# --mark-checked モード
if len(sys.argv) > 1 and sys.argv[1] == "--mark-checked":
    target_ids = set(sys.argv[2:])
    if not target_ids or not os.path.exists(INDEX_FILE):
        sys.exit(0)
    lines, updated = [], False
    with open(INDEX_FILE, 'r') as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                data = json.loads(raw)
                if data.get("session_id") in target_ids and not data.get("backfill_checked"):
                    data["backfill_checked"] = True
                    updated = True
            except Exception:
                pass
            lines.append(json.dumps(data, ensure_ascii=False))
    if updated:
        with open(INDEX_FILE, 'w') as f:
            f.write('\n'.join(lines) + '\n')
    sys.exit(0)

# --by-branch モード
if len(sys.argv) > 1 and sys.argv[1] == "--by-branch":
    target_repo   = sys.argv[2] if len(sys.argv) > 2 else ""
    target_branch = sys.argv[3] if len(sys.argv) > 3 else ""
    new_url       = sys.argv[4] if len(sys.argv) > 4 else ""
    def normalize_repo(r):
        return r.removesuffix(".git")
    if not (target_repo and target_branch and new_url and os.path.exists(INDEX_FILE)):
        sys.exit(0)
    lines, updated = [], False
    with open(INDEX_FILE, 'r') as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                data = json.loads(raw)
                if (normalize_repo(data.get("repo", "")) == normalize_repo(target_repo)
                        and data.get("branch") == target_branch
                        and "pr_urls" in data
                        and new_url not in data["pr_urls"]):
                    data["pr_urls"] = sorted(set(data["pr_urls"]) | {new_url})
                    updated = True
            except Exception:
                pass
            lines.append(json.dumps(data, ensure_ascii=False))
    if updated:
        with open(INDEX_FILE, 'w') as f:
            f.write('\n'.join(lines) + '\n')
    sys.exit(0)

session_id = sys.argv[1] if len(sys.argv) > 1 else ""
new_urls = set(sys.argv[2:])

if not session_id or not new_urls or not os.path.exists(INDEX_FILE):
    sys.exit(0)

lines, updated = [], False
with open(INDEX_FILE, 'r') as f:
    for raw in f:
        raw = raw.strip()
        if not raw:
            continue
        try:
            data = json.loads(raw)
            if data.get("session_id") == session_id and "pr_urls" in data:
                existing = set(data["pr_urls"])
                before = len(existing)
                existing.update(new_urls)
                if len(existing) > before:
                    data["pr_urls"] = sorted(existing)
                    updated = True
        except Exception:
            pass
        lines.append(json.dumps(data, ensure_ascii=False))

if updated:
    with open(INDEX_FILE, 'w') as f:
        f.write('\n'.join(lines) + '\n')
