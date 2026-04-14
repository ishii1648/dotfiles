---
name: dispatch
description: >-
  This skill should be used when the user wants to launch a Claude session in another repository via tmux,
  such as "別リポでclaude起動して", "dispatchして", "tmux windowでclaude開いて", "/dispatch",
  "他のリポジトリでタスクを実行して", "別プロジェクトにclaude立ち上げて".
  Creates a git worktree, a new tmux window, and starts claude with the given prompt via stdin redirect.
version: 1.1.0
allowed-tools: Bash, AskUserQuestion
argument-hint: "[repo] [\"prompt\"] [--in-session]  # --in-session: 現在のsessionに追加（デフォルトは新規session作成）"
disable-model-invocation: true
---

# dispatch - 別リポジトリで claude を起動

## 概要

`~/.claude/skills/dispatch/dispatch.sh` に全ロジックを委譲する。
最大 Bash 3回 + AskUserQuestion 1回で完結する。

## ワークフロー

### Step 1: 引数チェック

引数から `repo`、`prompt`、`in_session`（フラグ）を取得する。

| 引数パターン | 例 | 対応 |
|---|---|---|
| repo + prompt | `/dispatch C-FO/sandbox-ishii1648 "hello"` | → Step 3 |
| repo のみ | `/dispatch C-FO/sandbox-ishii1648` | → Step 2（prompt を聞く） |
| prompt のみ | `/dispatch "テストを実行して"` | → Step 3（カレントリポジトリ + 現在の session を使用） |
| 引数なし | `/dispatch` | → Step 2（両方聞く） |
| --in-session あり | `/dispatch repo "prompt" --in-session` | → 現在の tmux session に window を追加 |

デフォルト（フラグなし）では新規 tmux session を作成する。`--in-session` を指定した場合は現在の tmux session に window を追加する。

**repo 省略時の特殊動作**: prompt のみが指定された場合、カレントディレクトリの git リポジトリルートを repo として使用し、現在の tmux session に window を追加する（`--in-session` と同じ動作）。

引数が1つだけの場合の判別: ghq 短縮名パターン（`org/repo`）やパスなら repo、それ以外なら prompt として扱う。

`--in-session` は値を取らないフラグ。位置引数のどこに出現しても認識する。

### Step 2: 不足情報を AskUserQuestion で収集

repo が不足している場合、`list-repos` で候補を取得:

```bash
bash ~/.claude/skills/dispatch/dispatch.sh list-repos
```

結果から AskUserQuestion の選択肢を生成する（最大4件、よく使うリポジトリを優先）。

prompt が不足している場合も AskUserQuestion で入力してもらう。

両方不足している場合は AskUserQuestion で複数問まとめて聞く。

### Step 3: ブランチ名の決定

prompt の内容からタスクに適したブランチ名を決定する。

命名規則:
- `feat/<短い説明>` — 新機能追加
- `fix/<短い説明>` — バグ修正
- `chore/<短い説明>` — メンテナンス・設定変更

例:
- 「tenant module を stg/prod に追加」→ `feat/add-tenant-module-stg-prod`
- 「CI の flaky test を修正して」→ `fix/flaky-test-ci`

### Step 4: launch 実行

デフォルト（`--in-session` なし）では `--session` を渡さない。dispatch.sh 側が worktree 名を session 名にして新規 session を作成する:

```bash
bash ~/.claude/skills/dispatch/dispatch.sh launch "<repo>" "<prompt>" --branch "<branch_name>"
```

`--in-session` が指定されている場合、または **repo を省略して prompt のみ指定した場合**、現在の tmux session 名を取得して `--session` に渡す:

```bash
current_session=$(tmux display-message -p '#{session_name}')
bash ~/.claude/skills/dispatch/dispatch.sh launch "<repo>" "<prompt>" --branch "<branch_name>" --session "$current_session"
```

**repo 省略時**: `<repo>` には `git rev-parse --show-toplevel` で取得したカレントリポジトリのルートパスを使用する。

オプション引数:
- `--session <name>`: 既存の tmux session に window を追加
- `--window <name>`: window 名を指定
- `--branch <name>`: worktree のブランチ名（**必須**）
- `--no-worktree`: worktree を作成せず repo 直下で作業する（`--branch` 不要になる）

### Step 5: STATUS に応じて分岐

| STATUS | 対応 |
|--------|------|
| `LAUNCHED` | 完了報告（SESSION, WINDOW, PANE_ID, REPO, WORK_DIR を表示） |
| `ERROR` | MESSAGE を表示して終了 |

### Step 6: 完了報告

```
claude を起動しました
  リポジトリ: <REPO>
  作業ディレクトリ: <WORK_DIR>
  セッション: <SESSION>
  ウィンドウ: <WINDOW>
```
