# ADR-013: Claude permission ask の自動ブロックによる自律性向上

## ステータス

Draft

## コンテキスト

Claude Code はデフォルトで allow/deny リストにマッチしない Bash コマンドに対して permission ask（ユーザー承認ダイアログ）を表示する。これにより自律的な作業が中断される。

セッションログの分析から、以下のパターンが permission ask の主な原因と判明した：

| コマンド | 代替手段 | 頻度 |
|---------|---------|------|
| `cat` | Read | 高 |
| `find` | Glob | 高 |
| `grep \| head` | Grep | 高 |
| `ls \|\| cat` | Glob + Read | 中 |
| `for` / `while` ループ | Glob + 個別ツール | 中 |
| `python3 -c` インラインスクリプト | Read/Grep/Edit/jq | 中 |
| `tmux` + shell expansion | — | 低（代替困難） |

これらの大半は専用ツール（Glob/Read/Grep/Edit）で完全に代替可能にもかかわらず、Claude が慣習的に Bash で記述しようとするために発生していた。

### 問題の構造

permission ask には 2 種類のメカニズムがある。

| 種別 | トリガー | ユーザー介入 |
|------|---------|------------|
| Hook ブロック（`redirect-to-tools.py`） | `decision: block` を返す | 不要（自動） |
| Claude Code 組み込み permission ask | allow/deny リスト不一致または shell expansion | **必要**（作業停止） |

問題は後者。`for` ループや `$HOME` 展開を含むコマンドは allow リストにマッチせず、permission UI が発生する。

## 設計案

### 案1: CLAUDE.md ソフトガイダンスのみ

Claude に「Bash ループを書くな」と指示する。効果はあるが、長いセッションや圧縮後に薄れる可能性がある。

### 案2: redirect-to-tools.py ハードブロックのみ

代替可能コマンドを PreToolUse フックで自動ブロック。permission UI が出る前に止められるため、ユーザー介入なしに Claude が自律的にリトライできる。ただし未知パターンは捕捉できない。

### 案3: 2層アプローチ（採用）

CLAUDE.md による原則提示（ソフト）と `redirect-to-tools.py` による強制執行（ハード）を組み合わせる。新しいパターンを観測したら `redirect-to-tools.py` を拡張していく継続的改善サイクルを回す。

### 将来: PermissionRequest フックによる自動ログ記録

`Notification` フックのペイロードには `tool_input` が含まれないため、コマンドの自動捕捉には `PermissionRequest` フックが正しい介入点。これを使って未知パターンを `~/.claude/permission-asks.log` に記録し、`fix-permission-ask` スキルでルール追加を半自動化する。

## 決定

**案3（2層アプローチ）** を採用する。

### 層1: CLAUDE.md 自律性の原則

```
複雑な Bash（ループ・パイプ・インラインスクリプト）を生成せず、
専用ツールか個別コマンドに分解すること。
```

### 層2: redirect-to-tools.py ブロック対象

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

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-013 セクション）
