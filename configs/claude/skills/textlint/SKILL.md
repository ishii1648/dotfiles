---
name: textlint
description: Lint and auto-fix Markdown files using textlint MCP server. Use when user says "textlintして", "文章をチェックして", "lintして", or when CLAUDE.md instructs automatic textlint after writing .md files.
version: 0.1.0
allowed-tools: Read, Edit, mcp__textlint__lintFile, mcp__textlint__getLintFixedFileContent
context: fork
argument-hint: "<file-path>"
---

# textlint 自動チェック・修正スキル

## 概要

`.md` ファイルを textlint でチェックし、エラー・警告がある場合は自動修正する。
修正後も問題が残る場合はループして解消するまで繰り返す。

## 手順

### 1. 対象ファイルの確認

引数でファイルパスが渡された場合はそれを使用する。
渡されていない場合は直前に Write/Edit したファイルを対象とする。

### 2. リント実行

```
mcp__textlint__lintFile(filePath: "<対象ファイルの絶対パス>")
```

結果を確認する：
- エラー・警告が **0件** → 「textlint: 問題なし」と報告して終了
- エラー・警告が **1件以上** → ステップ 3 へ

### 3. 修正内容の取得と適用

```
mcp__textlint__getLintFixedFileContent(filePath: "<対象ファイルの絶対パス>")
```

取得した修正後のコンテンツを `Edit` ツールで元ファイルに適用する。

> **注意**: `getLintFixedFileContent` はファイルへの書き込みを行わない。
> 必ず `Edit` ツールで手動適用すること。

### 4. 再リントと終了判定

ステップ 2 に戻り、問題がなくなるまで繰り返す。

**上限**: 最大 5 回ループ。5 回後も問題が残る場合は残存エラーをユーザーに報告して終了する。

## 報告フォーマット

```
textlint チェック完了: <ファイルパス>
- 修正回数: N 回
- 残存エラー: 0 件（または残存内容の説明）
```

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| textlint MCP が未起動 | 「textlint MCP サーバーが利用できません」と報告して終了 |
| ファイルが存在しない | 「ファイルが見つかりません: <パス>」と報告して終了 |
| 5 回ループ後も残存エラー | 残存エラー内容をユーザーに報告して終了 |
