---
name: retro-pr
description: >-
  PRに紐づくClaude Codeセッションログを検索・分析する。PR URLまたはPR番号を指定すると、
  session-index.jsonlから該当セッションを検索し、transcriptを読み込んで分析結果を出力する。
  「PRのsession分析して」「PRの振り返り」「/retro-pr」で起動する。
version: 0.2.0
context: fork
allowed-tools: Read, Write, Bash(jq:*), Bash(gh pr view:*), Bash(mkdir:*), TeamCreate, TeamDelete
argument-hint: "<PR URL or PR番号> [--repo owner/repo]"
---

# retro-pr: PR セッション分析スキル

## 概要

PR に紐づく Claude Code セッションログを `~/.claude/session-index.jsonl` から検索し、
transcript を読み込んで分析結果を `.outputs/claude/` に出力する。

## ワークフロー

### Step 1: 引数パース

`$ARGUMENTS` から PR URL または PR 番号を特定する。

- URL が渡された場合、URL から `owner/repo` と PR 番号を抽出する
  - 例: `https://github.com/C-FO/aws-infra/pull/123` → repo=`C-FO/aws-infra`, number=`123`
- 番号のみ渡された場合、`--repo` オプションがあればそれを使用、なければ現在リポジトリで解決
  ```bash
  gh pr view {番号} --json url --jq '.url'
  ```
- 引数なしの場合、現在ブランチの PR を自動検出
  ```bash
  gh pr view --json url --jq '.url'
  ```
  - PR が見つからない場合: 「現在のブランチに紐づくPRが見つかりません。PR URLまたはPR番号を指定してください。」と案内して終了

### Step 2: session-index.jsonl 検索

`~/.claude/session-index.jsonl` が存在しない場合は「session-index.jsonl が見つかりません。」と報告して終了。

```bash
jq -c 'select(.pr_urls[]? | contains("{owner}/{repo}/pull/{number}"))' ~/.claude/session-index.jsonl
```

該当セッションが 0 件の場合: 「該当するセッションが見つかりませんでした。」と報告して終了。

### Step 3: セッション一覧表示

検索結果を以下の表形式で表示する。

| # | timestamp | session_id | branch | transcript |
|---|-----------|------------|--------|------------|
| 1 | 2026-02-20 10:23:45 | abc-123 | fix/something | /path/to/transcript.jsonl |

### Step 4: ツール使用統計の収集（スクリプト実行）

ツール使用統計は決定論的に導出できるため、transcript を jq で直接集計する。
各 transcript ファイルに対して以下を実行し、結果をマージする。

```bash
jq -s '
  [.[] | select(.type == "assistant") | .message.content[]?
   | select(.type == "tool_use") | .name]
  | group_by(.) | map({name: .[0], count: length})
  | sort_by(-.count)
' {transcript_path}
```

全 transcript の結果を統合して、ツール別の合計回数を算出する。

### Step 5: チーム作成・並列分析

TeamCreate で分析チームを作成し、観点ごとにメンバーをアサインする。
各メンバーには transcript パス一覧を渡し、Read ツールで読み込ませる。

#### メンバー構成

| メンバー名 | 分析観点 | 出力内容 |
|------------|----------|----------|
| `session-summary` | セッション経過 | ユーザーの主要な指示を時系列で抽出。実施した変更（ファイル名・内容）を要約 |
| `decision-review` | 意思決定と課題 | 重要な設計判断・技術選択とその理由を抽出。問題が起きた箇所・手戻り・方針変更を特定し、課題と改善点を導出 |

#### 各メンバーへの指示テンプレート

**session-summary**:
> 以下の transcript を Read で読み込み、分析結果をテキストで返してください。
> transcript: {paths}
>
> 1. ユーザーの主要な指示を時系列で抽出（箇条書き）
> 2. 実施した変更をファイル単位で要約（箇条書き）
>
> transcript 内の `type: "user"` エントリからユーザー指示を、
> `type: "assistant"` 内の tool_use（Write/Edit）からファイル変更を抽出すること。

**decision-review**:
> 以下の transcript を Read で読み込み、分析結果をテキストで返してください。
> transcript: {paths}
>
> 1. 意思決定ログ: 重要な設計判断・技術的選択とその理由（箇条書き）
> 2. 課題の特定: 以下の観点で問題点を洗い出す
>    - 手戻り: ユーザーが方針変更・やり直しを指示した箇所
>    - エラー・リトライ: ツール実行が失敗して再試行した箇所
>    - 非効率: 同じファイルの繰り返し読み書き、冗長な操作
>    - 判断ミス: Claude が誤った判断をしてユーザーに修正された箇所
> 3. 改善提案: 特定した課題それぞれに対する改善案（CLAUDE.md への追記、スキル改善、ワークフロー変更など）

### Step 6: 結果統合・出力

全メンバーの結果と Step 4 のツール統計を統合し、以下のパスに出力する。

```
.outputs/claude/retro-pr-{repo_slug}-{PR番号}.md
```

- `repo_slug`: `owner/repo` の `/` を `-` に置換したもの（例: `C-FO-aws-infra`）

出力フォーマット:

```markdown
# PR セッション分析: {repo}#{PR番号}

**PR URL**: {pr_url}
**分析日**: {today}
**セッション数**: {count}

## セッション一覧

| # | timestamp | branch | session_id |
|---|-----------|--------|------------|

## セッション経過

### ユーザーの主要な指示
- ...

### 実施した変更
- ...

## 意思決定ログ
- ...

## 課題と改善点

### 手戻り・方針変更
| # | 箇所 | 内容 | 影響 |
|---|------|------|------|

### エラー・リトライ
| # | 箇所 | 内容 | 原因 |
|---|------|------|------|

### 非効率な操作
- ...

### 改善提案
| # | 課題 | 改善案 | 対象 |
|---|------|--------|------|

対象: `CLAUDE.md` / `スキル` / `フック` / `ワークフロー` など

## ツール使用統計

| ツール | 回数 | 割合 |
|--------|------|------|

**tool_use 総数**: {total}
```

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| 引数なし + 現在ブランチにPRなし | 案内メッセージを表示して終了 |
| `~/.claude/session-index.jsonl` 不在 | 報告して終了 |
| 該当セッション 0 件 | 報告して終了 |
| transcript ファイル不在 | スキップして警告を表示、他のセッションは継続 |
