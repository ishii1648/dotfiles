#!/usr/bin/env python3
"""
session-index.jsonl の pr_urls が空のエントリを (repo, branch) でグループ化し
gh pr list で一括補完するバッチスクリプト
Usage: python3 session-index-backfill-batch.py [--recheck]

  --recheck  backfill_checked 済みのエントリも再チェックする（救済用）
"""
import json, os, subprocess, sys
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed

INDEX_FILE = os.path.expanduser("~/.claude/session-index.jsonl")
RECHECK = "--recheck" in sys.argv

if not os.path.exists(INDEX_FILE):
    sys.exit(0)

# pr_urls が空のエントリを収集（--recheck 時は backfill_checked 済みも含む）
entries = []
try:
    with open(INDEX_FILE, 'r') as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                entry = json.loads(raw)
                if not entry.get("pr_urls") and (not entry.get("backfill_checked") or RECHECK):
                    entries.append(entry)
            except Exception:
                pass
except Exception:
    sys.exit(0)

if not entries:
    print("backfill: 対象エントリなし（全件 pr_urls 補完済み or backfill_checked 済み）")
    sys.exit(0)

# (repo, branch) でグループ化し重複排除
groups = defaultdict(list)
for entry in entries:
    repo = entry.get("repo", "")
    branch = entry.get("branch", "")
    if repo and branch:
        groups[(repo, branch)].append(entry)

update_script = os.path.expanduser("~/.claude/claudedog/batch/session-index-update.py")

print(f"backfill: {len(entries)} エントリ / {len(groups)} グループを処理中...")


def fetch_pr_url(repo_branch_entries):
    """(group_entries, url, mark_checked) を返す。
    mark_checked=True にするのは cwd が存在しない場合のみ。
    cwd が存在するが PR が見つからない場合は mark_checked=False とし、
    次回バッチで再試行できるようにする。
    """
    (repo, branch), group_entries = repo_branch_entries
    cwd = group_entries[-1].get("cwd", "")
    if not cwd or not os.path.isdir(cwd):
        # cwd が消えている → 回収不能として永続スキップ
        return group_entries, None, True
    try:
        result = subprocess.run(
            ["gh", "pr", "list", "--head", branch, "--author", "@me", "--state", "all", "--json", "url", "-q", ".[0].url"],
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=8,
        )
        url = result.stdout.strip()
        if result.returncode != 0 or "github.com" not in url:
            # PR が見つからないが cwd は存在する → 再試行の余地あり
            return group_entries, None, False
        return group_entries, url, False
    except Exception:
        return group_entries, None, False


found, skipped, retried = 0, 0, 0

with ThreadPoolExecutor(max_workers=8) as executor:
    futures = [executor.submit(fetch_pr_url, item) for item in groups.items()]
    for future in as_completed(futures):
        group_entries, url, mark_checked = future.result()
        if url:
            found += 1
            for entry in group_entries:
                session_id = entry.get("session_id", "")
                if session_id:
                    subprocess.run([sys.executable, update_script, session_id, url])
        elif mark_checked:
            # cwd が存在しない場合のみ永続スキップ
            skipped += 1
            session_ids = [e.get("session_id", "") for e in group_entries if e.get("session_id")]
            if session_ids:
                subprocess.run([sys.executable, update_script, "--mark-checked"] + session_ids)
        else:
            # cwd は存在するが PR 未作成 → 次回バッチで再試行
            retried += 1

print(f"backfill: 完了 — URL取得成功 {found} グループ / cwd消滅スキップ {skipped} グループ / 再試行待ち {retried} グループ")
