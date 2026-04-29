---
name: orchestrate
description: ワークフロータイプに応じたエージェントチェーンを順次実行する。feature/bugfix/refactor/security/custom を指定し、各エージェントがハンドオフ文書で引き継ぎながら計画→TDD→レビューを実行する。「/orchestrate feature "新機能追加"」「/orchestrate bugfix --issue 53」「/orchestrate --dry-run feature "タスク"」「/orchestrate cleanup <session>」で起動。
argument-hint: '<workflow-type> "<タスク記述>" | <workflow-type> --issue <番号> | <workflow-type> <GitHub-issue-URL> | custom --agents <a,b,c> "<タスク記述>" | --dry-run <workflow-type> "<タスク記述>" | cleanup <session>'
version: 0.0.4
---

# orchestrate

ワークフロータイプに応じたエージェントチェーンを順次実行する。各エージェントは専用 tmux ウィンドウで起動し、ハンドオフ文書で引き継ぎながら作業を進める。`tmux wait-for` によるゼロコスト待機で前のエージェント完了後に自動的に次のエージェントを起動する。

単一ブランチで完結する小規模作業には `/dispatch`（軽量版・エージェントチェーンなし）を使用する。

コアロジック（worktree 作成・tmux セッション・エージェント起動・advance ループ・cleanup）は `~/.claude/skills/orchestrate/orchestrate.sh` に委譲する。

## ワークフロータイプ

| タイプ | エージェントチェーン |
|--------|---------------------|
| `feature` | planner → tdd-guide → code-reviewer → security-reviewer |
| `bugfix` | planner → tdd-guide → code-reviewer |
| `refactor` | architect → code-reviewer → tdd-guide |
| `security` | security-reviewer → code-reviewer → architect |
| `custom` | `--agents a,b,c` で任意指定 |

## 引数フォーマット

```
/orchestrate <workflow-type> "<タスク記述>"
/orchestrate <workflow-type> --issue <番号>
/orchestrate <workflow-type> <GitHub-issue-URL>
/orchestrate <workflow-type> <owner/repo>#<number>
/orchestrate <workflow-type> --repo <owner/repo> "<タスク記述>"
/orchestrate custom --agents planner,code-reviewer "<タスク記述>"
/orchestrate --dry-run <workflow-type> "<タスク記述>"
/orchestrate cleanup <session-name|session-id>
```

## ステップ

### Step 1: 引数の解析とタスク記述の構築

1. 第1引数でサブコマンドを判定する
   - `cleanup` の場合は Step 4 へジャンプ
2. `--dry-run` フラグを検出してフラグ変数に保持する
3. ワークフロータイプを取得する（feature / bugfix / refactor / security / custom）
   - `custom` の場合は `--agents <a,b,c>` を検出してエージェントリスト変数に保持する
4. `--repo <owner/repo>` フラグを検出してリポジトリ変数に保持する
5. `--from-todo [path]` フラグを検出した場合は Step 1-5 へ
6. 残り引数から以下を順に検出する:
   a. `https://github.com/` で始まる文字列（GitHub issue URL）→ Step 1-4 へ（URL から owner/repo も自動設定）
   b. `<owner/repo>#<number>` パターン（例: `ishii1648/tmux-sidebar#2`）→ Step 1-4 へ（owner/repo を自動設定）
   c. `--issue <番号>` フラグ → Step 1-3 へ
   d. その他の文字列をタスク記述として使用する
7. リポジトリルートを決定する:
   - `--repo <owner/repo>` が指定された場合:
     - **Bash ツール**で `ghq list -p <owner/repo>` でローカルパスを検索する
     - 見つかればそのパスを `repo-root` として使用する
     - 見つからない場合は「ローカルに `<owner/repo>` が見つかりません」と表示して終了する
   - 指定なしの場合: **Bash ツール**で `git rev-parse --show-toplevel` を実行
8. session-slug を生成する: repo の `owner/repo` 形式から `/` を `-` に置換（例: `ishii1648-tmux-sidebar`）
9. session-name を決定する: `owner/repo` 形式（例: `ishii1648/tmux-sidebar`）。指定なしの場合は `git remote get-url origin` から抽出、取得できなければディレクトリ名を使用
10. session-id を生成する: `<session-slug>-YYYYMMDD-HHMMSS`（**Bash ツール**で `date +%Y%m%d-%H%M%S` で取得）

#### Step 1-3: issue 番号からタスク記述を取得

1. 番号を3桁ゼロ埋めして `docs/issues.md` の `ADR-NNN` セクションを Read して取得する
2. セクションの `**受け入れ条件**` と課題タイトルをタスク記述として使用する
3. 取得できない場合は「issues.md に ADR-NNN セクションが見つかりません」と表示して終了

#### Step 1-4: GitHub issue URL / shorthand からタスク記述を取得

1. URL 形式（`https://github.com/<owner>/<repo>/issues/<number>`）の場合:
   - URL から `<owner>/<repo>` を抽出する
   - `--repo` が未指定であれば自動設定する
   - `gh issue view <URL> --json title,body` で issue 情報を取得する
2. shorthand 形式（`<owner/repo>#<number>`）の場合:
   - `gh issue view <number> --repo <owner/repo> --json title,body` で取得する
   - `--repo` が未指定であれば `owner/repo` を自動設定する
3. issue の title と body を結合してタスク記述として使用する:
   - タスク記述 = `<title>\n\n<body の内容>`
4. 取得できない場合は「GitHub issue の取得に失敗しました」と表示して終了する

#### Step 1-5: TODO.md からタスク記述を取得

1. `--from-todo` の後にパスが指定されていればそのパスを使用、なければ `./TODO.md` を使用する
2. ファイルの存在チェック: 存在しない場合は「TODO.md が見つかりません: <path>」と表示して終了
3. **Read ツール**で TODO.md を読み込み、未完了タスク（`- [ ]` 行）を抽出する
4. 未完了タスクが 0 件の場合は「未完了タスクがありません」と表示して終了
5. 抽出したタスク一覧を以下の形式でタスク記述として構成する:
   ```
   TODO.md の以下の未完了タスクを実行してください:

   1. <タスク1の記述>
   2. <タスク2の記述>
   ...

   各タスクをサブタスクとして順番に実装してください。
   ```

### Step 2: タスクファイルを書き込み、orchestrate.sh launch を実行（dry-run 以外）

`--dry-run` の場合はこのステップをスキップして Step 3 へ進む。

1. **Write ツール**でタスクファイルを `<repo-root>/.outputs/claude/orchestrate-task-<session-slug>.md` に書き込む。タスク記述の全文のみを含める（エージェントプロンプトは orchestrate.sh が生成する）。

2. **Bash ツール**で `orchestrate.sh launch` を実行する:
   ```
   bash ~/.claude/skills/orchestrate/orchestrate.sh launch "<repo-root>" --session-id "<session-id>" --session-name "<session-name>" --session-slug "<session-slug>" --workflow "<workflow-type>" --task-file "<repo-root>/.outputs/claude/orchestrate-task-<session-slug>.md" [--agents "<a,b,c>"] --inherit-size
   ```
   - `custom` ワークフローの場合のみ `--agents` を追加する

3. STATUS に応じて分岐する:

   | STATUS | 対応 |
   |--------|------|
   | `LAUNCHED` | 完了報告して終了 |
   | `ERROR` | MESSAGE を表示して終了 |

4. 完了報告を表示する:
   ```
   session 作成: <SESSION>  [session-id: <SESSION_ID>]
   workflow: <WORKFLOW>
   agents: <AGENTS>
   worktree: <WORKTREE>

   エージェントチェーン実行中:
     1. <agent1> → 2. <agent2> → 3. <agent3> → ...
   各エージェント完了時に自動的に次のエージェントが起動します。

   確認: tmux attach -t <SESSION>
   クリーンアップ: /orchestrate cleanup <SESSION_ID>  (または <SESSION>)
   ```

   **元セッションの orchestrate skill はここで終了する。**

### Step 3: dry-run（エージェントチェーンの表示のみ）

`--dry-run` の場合のみ実行する。

1. ワークフロータイプからエージェントチェーンを決定する
2. 以下の形式で表示する:

   ```
   orchestrate dry-run:
     セッション: <session-name>
     ワークフロー: <workflow-type>
     worktree: orchestrate/<session-id>/work

     エージェントチェーン:
       1. <agent1>: <役割説明>
       2. <agent2>: <役割説明>
       ...

     ハンドオフ:
       <agent1> → HANDOFF-<agent1>-to-<agent2>.md → <agent2>
       <agent2> → HANDOFF-<agent2>-to-<agent3>.md → <agent3>
       ...
       <agentN> → FINAL-REPORT.md
   ```

3. ここで終了する。

### Step 4: cleanup サブコマンド

`/orchestrate cleanup <session-name|session-id>` が指定された場合:

**Bash ツール**で `orchestrate.sh cleanup` を実行する:
```
bash ~/.claude/skills/orchestrate/orchestrate.sh cleanup "<session-name|session-id>"
```

STATUS に応じて分岐する:

| STATUS | 対応 |
|--------|------|
| `CLEANED` | 削除されたリソースを表示して終了 |
| `ERROR` | MESSAGE を表示して終了 |

## 制約

- tmux セッション内でのみ動作する
- git リポジトリ内でのみ動作する
- worktree パスは `<repo-root>@orchestrate-<session-id>-work` 形式
- ネットワーク通信を伴うコマンドは使用しない（aws, curl, terraform 等）。ただし `gh` コマンドによる GitHub issue 取得は許可
