# ADR-036: Notification hook による permission UI 表示回数の計測

## ステータス

採用済み

## コンテキスト

Claude Code が PR 作成までにどれだけ自律的に動作できているかを可視化したい。指標の一つとして「permission UI が何回表示されたか（= 人間が承認/拒否操作を求められた回数）」を PR ごとに計測したい。

現状の transcript からわかること：

- **拒否イベント**: ユーザーが Deny または ESC で中断した場合、`[Request interrupted by user for tool use]` というメッセージが `type: "user"` イベントとして記録される
- **承認イベント**: 承認した場合は通常の `tool_result` として流れるだけで、承認操作の明示的な記録がない
- **permissionMode**: ユーザーが発言した際のメッセージに `permissionMode: "default" | "acceptEdits"` が記録される

PreToolUse hook はツール実行直前（= ユーザーが Approve した後）に発火するため、hook のログが「承認済み permission UI の回数」の代理指標になる可能性がある。ただし以下の不確かさがある：

1. `acceptEdits` モードでも PreToolUse は発火するが permission UI は表示されない
2. `permissions.allow` で自動承認されたツールにも PreToolUse が発火する（permission UI なし）
3. hook に `permissionMode` の情報が渡されるか未確認

## 設計案

### 案A: PreToolUse hook でログ記録（採用候補）

PreToolUse フックでツール名・セッション ID・タイムスタンプ・permissionMode を `~/.claude/logs/permission-approved.log` に追記する。

拒否分は transcript の `[Request interrupted by user for tool use]` をパースして補完し、両者を合算することで permission UI 表示回数を推定する。

| ファイル | 変更内容 |
|----------|----------|
| `configs/claude/scripts/permission-log.sh` | 新規作成（PreToolUse hook 用ログスクリプト） |
| `configs/claude/settings.json` | PreToolUse hook への登録 |

**未解決事項**:
- `CLAUDE_PERMISSION_MODE` 環境変数が hook スクリプトに渡されるか要検証
- `permissions.allow` による自動承認と permission UI 経由の承認を区別する手段が必要

### 案B: transcript パースのみ（却下）

hook を追加せず、transcript から `[Request interrupted by user for tool use]` のみをカウントする。

Deny 数は正確に取れるが、Approve 数は取れないため「permission UI 表示回数」の完全計測にはならない。

### 案C: Notification: permission_prompt hook を使う（採用）

`Notification: permission_prompt` は permission UI が **表示されたタイミング** で発火する。

- Approve / Deny の前に発火 → 両方をカウントできる
- `permissions.allow` で自動承認された場合は発火しない（UI が出ないから）
- `permissionMode` の心配も不要（permission UI が表示される = acceptEdits モードではない）

既存の `claude-notify.sh` と同様に、`Notification: permission_prompt` hooks 配列に `permission-log.sh` を追加する。

| ファイル | 変更内容 |
|----------|----------|
| `configs/claude/scripts/permission-log.sh` | 新規作成（Notification: permission_prompt hook 用ログスクリプト） |
| `configs/claude/settings.json` | Notification.permission_prompt hooks への登録 |
| `configs/claude/scripts/permission-ui-server.py` | 新規作成（可視化 Web サーバ、port 18765、純粋 SVG グラフ） |
| `configs/claude/scripts/permission-ui-start.sh` | 新規作成（二重起動防止付き起動スクリプト） |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-036 セクション）
