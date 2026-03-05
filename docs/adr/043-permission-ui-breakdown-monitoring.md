# ADR-043: permission UI 内訳の監視

## ステータス

採用済み

## 関連 ADR

- 依存: ADR-036（permission UI 計測の基盤）
- 関連: ADR-037（自律度指標）、ADR-041（介入指標拡張）、ADR-042（時系列トレンド）

## コンテキスト

ADR-036 で `Notification: permission_prompt` hook により permission UI の発生回数を計測できるようになった。しかし `permission.log` に記録されるのは `timestamp + session_id` のみであり、以下の内訳が取れていない。

1. **どのツールが原因か不明** — `permission.log` に `tool_name` がないため、Bash / Edit / Write 等のどれが permission UI を発生させたか追跡できない
2. **承認/拒否の結果が不明** — permission UI に対してユーザーが allow したか deny したかが記録されない
3. **hook 起因の deny と通常の permission UI が混在** — `redirect-to-tools.py`（PreToolUse deny）はユーザーに判断を委ねない自動ブロックだが、`permission_prompt` 通知との区別がついていない可能性がある

これにより `perm_rate` の改善施策を検討する際に「何を変えれば効果的か」が判断できない。

## 設計案

### 案A: Notification ペイロードを拡張して tool_name を記録する（不採用）

`permission_prompt` Notification イベントのペイロードに `tool_name` が含まれているかを調査し、含まれていれば `permission-log.sh` を拡張してログに追記する。

- メリット: `permission-log.sh` の改修のみで内訳が取れる
- **Spike 調査結果（2026-03-04）**: `permission_prompt` Notification ペイロードに `tool_name` フィールドは存在しない。`jq -r '.tool_name // "unknown"'` は常に `"unknown"` を返すことが permission.log の全エントリで確認された。案A は不成立。

### 案B: hook 起因の deny を permission.log から分離する（採用済み）

`redirect-to-tools.py` の PreToolUse deny は permission UI ではなくClaude側のブロックであるため、`deny.log` 等の別ログに記録する。これにより「真の permission UI（ユーザーが判断を求められた）」と「hook による自動ブロック」を区別した集計が可能になる。

- メリット: `redirect-to-tools.py` の改修のみで実現可能（ペイロード調査不要）
- 効果: `perm_rate` の分母・分子の解釈が明確になる

### 案B': PreToolUse hook で tool_name を一時ファイルに記録する（採用済み）

案A の不成立を受けた代替案。`permission_prompt` Notification は `tool_name` を含まないが、直前に発火する PreToolUse hook は含む。PreToolUse（全ツール対象）で `session_id → tool_name` を `~/.claude/logs/last-tool-{session_id}` に書き出し、`permission-log.sh` がそのファイルを読む。

- フロー: PreToolUse → `pretooluse-track.sh` が一時ファイルを書く → ユーザーが permission UI を確認 → `permission-log.sh` が一時ファイルから tool_name を読む
- メリット: Notification ペイロードに依存しない。session_id でキーイングするため並行セッションでも混在しない
- 追加ファイル: `configs/claude/scripts/pretooluse-track.sh`（新規）、`configs/claude/settings.json` にマッチャーなし PreToolUse hook を追加

### 案C: PostToolUse hook で承認/拒否の結果を記録する（要調査）

PostToolUse hook のペイロードに permission の結果（approved / denied）が含まれているか調査し、含まれていれば結果ログを追加する。

- 前提: PostToolUse ペイロードに permission 結果が含まれることの確認が必要

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/scripts/pretooluse-track.sh` | dotfiles | 新規作成。tool_name を一時ファイルに記録（案B'） |
| `configs/claude/scripts/permission-log.sh` | dotfiles | stdin の `.tool_name` 読み取りを廃止し、一時ファイルから読むよう変更（案B'） |
| `configs/claude/scripts/redirect-to-tools.py` | dotfiles | deny 時に `deny.log` にも記録（案B） |
| `configs/claude/scripts/permission-ui-server.py` | dotfiles | ツール別内訳グラフの追加 |
| `configs/claude/settings.json` | dotfiles | PreToolUse（マッチャーなし）フックに `pretooluse-track.sh` を追加（案B'） |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-043 セクション）
