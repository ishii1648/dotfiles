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

### 案A: Notification ペイロードを拡張して tool_name を記録する（採用候補）

`permission_prompt` Notification イベントのペイロードに `tool_name` が含まれているかを調査し、含まれていれば `permission-log.sh` を拡張してログに追記する。

- メリット: `permission-log.sh` の改修のみで内訳が取れる
- 前提: ペイロードに `tool_name` が含まれていることの確認が必要（Spike 要素）

### 案B: hook 起因の deny を permission.log から分離する（採用候補）

`redirect-to-tools.py` の PreToolUse deny は permission UI ではなくClaude側のブロックであるため、`deny.log` 等の別ログに記録する。これにより「真の permission UI（ユーザーが判断を求められた）」と「hook による自動ブロック」を区別した集計が可能になる。

- メリット: `redirect-to-tools.py` の改修のみで実現可能（ペイロード調査不要）
- 効果: `perm_rate` の分母・分子の解釈が明確になる

### 案C: PostToolUse hook で承認/拒否の結果を記録する（要調査）

PostToolUse hook のペイロードに permission の結果（approved / denied）が含まれているか調査し、含まれていれば結果ログを追加する。

- 前提: PostToolUse ペイロードに permission 結果が含まれることの確認が必要

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/scripts/permission-log.sh` | dotfiles | tool_name をログに追記（案A） |
| `configs/claude/scripts/redirect-to-tools.py` | dotfiles | deny 時に `deny.log` にも記録（案B） |
| `configs/claude/scripts/permission-ui-server.py` | dotfiles | ツール別内訳グラフの追加 |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-043 セクション）
