# ADR-006: PreToolUse Hook による Bash Permission の強制実行

## ステータス

採用済み

## コンテキスト

Claude Code の `settings.json` で `permissions.allow` に書き込み系 Bash コマンド（`mkdir`, `mv`, `git add` 等）を登録しても、permission プロンプトがスキップされない既知バグが存在する。読み取り系コマンド（`ls`, `git status` 等）は正常に動作するが、書き込み系は毎回ユーザー承認を求められ、自動化ワークフローが阻害される。

一方、`permissions.deny` に登録したコマンドも、チェインコマンド（`&&`, `||`, `;`, `|`）の中に埋め込まれた場合にすり抜ける可能性がある。

## 決定

`PreToolUse` hook を使い、`settings.json` の permission ルールを Python スクリプトで再評価するワークアラウンドを実装する。

### 構成

| コンポーネント | パス |
|---------------|------|
| Hook スクリプト | `configs/claude/scripts/enforce-bash-permissions.py` → `~/.claude/scripts/` (symlink) |
| Hook 登録 | `~/.claude/settings.json` の `hooks.PreToolUse` |

### パターンマッチの3モード

`settings.json` の `Bash(...)` パターンを以下の3モードで解釈する:

| パターン例 | モード | マッチ方式 |
|-----------|--------|-----------|
| `Bash(mkdir:*)` | word_prefix | `mkdir` 単体、または `mkdir ` で始まるコマンド |
| `Bash(coderabbit*)` | char_prefix | `coderabbit` で始まる文字列（`coderabbitai` 等も含む） |
| `Bash(rm *.git/lock.index)` | exact | 完全一致 |

### 評価ロジック

1. **deny を先に評価**（deny 優先）。チェインコマンドを `&&`, `||`, `;`, `|` で分割し、各セグメントを個別にチェック
2. **allow を評価**。コマンド全体に対してのみマッチ（保守的設計）
3. **どちらにもマッチしない場合** → `exit(0)` で通常の permission プロンプトにフォールバック

### 設計方針

- **fail-open**: 例外発生時（settings.json の不在、パースエラー等）は `sys.exit(0)` で通常動作に戻る。hook の障害でツール実行全体が止まることを防ぐ
- **deny のチェイン分割**: `ls && sudo whoami` のようなコマンドで deny ルール（`sudo`）を確実に捕捉
- **allow はコマンド全体のみ**: チェインの一部だけが allow パターンにマッチしてもコマンド全体を許可しない

## 結果

- `settings.json` の既存ルールを変更せず、hook が同じルールを読み取って強制実行する
- Claude Code 本体のバグが修正された場合でも、hook は同じルールを二重に適用するだけで副作用はない（allow が二重に許可されるのみ）
- チェインコマンドによる deny すり抜けも防止される

## 参考

- [Claude Code Hooks ドキュメント](https://docs.anthropic.com/en/docs/claude-code/hooks)
