---
name: session-log
description: workflow skill（dispatch/spawn等）で収集したセッションログを git にコミットする。「/session-log commit <workflow-session-id>」で使用。
argument-hint: "commit <workflow-session-id>"
version: 0.1.0
---

# session-log

dispatch/spawn 等の workflow skill が `docs/dispatch-logs/` に収集した JSONL セッションログを git に追加・コミットする。

## 引数フォーマット

```
/session-log commit <workflow-session-id>
```

- `commit <workflow-session-id>`: 指定セッションの JSONL ログを git add → commit する

## ステップ

### Step 1: 引数の解析

1. 第1引数でサブコマンドを判定する
   - `commit` 以外の場合は「使用方法: /session-log commit <workflow-session-id>」を表示して終了
2. `<workflow-session-id>` を取得する
3. **Bash ツール**で `git rev-parse --show-toplevel` でリポジトリルートを確認する（git リポジトリ外なら終了）

### Step 2: ログファイルの確認

1. **Glob ツール**で `docs/dispatch-logs/<workflow-session-id>/` 内の JSONL ファイルを確認する
2. ファイルが0件の場合は「ログが見つかりません: docs/dispatch-logs/<workflow-session-id>/」を表示して終了
3. 見つかったファイルを一覧表示する

### Step 3: git add + commit

1. **Bash ツール**でステージングする（1コマンド1呼び出し）:
   ```
   git add docs/dispatch-logs/<workflow-session-id>
   ```
2. **Bash ツール**でコミットする:
   ```
   git commit -m "log: <workflow-session-id> session logs"
   ```
3. **Bash ツール**で git remote が設定されているか確認する:
   ```
   git remote
   ```
   出力が空でなければ **Bash ツール**で push する:
   ```
   git push
   ```
4. 完了メッセージを表示する:
   ```
   コミット完了: log: <workflow-session-id> session logs
   ```

## 制約

- git リポジトリ内でのみ動作する
- `docs/dispatch-logs/` 以下のファイルのみを対象とする
- Bash コマンドは1コマンド1呼び出し（`&&`/`||`/`;` での連結は禁止）
