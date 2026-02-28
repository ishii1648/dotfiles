# ADR-013: Claude permission ask の自動ブロックによる自律性向上

## ステータス

Draft

## コンテキスト

Claude Code はデフォルトで allow/deny リストにマッチしない Bash コマンドに対して permission ask（ユーザー承認ダイアログ）を表示する。これにより自律的な作業が中断される。

セッションログの分析から、以下のパターンが permission ask の主な原因と判明した：

- `cat` / `find` / `grep` などのファイル操作コマンド → Read/Glob/Grep ツールで代替可能
- `for` / `while` ループ → Glob + 個別ツール呼び出しで代替可能
- `python3 -c` / `python -c` インラインスクリプト → Read/Grep/Edit/jq で代替可能

これらは専用ツール（Glob/Read/Grep/Edit）で完全に代替可能にもかかわらず、Claude が慣習的に Bash で記述しようとするために発生していた。

permission ask が発生するとユーザーが承認または否認するまで作業が止まり、Claude の自律性が損なわれる。

## 決定

**2層のアプローチ**で permission ask を削減する。

### 層1: CLAUDE.md ソフトガイダンス

`~/.claude/CLAUDE.md` に「自律性の原則」として明示する：

> 複雑な Bash（ループ・パイプ・インラインスクリプト）を生成せず、専用ツールか個別コマンドに分解すること。

これにより Claude が Bash ではなく専用ツールを選択する頻度を高める。

### 層2: `redirect-to-tools.py` ハードブロック

PreToolUse フックで代替可能なコマンドを自動ブロックし、専用ツールへ誘導するメッセージを返す。Claude Code の permission UI が表示される前に処理を止めるため、ユーザー介入なしに Claude が自律的にリトライできる。

**ブロック対象コマンド:**

| コマンド | 代替手段 |
|---------|---------|
| `find` | Glob |
| `grep` / `rg` | Grep |
| `cat`（読み取り） | Read |
| `cat >` / `echo >` | Write |
| `head` / `tail` | Read |
| `sed` / `awk` | Edit |
| `for` / `while` | Glob + 個別ツール |
| `python3 -c` / `python -c` | Read/Grep/Edit/jq |

### 継続的改善サイクル

新しいパターンを観測したら `redirect-to-tools.py` を拡張する。将来的には `PermissionRequest` フックで未知パターンを自動ログに記録し、半自動でルール追加するワークフローを整備する。

## 結果

（未定 → docs/issues.md の受け入れ条件を参照）
