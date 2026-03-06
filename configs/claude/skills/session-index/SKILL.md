---
name: session-index
description: >-
  Reference-only guide for searching Claude Code session logs via
  ~/.claude/session-index.jsonl. Use when you need to find past sessions
  by date, repository, or branch. Do NOT trigger for general questions
  about Claude Code — only use when session log retrieval is explicitly needed.
---

# Session Index 検索ガイド

セッション開始時に SessionStart フックで `~/.claude/session-index.jsonl` へ記録される。
各行は以下の JSON 形式:

```json
{
  "timestamp": "2026-02-19 10:23:45",
  "session_id": "abc-123",
  "cwd": "/Users/sho/ghq/github.com/C-FO/aws-infra",
  "repo": "C-FO/aws-infra",
  "branch": "fix/something",
  "pr_urls": ["https://github.com/C-FO/aws-infra/pull/123"],
  "transcript": "/Users/sho/.claude/projects/.../00893aaf.jsonl"
}
```

## 検索コマンド

### 日付で絞り込む
```bash
cat ~/.claude/session-index.jsonl | jq 'select(.timestamp | startswith("2026-02-19"))'
```

### リポジトリで絞り込む
```bash
cat ~/.claude/session-index.jsonl | jq 'select(.repo == "C-FO/aws-infra")'
```

### ブランチで絞り込む
```bash
cat ~/.claude/session-index.jsonl | jq 'select(.branch | startswith("fix/"))'
```

### transcript パスを取得してログを参照する
```bash
# 最新セッションのログを表示
cat ~/.claude/session-index.jsonl \
  | jq -r 'select(.repo == "C-FO/aws-infra") | .transcript' \
  | tail -1 \
  | xargs cat
```

### 複合条件で絞り込む
```bash
cat ~/.claude/session-index.jsonl \
  | jq 'select(.repo == "C-FO/aws-infra" and (.timestamp | startswith("2026-02")))'
```

### PR URL を持つセッションのみ表示
```bash
cat ~/.claude/session-index.jsonl | jq 'select(.pr_urls | length > 0)'
```

### 特定 PR に関連するセッションを探す
```bash
cat ~/.claude/session-index.jsonl | jq 'select(.pr_urls[]? | contains("/pull/123"))'
```
