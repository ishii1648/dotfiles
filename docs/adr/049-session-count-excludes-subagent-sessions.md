# ADR-049: セッション数計測からサブエージェントセッションを除外する

## ステータス

採用済み

## コンテキスト

ADR-041 で claude-stats に「セッション数/PR」指標を追加した。この指標は「同一 PR に対して Claude を起動し直した回数」を表す工数感覚の代理指標として設計された。

しかし実際の計測では、意図より大きい値が出ることが判明した。例として `example-org/docs#854` のセッション数が 9 と表示されたが、体感ではそれほど多くなかった。

### Spike による原因調査（2026-03-05）

**当初の仮説（誤り）**: `SessionStart` フックが Task サブエージェントでも発火してセッション数が水増しされる。

**Spike で判明した事実**:

1. **`SessionStart` は Task サブエージェントでは発火しない** — デバッグログ（`~/.claude/logs/session-index-debug.log`）と session-index.jsonl を確認したところ、`/subagents/` 配下の transcript を持つエントリは存在しなかった。`parent_session_id` もフック入力に含まれなかった。

2. **真の原因: `file-history-snapshot` ゴーストファイル** — `example-org/docs#854` の 9 セッションを調査した結果、以下の内訳だった:
   - 実セッション（`type: "progress"` / user-assistant メッセージあり）: 4 件
   - ゴーストファイル（`file-history-snapshot` のみ・`sessionId` フィールドなし）: 5 件

   Claude Code はファイル編集履歴（undo 用スナップショット）として UUID 名の `.jsonl` を project ディレクトリに作成する。`session-index.sh`（SessionStart hook）がこれらの UUID で発火し、session-index.jsonl に「セッション」として記録される。

**指標の本来の意味との乖離**: セッション数は「ユーザーが Claude を起動し直した回数」を測りたいが、現状は `file-history-snapshot` のみの空セッションも計上されている。

## 設計案

### 案1（却下）: `parent_session_id` フィールドによるサブエージェント判定

Spike により `parent_session_id` がフック入力に含まれないこと・Task サブエージェントは SessionStart を発火させないことが判明。この案は前提が崩れており実現不可。

### 案2（採用）: `type: "user"` エントリ存在チェックによるゴーストセッション除外

`permission-ui-server.py` の `load_sessions()` でセッションカウントに使用する transcript を読み込む際、`type: "user"` エントリが 1 件も存在しないセッションを `is_ghost: True` とみなして `aggregate()` のセッション数カウントから除外する。

**条件**:
- transcript ファイルが存在する
- `type: "user"` の行が 0 件（= `file-history-snapshot` のみ、またはコマンド出力のみ）

**変更対象**: `permission-ui-server.py` の `load_sessions()` および `aggregate()`

### 案3（却下）: `session-index.sh` でゴーストセッションを記録しない

SessionStart フック実行時に transcript を読んで `type: "user"` の有無を確認する。しかしセッション開始直後は transcript にまだユーザーメッセージが存在しないため、開始時点での判断は不可能。

## Spike 結果（2026-03-05 完了）

- `SessionStart` フック入力フィールド: `session_id`, `transcript_path`, `cwd`, `hook_event_name`, `source`, `model` のみ。`parent_session_id` は存在しない
- Task サブエージェントの transcript は `{session_id}/subagents/agent-{agent_id}.jsonl` に格納され、SessionStart は発火しない
- ゴーストファイルの実態: `{"type":"file-history-snapshot","messageId":"...","snapshot":{...}}` のみで構成される UUID 名 JSONL ファイル（`sessionId` フィールドなし）

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-049 セクション）

## 関連 ADR

- [ADR-011](011-claude-session-index.md): session-index.jsonl の構造とセッション記録の基盤
- [ADR-041](041-claude-human-intervention-metrics-expansion.md): セッション数/PR 指標の導入（本 ADR の修正対象）
- [ADR-038](038-adr-spike-validation-pattern.md): Spike 検証パターン（案1 の前提確認に適用）
