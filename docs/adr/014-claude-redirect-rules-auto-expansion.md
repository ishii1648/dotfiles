# ADR-014: redirect-to-tools.py ルールの自動拡張

## ステータス

Draft

## コンテキスト

ADR-013 で代替可能な Bash コマンドの自動ブロック（2層アプローチ）を採用した。これにより既知パターンの permission ask はなくなったが、**新しい未知パターンに遭遇した場合は依然として手動対応が必要**という課題が残った。

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

### 案1: PermissionRequest フックで deny + ログ記録

未知コマンドを `PermissionRequest` フックで自動的に deny し、`~/.claude/permission-asks.log` に記録する。permission UI は出なくなり、ログを後から分析してルール追加を検討できる。

**メリット**: permission UI を完全に抑止できる
**デメリット**: 正当な新コマンドも弾く。allow リストへの追加が必要になる

### 案2: enforce-bash-permissions.py のフォールバックを deny に変更

`enforce-bash-permissions.py` が allow/deny どちらにもマッチしない場合、現在は permission UI に回している（`sys.exit(0)`）。ここで deny + ログ記録に変えることで同様の効果が得られる。

**メリット**: 既存スクリプトの小さな変更で実現できる
**デメリット**: 案1と同じく正当な新コマンドを弾く

### 案3: fix-permission-ask スキルによるバッチ処理

`permission-asks.log` が蓄積されたタイミングでスキルを実行し、ログを分析して `redirect-to-tools.py` へのルール追加を提案する。ユーザーが承認したものだけ反映する。

**メリット**: 正当なコマンドを誤って弾かない
**デメリット**: ログ蓄積まで手動運用が続く

### 案4: 案1 or 2 + 案3の組み合わせ

deny + ログ記録で permission UI を抑止しつつ、スキルでバッチ処理してルールを整理する。deny したコマンドのうち正当なものは allow リストへ、redirect-to-tools でブロックすべきものはルール追加。

## 決定

（未定）

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-013/014 セクション）
