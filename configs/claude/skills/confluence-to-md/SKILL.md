---
name: confluence-to-md
description: >-
  Retrieves a Confluence page via Atlassian MCP, normalizes custom emoji tags to
  Unicode characters, and saves formatted Markdown to .outputs/claude/.
  Use when the user says "Confluenceをmarkdownに変換して", "Confluenceページを取得して",
  or "confluence-to-md".
context: fork
agent: general-purpose
allowed-tools: Read, Write, Glob, Grep, Bash(ls:*), Bash(mkdir:*), ToolSearch, mcp__atlassian-v2__getConfluencePage
argument-hint: "<ConfluenceページURL or ページID>"
---

# Confluence to Markdown

## 概要

ConfluenceページのURLまたはページIDを受け取り、Atlassian MCP (`getConfluencePage`) を使用してページ内容をMarkdown形式で取得する。取得したMarkdown内に含まれるConfluence独自の絵文字タグ (`<custom data-type="emoji">`) をUnicode絵文字またはテキスト表現に変換し、整形済みMarkdownファイルとして `.outputs/claude/` 配下に出力する。

## 引数

- **ConfluenceページURL or ページID**（必須）: 対象ページの識別子
  - URL例: `https://your-site.atlassian.net/wiki/spaces/SPACE/pages/123456789/Page+Title`
  - ページID例: `123456789`

## 共通コンテキスト

以下の値はプロジェクト固有であり、環境に応じて変更が必要。URLから `cloudId` を自動抽出できる場合はそちらを優先する。

```yaml
confluence:
  cloudId: your-site.atlassian.net  # 環境に応じて変更（URLから自動抽出を優先）
```

## ワークフロー

### Step 1: 入力の正規化

`$ARGUMENTS` からページIDを抽出する。

- URLの場合: パスから `/pages/` の直後にある数値部分をページIDとして抽出する
- 数値のみの場合: そのままページIDとして使用する
- いずれにも該当しない場合: エラーメッセージを表示し、正しい入力形式を案内する

### Step 2: MCPツールのロードとページ取得

1. ToolSearchで `mcp__atlassian-v2__getConfluencePage` をロードする
2. `getConfluencePage` を以下のパラメータで呼び出す:
   - `cloudId`: URLから抽出したホスト名、または共通コンテキストの値を使用
   - `pageId`: Step 1で抽出したページID
   - `contentFormat`: `markdown`
3. レスポンスからページタイトルとMarkdown本文を取得する

### Step 3: 絵文字タグの正規化

取得したMarkdown内の `<custom data-type="emoji">` タグを `confluence-emoji-mapping` スキルのマッピングテーブルに従って置換する。

1. `confluence-emoji-mapping` スキルを Read ツールで参照し、マッピングテーブルを取得する
   - スキルファイルのパス: `configs/claude/skills/confluence-emoji-mapping/SKILL.md`
2. 標準絵文字 → Unicode 文字に置換
3. Atlassian 独自絵文字 → テキスト表現に置換
4. マッピング外の shortName → `:shortName:` 形式で残す

### Step 4: ファイル出力

1. `mkdir -p .outputs/claude` を実行して出力ディレクトリを確保する
2. ページタイトルからファイル名を生成する:
   - スペースをハイフンに置換
   - 英数字・ハイフン・アンダースコア以外の文字を除去
   - 小文字に変換
   - 末尾に `.md` を付与
3. 整形済みMarkdownを `.outputs/claude/<ファイル名>.md` に書き込む
   - ファイル先頭にページタイトルをH1見出しとして付与する（元のMarkdownに含まれていない場合）

### Step 5: 完了報告

出力ファイルの絶対パスをユーザーに表示する。

## ベストプラクティス

- ページIDの抽出時はURLの様々なパターン（クエリパラメータ付き等）に対応する
- 絵文字変換では正規表現を使用し、タグ全体を確実に置換する
- ファイル名の生成時は十分にサニタイズし、ファイルシステム上の問題を防ぐ
- 出力ファイルが既に存在する場合は上書きする（最新版を優先）

## エラーハンドリング

| シナリオ | 対応 |
|---------|------|
| ページIDが抽出できない | エラーメッセージを表示し、正しい入力形式を案内する |
| MCPツールのロード失敗 | エラーを報告し、Confluenceへの直接アクセスを促す |
| ページが見つからない | ページIDの確認とアクセス権限の確認を促す |
| Markdown取得結果が空 | 空ページである旨を報告し、処理を終了する |
