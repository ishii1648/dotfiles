---
name: lint-fix
description: lint エラーを自動修正して commit+push する。「lint を直して」「lint エラーを修正して」「lint-fix」「push が失敗した」「pre-push フックで怒られた」と言われた時に使用する。ESLint/prettier は --fix で自動修正し、textlint も --fix を試みて、残存する自動修正不可のエラーのみ報告する。
version: 0.1.0
allowed-tools: Bash, Read, Edit, Write
argument-hint: "[commit message]"
---

# lint-fix - lint 自動修正 & commit+push

## 概要

lint エラーを自動修正し、修正内容を commit して push するスキル。
`pre-push` フックで lint が失敗した際のリカバリーや、push 前の予防的修正に使用する。

## 前提条件

`package.json` に以下のスクリプトが定義されていること:

- `lint` - ESLint チェック
- `lint-fix` - ESLint 自動修正
- `textlint` - textlint チェック

## ワークフロー手順

### 1. 事前チェック

```bash
# node_modules の存在確認
ls node_modules 2>/dev/null || echo "MISSING"
```

`node_modules` が存在しない場合は `npm install` を促して終了。

### 2. ESLint を --fix で自動修正

```bash
npm run lint-fix
```

- 修正後に `npm run lint` を再実行して残存エラーを確認
- 残存エラーがある場合（自動修正不可のルール違反）: エラー内容を報告してユーザーに手動対応を促し、以降の処理を停止

### 3. textlint を --fix で自動修正

```bash
npm run textlint -- --fix
```

- 修正後に `npm run textlint` を再実行して残存エラーを確認
- 残存エラーがある場合（自動修正不可のルール違反）: エラー内容を報告してユーザーに手動対応を促し、以降の処理を停止

### 4. 変更があるか確認

```bash
git diff --name-only
```

変更ファイルが存在しない場合は "lint エラーなし（修正不要）" と表示して終了。

### 5. 変更をコミット

```bash
git add -A
git commit -m "style: fix lint errors"
```

- 引数でコミットメッセージが渡された場合はそれを使用する
- 引数がない場合のデフォルトメッセージ: `style: fix lint errors`

### 6. リモートにプッシュ

```bash
git push
```

- push 失敗時はエラーメッセージを表示して停止
- 成功時は既存 PR の URL を表示する（存在する場合）

```bash
PR_URL=$(gh pr view --json url -q '.url' 2>/dev/null) && echo "PR: $PR_URL"
```

## 引数

| 引数 | 説明 |
|------|------|
| `"message"` | カスタムコミットメッセージ（省略時: `style: fix lint errors`） |

## 使用例

```bash
/lint-fix                          # デフォルトメッセージでコミット
/lint-fix "style: prettier format" # カスタムメッセージでコミット
```

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| node_modules なし | npm install を促して停止 |
| 自動修正後も ESLint エラー残存 | エラー内容を表示してユーザーに手動対応を促す |
| 自動修正後も textlint エラー残存 | エラー内容を表示してユーザーに手動対応を促す |
| 変更なし | "lint エラーなし（修正不要）" と表示して正常終了 |
| push 失敗 | エラーメッセージを表示して停止 |
