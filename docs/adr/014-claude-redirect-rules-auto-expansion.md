# ADR-014: redirect-to-tools.py ルールの自動拡張

## ステータス

Accepted

## コンテキスト

ADR-013 で代替可能な Bash コマンドの自動ブロック（2層アプローチ）を採用した。その後、2層目として使用していた `enforce-bash-permissions.py`（PermissionRequest フックで allow/deny を判定するスクリプト）は削除済み。現在は `redirect-to-tools.py`（PreToolUse フックで Bash コマンドを専用ツールにリダイレクト）のみが稼働している。

これにより既知パターンの permission ask はなくなったが、**新しい未知パターンに遭遇した場合は依然として手動対応が必要**という課題が残った。

現在の対応フロー：

```
新しいパターンで permission ask 発生
  → ユーザーが気づく（作業停止）
  → どのコマンドが原因か手動で特定
  → ユーザーが Claude に指示
  → Claude が redirect-to-tools.py を編集
```

この「観測→特定→修正」のサイクルを半自動化したい。

### Notification フックでは不可

`Notification`（permission_prompt）フックのペイロードには `tool_input` が含まれないため、どのコマンドが原因かをフックから取得できない。

### PermissionRequest フックが正しい介入点

`PermissionRequest` フックは `tool_input.command` を含むため、コマンドの自動捕捉が可能。またフックから `deny` 決定を返すことで permission UI を抑止できる。

```json
{
  "hook_event_name": "PermissionRequest",
  "tool_name": "Bash",
  "tool_input": {
    "command": "for f in ...; do rm $f; done"
  }
}
```

## 設計案

### 案1: PermissionRequest フックでログ記録のみ

未知コマンドを `PermissionRequest` フックで `~/.claude/permission-asks.log` に記録する。permission UI は通常通り表示され、ログを後から分析してルール追加を検討できる。

**メリット**: 正当な新コマンドを誤って弾かない
**デメリット**: ログ蓄積まで permission UI は引き続き出る

### 案2: fix-permission-ask スキルによるバッチ処理

`permission-asks.log` が蓄積されたタイミングでスキルを実行し、ログを分析して `redirect-to-tools.py` へのルール追加を提案する。ユーザーが承認したものだけ反映する。

**メリット**: 正当なコマンドを誤って弾かない
**デメリット**: ログ蓄積まで手動運用が続く

### 案3: 案1 + 案2の組み合わせ

ログ記録で permission ask を捕捉しつつ、スキルでバッチ処理してルールを追加する。permission ask は初回のみ発生し、ルール追加後は以降の同パターンで発生しなくなる。

## 決定

**案3（案1 + 案2 の組み合わせ）を採用する。**

### PermissionRequest フック: deny + ログ記録

`configs/claude/hooks/log-permission-ask.py` を新規作成し、`PermissionRequest` イベントで次の処理を行う：

1. `tool_input.command` を `~/.claude/permission-asks.log` に追記（タイムスタンプ付き）
2. フックからは何も返さず permission UI を通常通り表示させる（初回は許容）

### fix-permission-ask スキル: バッチ処理

`configs/claude/plugins/dotfiles/skills/fix-permission-ask.md` を新規作成し、次のフローを実行する：

1. `~/.claude/permission-asks.log` を読み込んで記録されたコマンドを列挙
2. 各コマンドを以下に分類して提案：
   - `redirect-to-tools.py` にルール追加すべき（専用ツールへのリダイレクト対象）
   - `allow` リストに追加すべき（正当な新コマンド）
   - 要確認（判断が難しいもの）
3. `AskUserQuestion` で各提案をユーザーが承認
4. 承認分のみ `redirect-to-tools.py` を編集してルールを追加
5. 処理済みエントリをログからクリア

### ログフォーマット

```
2026-02-28T10:00:00 command="find . -name '*.py'"
2026-02-28T10:05:00 command="ls -la /tmp"
```

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-013/014 セクション）
