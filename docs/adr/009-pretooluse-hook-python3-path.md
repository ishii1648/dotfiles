# ADR-009: PreToolUse Hook の python3 パス解決によるフルパス指定

## ステータス

採用済み

## コンテキスト

`enforce-bash-permissions.py`（ADR-006）の hook 実行時に `PreToolUse:Bash hook error` が発生するケースが確認された。

```
⏺ Bash(mkdir -p /path/to/project/.github)
   ⎿  PreToolUse:Bash hook error
   ⎿  Done
```

調査の結果、スクリプトのロジック自体は正常に動作する（対象コマンドに対して正しく `{"decision": "allow"}` を返す）。エラーの原因は hook の実行環境にある。

### 原因分析

hook コマンドの現行設定:

```json
"command": "~/.claude/scripts/enforce-bash-permissions.py"
```

スクリプトの shebang:

```python
#!/usr/bin/env python3
```

Claude Code の hook はサブプロセスとして実行されるため、ユーザーのインタラクティブシェル環境（fish / zsh / bash のプロファイル）が読み込まれない。そのため `/opt/homebrew/bin` が PATH に含まれず、`/usr/bin/env python3` が python3 を発見できずスクリプトが起動に失敗する。

fail-open 設計（ADR-006）により hook エラーは通常動作にフォールバックするが、hook の意図した権限チェックがスキップされるため、deny ルールの迂回リスクが生じる。

## 決定

hook コマンドで python3 のフルパスを明示的に指定する。

### 変更箇所

`~/.claude/settings.json` の `hooks.PreToolUse`:

```json
// Before
"command": "~/.claude/scripts/enforce-bash-permissions.py"

// After
"command": "/opt/homebrew/bin/python3 ~/.claude/scripts/enforce-bash-permissions.py"
```

同様に `redirect-to-tools.py`（ADR-008）も同じ対処を適用する。

### 対象外とした代替案

| 代替案 | 不採用の理由 |
|--------|-------------|
| shebang をフルパスに変更 (`#!/opt/homebrew/bin/python3`) | hook コマンドの呼び出し方によっては shebang が無視される場合がある。コマンド側で明示する方が確実 |
| シェルラッパースクリプト経由で実行 | 不要な間接層が増える。直接フルパスを指定する方がシンプル |
| hook の timeout を延長 | 根本原因（PATH 問題）の解決にならない |

## 結果

- hook 実行環境の PATH に依存しなくなり、`PreToolUse:Bash hook error` が解消される
- deny ルールの迂回リスクが排除される
- macOS + Homebrew 環境でのパスがハードコードされるため、環境が変わった場合はパスの更新が必要

## 参考

- [ADR-006: PreToolUse Hook による Bash Permission の強制実行](./006-pretooluse-hook-bash-permissions.md)
- [ADR-008: PreToolUse Hook による Bash コマンドのネイティブツールへのリダイレクト](./008-pretooluse-hook-redirect-to-tools.md)
