# ADR-013: Claude permission ask の自動ブロックによる自律性向上

## ステータス

採用済み

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

### 案1: CLAUDE.md ソフトガイダンスのみ（却下）

Claude に「Bash ループを書くな」と指示する。効果はあるが、長いセッションや圧縮後に薄れる可能性がある。

### 案2: redirect-to-tools.py ハードブロックのみ（却下）

代替可能コマンドを PreToolUse フックで自動ブロック。permission UI が出る前に止められるため、ユーザー介入なしに Claude が自律的にリトライできる。ただし未知パターンは捕捉できない。

### 案3: 2層アプローチ（採用）

CLAUDE.md による原則提示（ソフト）と `redirect-to-tools.py` による強制執行（ハード）を組み合わせる。新しいパターンを観測したら `redirect-to-tools.py` を拡張していく継続的改善サイクルを回す。

#### 層1: CLAUDE.md 自律性の原則

```
複雑な Bash（ループ・パイプ・インラインスクリプト）を生成せず、
専用ツールか個別コマンドに分解すること。
```

#### 層2: redirect-to-tools.py ハードブロック

##### どの hook に組み込むか

`settings.json` の `PreToolUse` フック（matcher: `Bash`）として登録する。Bash ツールが呼ばれるたびに実行され、`decision: block` を返すことで Claude Code の permission UI が出る前にコマンドを止める。

```
Bash ツール呼び出し
  → PreToolUse: redirect-to-tools.py  ← ここ
      → block → Claude がエラーを受け取り、代替ツールでリトライ
      → pass  → Claude Code ネイティブの allow/deny 評価へ
```

allow/deny リストの評価は Claude Code ネイティブに委ね、スクリプトは代替可能コマンドの誘導のみに専念する。

##### スクリプトの概要

`configs/claude/scripts/redirect-to-tools.py` として実装する。

**処理フロー:**

1. stdin から hook の JSON（`tool_input.command`）を読む
2. コマンドを `&&` / `||` / `;` で分割してセグメントごとに検査
3. 各セグメントの先頭コマンドをルールテーブルと照合
4. マッチしたら `{"decision": "block", "reason": "<代替ツール名> を使ってください"}` を stdout に出力して終了
5. マッチしなければ何も出力せず終了（pass-through）

**ルールテーブル（コマンド → 代替手段 → エラーメッセージ）:**

| コマンド | 代替手段 | 条件 |
|---------|---------|------|
| `find` | Glob | 常に |
| `grep` / `rg` | Grep | 常に |
| `cat` | Read | `>` リダイレクトなし |
| `cat` / `echo` | Write | `>` リダイレクトあり |
| `head` / `tail` | Read | 常に |
| `sed` / `awk` | Edit | 常に |
| `for` / `while` | Glob + 個別ツール | 常に |
| `python3` / `python` | Read/Grep/Edit/jq | `-c` フラグあり |

**設計上の判断:**

- **fail-open**: スクリプト内で例外が発生した場合は `sys.exit(0)`（pass-through）とし、誤検知によるブロックよりも動作継続を優先する
- **パイプ前半のみ検査**: `git log | grep fix` のようにパイプ後段に対象コマンドが来るケースはブロックしない。先頭コマンドが `git` であれば pass-through
- **チェーン全体を検査**: `cmd1 && cat file` のように `&&`/`||`/`;` で連結された場合は各セグメントを個別に検査し、1つでもマッチすればコマンド全体をブロックする

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-013 セクション）
