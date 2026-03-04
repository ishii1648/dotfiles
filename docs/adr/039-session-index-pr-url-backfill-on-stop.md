# ADR-039: Stop フックで既存 PR URL を補完する

## ステータス

採用済み

## コンテキスト

ADR-035 で `SessionStart` フックから `gh pr view` を削除し、PR URL の収集を PostToolUse / Stop フックに委譲した。

設計の前提は「セッション中に `gh pr` コマンドを Bash ツールで実行すれば PostToolUse フックが PR URL を検出する」だった。しかし以下のケースでは `pr_urls` が空のまま残る。

- PR が SessionStart 以前から既に存在している
- セッション中に `gh pr view` / `gh pr list` などの PR URL を返す Bash コマンドを実行しなかった
- Stop フックがトランスクリプトをスキャンしても PR URL がトランスクリプト内に存在しなかった

`session-index-post-tool.sh` は `Bash` ツールのレスポンスのみを監視しているため、ツール経由で PR URL が出力されない場合は検出できない構造的な問題がある。

## 設計案

### 案A: Stop フックで pr_urls が空なら gh pr view を非同期実行（採用）

`session-index-stop.sh` に以下のロジックを追加する。

1. `session-index.jsonl` から現セッションの `pr_urls` を確認
2. `pr_urls` が空かつブランチが存在する場合のみ `gh pr view` を**バックグラウンド（`&`）で非同期実行**
3. 取得した PR URL を `session-index-update.py` で補完

**非同期実行とする理由**: Stop フックは Claude Code の応答完了後、ユーザーが次の操作を待つタイミングで発火する。`gh pr view` を同期実行するとネットワーク待ちがそのまま体感レイテンシになり UX が悪化する。バックグラウンド実行にすることで Stop フック自体は即座に戻り、補完処理はユーザー操作と並行して完了する。

**変更対象**:

| ファイル | 変更内容 |
|----------|----------|
| `configs/claude/scripts/session-index-stop.sh` | `pr_urls` 空チェック + `gh pr view` の非同期補完ロジックを追加 |

セッション終了時の非同期実行のため、起動時間（ADR-035 の改善）にも Stop フックの応答性にも影響しない。

### 案B: PostToolUse の matcher を全ツールに拡張（却下）

`session-index-post-tool.sh` の matcher を `Bash` 以外のツールにも拡張する。

却下理由: 全ツールのレスポンスを監視するとオーバーヘッドが大きく、かつ PR URL が Bash 以外のレスポンスに含まれることは稀で根本解決にならない。

### 案C: SessionStart で非同期 gh pr view（却下）

ADR-035 案B で検討・却下済み。SessionStart 時点ではバックグラウンドプロセスが JSONL に書き戻すタイミング制御が複雑になる。Stop フック（案A）はセッション終了後に発火するため、書き戻し競合のリスクがなくシンプルに実装できる。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-039 セクション）

## 関連 ADR

- 依存: [ADR-011](011-claude-session-index.md)（session-index の基本設計）
- 依存: [ADR-035](035-claude-session-index-startup-optimization.md)（SessionStart の `gh pr view` 削除、本 ADR が解決する前提崩れの原因）
- 部分廃止: [ADR-040](040-session-index-pr-url-backfill-cron-batch.md)（Stop フック else ブランチの backfill ロジックを削除し、launchd cron バッチ（`StartInterval: 3600`、毎時）に移行）
