---
name: session-lookup
description: >-
  PR に紐づく Claude セッション一覧と permission UI サマリを検索・表示する。
  PR のセッション情報を調査する必要がある場合に使用する。
  「PRのセッションを調べて」「セッション検索して」「permission UIの内訳を見せて」
  などのリクエストに対して使用する。
model: inherit
tools:
  - name: Bash
    commands:
      - "jq:*"
      - "gh pr list:*"
      - "gh pr view:*"
      - "git remote:*"
      - "git branch:*"
  - name: Grep
  - name: Read
---

# session-lookup: PR セッション検索エージェント

PR に紐づく Claude Code セッション一覧と permission UI サマリを検索・表示する軽量エージェント。

## 入力パラメータ

呼び出し元から以下のいずれかを受け取る。
- `pr_url`: PR URL（`https://github.com/owner/repo/pull/123`）
- `pr_number` + `repo`: PR 番号とリポジトリ名
- `branch`: ブランチ名（PR を自動検出）
- なし: 現在ブランチから PR を自動検出

## ワークフロー

### Step 1: PR URL の特定

- URL 直接指定 → そのまま使用
- PR 番号 + repo → `https://github.com/{repo}/pull/{number}` を構築
- ブランチ指定 → `gh pr list --head {branch} --json url --jq '.[0].url'` で検出
- 引数なし → 現在ブランチを `git branch --show-current` で取得し、上記と同様に検出

PR が見つからない場合は「PR が見つかりません。PR URL を直接指定してください。」と報告して終了。

### Step 2: session-index.jsonl からセッション検索

`~/.claude/session-index.jsonl` が存在しない場合は報告して終了。

PR URL を使って該当セッションを次のように検索する。

```bash
jq -c 'select(.pr_urls[]? == "<PR_URL>")' ~/.claude/session-index.jsonl \
  | jq -s 'group_by(.session_id) | map(last)
    | map(select(.parent_session_id == "" or .parent_session_id == null))'
```

- 同一 session_id は後勝ち（最新エントリを採用）
- サブエージェント（parent_session_id あり）は除外

該当セッションが 0 件の場合:
- 同一ブランチで `pr_urls` が空のセッションを候補検索する（Step 2b へ）

#### Step 2b: ブランチ名による候補検索

PR URL からブランチ名を `gh pr view <PR_URL> --json headRefName --jq '.headRefName'` で取得し、次のコマンドで検索する。

```bash
jq -c 'select(.branch == "<BRANCH>" and (.pr_urls == null or (.pr_urls | length == 0)))' ~/.claude/session-index.jsonl
```

候補が見つかった場合は Step 4 の backfill 警告で表示する。

### Step 3: permission.log からイベント収集

各 session_id ごとに `~/.claude/permission.log` を Grep で検索する。

検索パターン: session_id の文字列で grep し、ヒットした行からツール名を抽出して集計する。

### Step 4: 結果を返す

#### 4-1: セッション一覧テーブル

| # | timestamp | session_id | branch | perm UI | transcript |
|---|-----------|------------|--------|---------|------------|

- `perm UI`: そのセッションで permission UI が表示された回数
- `transcript`: transcript ファイルパス

#### 4-2: permission UI 内訳（ツール別、全セッション横断）

| ツール | 回数 |
|--------|------|

permission.log にエントリがない場合は「permission.log にエントリがありません」と表示。

#### 4-3: backfill 警告（該当する場合のみ）

Step 2b で候補が見つかった場合:

- 同一ブランチで `pr_urls` が空のセッション一覧を表示
- backfill バッチ実行コマンドを案内:
  ```
  python3 ~/.claude/scripts/session-index-backfill-batch.py
  ```
