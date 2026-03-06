# ADR-044: ADR-040 採用後に意味を失った PR URL 収集 hook を削除する

## ステータス

採用済み

## コンテキスト

ADR-040 で session-index の pr_urls 補完を cron バッチ（`session-index-backfill-batch.py`）に移行した。
バッチは `repo + branch → gh pr list` で**正確に**PR URL を紐づける。

しかし、それ以前に ADR-011・ADR-039 で実装した以下の hook が削除されずに残っている。

| コンポーネント | 動作 | 問題 |
|---|---|---|
| `session-index-post-tool.sh`（PostToolUse/Bash hook） | Bash ツールのレスポンス全体を正規表現スキャンして PR URL を収集 | 他人の PR URL も無差別に収集し `pr_urls` に書き込む |
| `session-index-stop.sh` のトランスクリプトスキャン部分（Stop hook） | セッション終了時にトランスクリプト全行をスキャンして PR URL を収集 | 同様に会話内に登場した他人の PR URL が混入する |

### バグの構造

バッチは「`pr_urls` が空のエントリのみ」を補完対象とする。
hook が先に誤った URL を書き込んでしまうと、バッチはそのエントリをスキップし、誤 URL が永続する。

```
[hook による誤混入]                        [バッチによる正確な補完]
PostToolUse → 他人の PR URL を書き込む → pr_urls が "空でない" → バッチがスキップ
Stop（スキャン） → 同様 ──────────────────↗                      ↑
                                                               誤 URL が永続
```

この構造が `example-org/app#9386` のような「自分が作っていない PR が集計に混入する」バグの根本原因である。

### 影響範囲の整理

- ADR-040 採用後、PR URL の正式な収集はバッチのみで完結する設計になった
- PostToolUse hook は ADR-040 で廃止が明示されていなかったため削除漏れとなった
- `session-index-stop.sh` については ADR-040 が「ADR-039 の else ブランチを削除」とのみ言及しており、ADR-011 由来のトランスクリプトスキャン部分を残す意図があったが、これも同様の問題を起こす

## 設計案

### 案A: 誤混入する hook をすべて削除（採用）

| ファイル | 変更内容 |
|---|---|
| `configs/claude/settings.json` | PostToolUse/Bash の `session-index-post-tool.sh` エントリを削除 |
| `configs/claude/scripts/session-index-post-tool.sh` | ファイルごと削除（`git rm`） |
| `configs/claude/scripts/session-index-stop.sh` | トランスクリプトスキャンのロジックを削除。ファイル自体は Stop hook の他機能（`claude-pane-state.sh idle`）と分離されているため削除 |

Stop hook のエントリ（`settings.json`）も `session-index-stop.sh` 用に設定されているため、同エントリを削除する。
`claude-pane-state.sh idle` は Stop hook の別エントリに設定済みのため影響なし。

### 案B: hook に「自分の PR のみ収集」ロジックを追加（却下）

バッチと同様に `gh pr list --head <branch>` で確認する実装を検討できるが、以下の理由で却下する。

- バッチが既に同様の機能を担っており重複する
- hook は毎ツール呼び出しで発火するため、`gh pr list` のネットワーク呼び出しが頻発してパフォーマンスに悪影響
- ADR-035 が SessionStart の `gh pr view` を削除した理由（ネットワーク遅延）と矛盾する

### 既存の汚染データへの対応

すでに誤 URL が `pr_urls` に書き込まれているエントリはバッチが補正できない。
本 ADR のスコープ外とするが、手動クリーニングまたは別 ADR で対処する。

### 削除後に残る PR/session 紐づけコンポーネント

本 ADR の削除後、PR/session 紐づけを担うコンポーネントは以下のみとなる。

| スクリプト | Hook / 実行タイミング | 役割 |
|---|---|---|
| `configs/claude/scripts/session-index.sh` | SessionStart | セッション開始時に `session-index.jsonl` へ新規レコードを追記する（`pr_urls: []` 空で登録）|
| `configs/claude/launchd/com.user.session-index-backfill.plist` | macOS launchd | バッチを毎時・ログイン時に定期実行するスケジューラ |
| `configs/claude/scripts/session-index-backfill-batch.py` | launchd から起動（毎時・ログイン時） | `pr_urls` が空のエントリを `(repo, branch)` でグループ化し `gh pr list --head <branch>` で正確に補完する |
| `configs/claude/scripts/session-index-update.py` | バッチから呼び出し | `session-index.jsonl` の特定 session_id の `pr_urls` を増分更新するユーティリティ |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-044 セクション）

## 関連 ADR

- 部分廃止: [ADR-011](011-claude-session-index.md)（PostToolUse / Stop hook による PR URL 収集を削除）
- 部分廃止: [ADR-039](039-session-index-pr-url-backfill-on-stop.md)（Stop hook のトランスクリプトスキャンを削除）
- 依存: [ADR-040](040-session-index-pr-url-backfill-cron-batch.md)（cron バッチ方式への移行）
