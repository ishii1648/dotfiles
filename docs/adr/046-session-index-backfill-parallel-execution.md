# ADR-046: session-index-backfill-batch.py の並列実行化

## ステータス

採用済み

## 関連 ADR

- 依存: [ADR-040](040-session-index-pr-url-backfill-cron-batch.md) — バッチスクリプトの基本設計
- スキーマ変更: [ADR-011](011-claude-session-index.md) — session-index.jsonl のデータ構造定義

## コンテキスト

ADR-040 で導入した `session-index-backfill-batch.py` は、`pr_urls` が空の `(repo, branch)` グループごとに `gh pr list` を逐次実行する。

現時点で session-index.jsonl には 371 エントリ・58 ユニークグループが存在し、1 グループあたり最大 8 秒（タイムアウト設定値）かかるため、最悪ケースで **約 8 分** 要する計算になる。実際にユーザーが 10 秒以上応答なしでキャンセルする事態が発生した。

`gh pr list` は独立した API 呼び出しであり、グループ間に依存関係がないため並列化が適用できる。

さらに根本的な問題として、**PR が存在しないグループが毎回リトライされ続ける**ことがある。現行スクリプトは `pr_urls` が空であることのみを処理条件にしているため、`master` / `main` ブランチのセッション（PR を作らない作業）は永遠に API を呼び続ける。実データでは `ishii1648/dotfiles master` が 128 エントリと最多であり、このグループは毎回 `gh pr list` を呼んでも空振りが確定している。

バッチ実行済み（= チェック完了）のエントリにフラグを立てることで、新規エントリのみを処理対象とし、不要な API 呼び出しを排除できる。

## 設計案

### 案A: ThreadPoolExecutor で並列実行（採用）

`concurrent.futures.ThreadPoolExecutor` を使い、各グループの `gh pr list` を並列実行する。

**変更概要:**

- グループごとの処理を関数に切り出す（`fetch_pr_url(repo, branch, group_entries)`）
- `ThreadPoolExecutor(max_workers=8)` で全グループを並列サブミット
- 結果収集後に `session-index-update.py` を呼び出す（書き込みは逐次）

**並列数の根拠:**

- GitHub API のレート制限（認証済みで 5,000 req/h）に対して 58 グループ × 並列 8 は十分安全
- 実行頻度が毎時 1 回のため累積リクエスト数も問題なし

**期待される改善:**

| 条件 | 現行（逐次） | 改善後（並列 8） |
|------|------------|----------------|
| 全グループ正常応答（1秒/件） | 約 58 秒 | 約 8 秒 |
| 全グループタイムアウト（8秒/件） | 約 8 分 | 約 8 秒 |

**`backfill_checked` フラグによるスキップ:**

本 ADR は ADR-011 で定義された session-index.jsonl のスキーマに `backfill_checked` フィールドを追加する。

ADR-011 の既存スキーマ:

```json
{
  "timestamp": "...", "session_id": "...", "cwd": "...",
  "repo": "...", "branch": "...", "pr_urls": [...], "transcript": "..."
}
```

本 ADR 追加後のスキーマ（`backfill_checked` を追記）

```json
{
  "timestamp": "...", "session_id": "...", "cwd": "...",
  "repo": "...", "branch": "...", "pr_urls": [...], "transcript": "...",
  "backfill_checked": true
}
```

- `backfill_checked` は PR URL が取得できなかった場合のみ書き込む（省略 = 未処理）
- 後方互換: フィールドなしの既存エントリは未処理として扱い、動作に変化なし

バッチ実行時の処理フロー:

| 結果 | 処理 |
|------|------|
| PR URL が取得できた | `pr_urls` に URL を追加（既存動作） |
| PR URL が取得できなかった | `backfill_checked: true` をエントリに追記 |
| 既に `backfill_checked: true` のエントリ | スキップ（API 呼び出しなし） |
| 新規エントリ（`backfill_checked` フィールドなし） | 処理対象 |

これにより `master` / `main` ブランチのセッションは初回チェック後に永続スキップされる。

**変更が必要なファイル:**

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `configs/claude/scripts/session-index-backfill-batch.py` | dotfiles | ThreadPoolExecutor で並列実行 + `backfill_checked` フラグの読み書きを追加 |
| `configs/claude/scripts/session-index-update.py` | dotfiles | `backfill_checked: true` を書き込む機能を追加 |

### 案B: asyncio + asyncio.subprocess で非同期実行（却下）

却下理由: Python 標準の `asyncio.create_subprocess_exec` は Python 3.7+ で利用可能だが、`subprocess.run` の単純な並列化としては ThreadPoolExecutor の方がコードが簡潔で理解しやすい。非同期 I/O の恩恵がスレッドプールより大きくなるほどのスループットは今回の用途では不要。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-046 セクション）
