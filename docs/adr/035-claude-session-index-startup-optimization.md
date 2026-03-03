# ADR-035: Claude Code 起動時の session-index.sh ネットワーク呼び出し最適化

## ステータス

採用済み

## コンテキスト

Claude Code の起動（セッション開始）に 2〜5 秒かかる問題がある。

`SessionStart` フックで毎回実行される `configs/claude/scripts/session-index.sh` が `gh pr view` を呼び出し、GitHub API への HTTP リクエストを発行している。ネットワーク状況次第で 1〜3 秒のレイテンシが発生するため、これが主因となっている。

```bash
# configs/claude/scripts/session-index.sh（現状）
if [ -n "$BRANCH" ] && [ -n "$REMOTE_URL" ] && command -v gh > /dev/null 2>&1; then
    PR_URL=$(GIT_DIR="$CWD/.git" gh pr view "$BRANCH" --json url -q '.url' 2>/dev/null || echo "")
fi
```

なお `session-index-post-tool.sh`（PostToolUse フック）と `session-index-stop.sh`（Stop フック）がすでに PR URL を抽出・更新する仕組みを持っており、SessionStart 時点での `gh pr view` は機能的に重複している。

副因として以下も存在するが、本 ADR では扱わない：

- MCP サーバーの多数並列起動（datadog / slack / atlassian-v2 / terraform 等）
- `session-index.jsonl` の肥大化（250 行超）

## 設計案

### 案A: `gh pr view` を session-index.sh から削除（採用）

SessionStart 時の `gh pr view` 呼び出しを削除する。PR URL の収集は PostToolUse / Stop フックに完全委譲する。

**変更対象**:

| ファイル | 変更内容 |
|----------|----------|
| `configs/claude/scripts/session-index.sh` | `gh pr view` の 3 行を削除 |

初回セッションでは PR URL が空のレコードが記録されるが、`gh pr` コマンド実行後の PostToolUse / Stop が PR URL を補完する。PR が存在しないブランチでは元々 PR URL が空になるため、動作上の差異はない。

### 案B: `gh pr view` を非同期化（却下）

バックグラウンドで `gh pr view` を実行し、セッション開始を非ブロッキングにする。

却下理由: 非同期実行後に結果を JSONL に書き戻す仕組みが必要で複雑になる。案A の方がシンプルかつ副作用がない。

### 案C: `session-index.jsonl` のトリミング（別課題）

250 行超に肥大化した `session-index.jsonl` を定期的にトリミングし、直近 N 件のみ保持する。

副因であり本 ADR のスコープ外。必要であれば別 ADR を立てる。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-035 セクション）
