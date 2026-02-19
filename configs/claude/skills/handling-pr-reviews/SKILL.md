---
name: handling-pr-reviews
description: >-
  Reads PR code review comments, triages each comment, makes code fixes where
  needed, and posts reply comments. Use when the user asks to respond to PR
  review comments, handle PR feedback, fix review comments, or process code
  review feedback on a GitHub PR.
version: 0.2.0
model: claude-opus-4-6
allowed-tools: Read, Grep, Glob, Write, Edit, "Bash(git:*)", "Bash(gh pr view:*)", "Bash(gh api:repos/*/*/pulls/*/comments*)"
argument-hint: "[--response | --response-only] [PR number or URL (optional)]"
disable-model-invocation: true
---

# PR Review Response

## Overview

PRコードレビューコメントを取得・分析し、3つのモードで対応する:

| モード | 引数 | やること | やらないこと |
|--------|------|---------|-------------|
| **実装モード**（デフォルト） | なし or PR番号のみ | コメント取得→分析→トリアージ→コード修正→コミット | コメント返信、プッシュ |
| **フルモード** | `--response` | コメント取得→分析→トリアージ→コード修正→コミット→返信投稿 | プッシュ |
| **返信モード** | `--response-only` | コメント取得→コミット情報から対応内容を把握→返信投稿 | コード修正 |

典型的なワークフロー: `--response` で修正・コミット・返信を一括実行。または実装モードで修正・コミット後、`--response-only` で返信投稿。

## Workflow Steps

### Step 1: 引数パースとPRレビューコメントの取得（共通）

1. **引数パース**:
   - 引数に `--response-only` が含まれるか判定 → **返信モード**
   - 引数に `--response` が含まれるか判定 → **フルモード**
   - いずれも含まれない → **実装モード**
   - `--response` / `--response-only` を除いた残りからPR番号を特定（以下の優先順で解決）
2. PR番号の特定:
   a. 引数が指定されている場合: 引数からPR番号を特定（URLの場合は番号を抽出）
   b. 引数が省略された場合: 現在のブランチから自動検出
      ```bash
      gh pr view --json number,title,headRefName,baseRefName,url
      ```
      - `gh pr view` は引数なしで現在のブランチに紐づくPRを自動検出する
      - PRが見つからない場合: 「現在のブランチに紐づくPRが見つかりません。PR番号またはURLを指定してください。」と報告して終了
3. PRメタデータを取得:
   ```bash
   gh pr view {PR} --json number,title,headRefName,baseRefName,url
   ```
4. コードレビューコメントを取得:
   ```bash
   gh api repos/{owner}/{repo}/pulls/{PR}/comments --paginate
   ```
   - `gh pr view --comments` ではなく `gh api` を使う理由: 前者は issue レベルコメントのみ、後者はコード行レベルのレビューコメント（`path`, `line`, `diff_hunk`, `in_reply_to_id` 付き）を返す
5. フィルタリング:
   - `in_reply_to_id` が null のルートコメントのみを処理対象とする（スレッドの重複処理を回避）
   - 既に自分が返信済みのスレッドはスキップ

**エラー処理:**
- 引数なし かつ 現在のブランチにPRが存在しない場合: 「現在のブランチに紐づくPRが見つかりません。PR番号またはURLを指定してください。」と報告して終了
- PRが見つからない場合: エラー報告し、PR番号/URLの確認を提案
- レビューコメントが0件: 「PRレビューコメントはありません。」と報告して終了
- 全コメント対応済み: 「全てのコメントは対応済みです。」と報告して終了
- 返信モードでコミットが存在しない場合: 「ベースブランチからの変更コミットが見つかりません。先に実装モードで修正・コミットしてください。」と報告して終了

### Step 2 以降: モード別分岐

- **実装モード**の場合 → `workflow-implement.md` の手順に従う
- **フルモード**の場合 → `workflow-implement.md` の手順を実行し、コミット完了後に `workflow-response.md` の Step 2 以降を続けて実行する
- **返信モード**の場合 → `workflow-response.md` の手順に従う
