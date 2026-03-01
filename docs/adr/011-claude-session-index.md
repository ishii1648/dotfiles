# ADR-011: Claude セッションを PR ベースで追跡する

## ステータス

採用済み

## コンテキスト

Claude Code で複数リポジトリ・複数ブランチを並行して作業すると、どのセッションがどの PR に対応するかが分からなくなる。セッション終了後に「あのセッションで何の PR を作ったか」を振り返ろうとしても、トランスクリプトを手動で探す必要があった。

セッション単位で以下の情報を自動収集・蓄積できれば、後から PR ベースで作業を追跡できる：

- セッション開始時刻・ID
- 作業ディレクトリ・リポジトリ・ブランチ
- セッション中に作成・参照した PR の URL

- [Claude Code Hooks ドキュメント](https://docs.anthropic.com/en/docs/claude-code/hooks)

## 設計案

### 構成

| コンポーネント | パス | Hook |
|---------------|------|------|
| セッション開始記録 | `configs/claude/scripts/session-index.sh` | SessionStart |
| ツール出力からの PR URL 抽出 | `configs/claude/scripts/session-index-post-tool.sh` | PostToolUse |
| トランスクリプト全体からの PR URL 抽出 | `configs/claude/scripts/session-index-stop.sh` | Stop |
| PR URL 増分更新ユーティリティ | `configs/claude/scripts/session-index-update.py` | 上記から呼び出し |

### データ構造

記録先: `~/.claude/session-index.jsonl`（JSON Lines 形式）

```json
{
  "timestamp": "2026-02-27 12:34:56",
  "session_id": "xxx-yyy-zzz",
  "cwd": "/path/to/project",
  "repo": "org/repo",
  "branch": "feature-xxx",
  "pr_urls": ["https://github.com/org/repo/pull/123"],
  "transcript": "/path/to/transcript.json"
}
```

### 処理フロー

```
SessionStart
  → session-index.sh
    → git remote / branch / gh pr view で初期メタデータ取得
    → ~/.claude/session-index.jsonl に新規レコード追記

PostToolUse
  → session-index-post-tool.sh
    → tool_response から PR URL を正規表現で抽出
    → session-index-update.py <session_id> <pr_url...> を呼び出し

Stop
  → session-index-stop.sh
    → トランスクリプトファイルを全行スキャンして PR URL を抽出
    → session-index-update.py <session_id> <pr_url...> を呼び出し

session-index-update.py
  → session-index.jsonl を読み込み
  → session_id に一致するレコードの pr_urls に新規 URL をマージ（重複排除・ソート）
  → 変更があった場合のみ再書き込み
```

### 設計方針

- **JSON Lines 形式**: 1セッション1行で追記のみ。読み込みは全行スキャンで、ファイルロックや DB 不要
- **増分更新**: PostToolUse と Stop の両方が PR URL を収集し、重複は排除する。これにより途中で PR が作成された場合も最終的に記録される
- **リモートなしリポジトリ対応**: `git remote` が空の場合は ghq パス構造（`~/ghq/<host>/<org>/<repo>`）から repo 名を推測
- **エラー無視**: hook の失敗がセッション全体に影響しないよう、各スクリプトは例外・ファイル不在を黙認して終了
- **PR URL パターン**: `https://github.com/<owner>/<repo>/pull/<number>` を正規表現でマッチ。GitHub Actions URL などの誤検知を防ぐため `pull/` を必須とする

Claude Code の hooks を活用して、セッションメタデータと PR URL を `~/.claude/session-index.jsonl` に自動記録する。PostToolUse と Stop の2段階で収集することで途中作成の PR も記録漏れなく収集できる。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-011 セクション）
