---
name: orchestrate
description: タスク記述（または issue 番号・GitHub issue URL・TODO.md）を受け取り、meta planner が計画を立ててから単一 worktree で実行する。parent が worktree を事前作成し、planning Claude が計画→実行を担当する。「/orchestrate "タスク記述"」「/orchestrate --issue 53」「/orchestrate --from-todo TODO.md」「/orchestrate --dry-run "タスク"」「/orchestrate cleanup <session>」で起動。
argument-hint: '"<タスク記述>" | --issue <番号> | <GitHub-issue-URL> | <owner/repo>#<number> | --repo <owner/repo> | --from-todo [path] | --dry-run "<タスク記述>" | cleanup <session>'
version: 3.0.0
---

# orchestrate

タスク記述または issue 番号を受け取り、meta planner が計画を立ててから単一 worktree で実行する。parent が worktree・tmux セッションを事前作成し、planning Claude が計画策定→実装を一貫して担当する。

単一ブランチで完結する小規模作業には `/dispatch`（軽量版・planning なし）を使用する。

コアロジック（worktree 作成・tmux セッション・Claude 起動・cleanup）は `~/.claude/skills/orchestrate/orchestrate.sh` に委譲する。

## 引数フォーマット

```
/orchestrate "<タスク記述>"
/orchestrate --issue <番号>
/orchestrate <GitHub-issue-URL>
/orchestrate <owner/repo>#<number>
/orchestrate --repo <owner/repo> "<タスク記述>"
/orchestrate --repo <owner/repo> --issue <番号>
/orchestrate --from-todo [path]
/orchestrate --dry-run "<タスク記述>"
/orchestrate --dry-run --issue <番号>
/orchestrate cleanup <session-name|session-id>
```

## ステップ

### Step 1: 引数の解析とタスク記述の構築

1. 第1引数でサブコマンドを判定する
   - `cleanup` の場合は Step 4 へジャンプ
2. `--dry-run` フラグを検出してフラグ変数に保持する
3. `--repo <owner/repo>` フラグを検出してリポジトリ変数に保持する
4. `--from-todo [path]` フラグを検出した場合は Step 1-5 へ
5. 残り引数から以下を順に検出する:
   a. `https://github.com/` で始まる文字列（GitHub issue URL）→ Step 1-4 へ（URL から owner/repo も自動設定）
   b. `<owner/repo>#<number>` パターン（例: `ishii1648/tmux-sidebar#2`）→ Step 1-4 へ（owner/repo を自動設定）
   c. `--issue <番号>` フラグ → Step 1-3 へ
   d. その他の文字列をタスク記述として使用する
6. リポジトリルートを決定する:
   - `--repo <owner/repo>` が指定された場合:
     - **Bash ツール**で `ghq list -p <owner/repo>` でローカルパスを検索する
     - 見つかればそのパスを `repo-root` として使用する
     - 見つからない場合は「ローカルに `<owner/repo>` が見つかりません」と表示して終了する
   - 指定なしの場合: **Bash ツール**で `git rev-parse --show-toplevel` を実行
7. session-slug を生成する: repo の `owner/repo` 形式から `/` を `-` に置換（例: `ishii1648-tmux-sidebar`）
8. session-name を決定する: `owner/repo` 形式（例: `ishii1648/tmux-sidebar`）。指定なしの場合は `git remote get-url origin` から抽出、取得できなければディレクトリ名を使用
9. session-id を生成する: `<session-slug>-YYYYMMDD-HHMMSS`（**Bash ツール**で `date +%Y%m%d-%H%M%S` で取得）

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

### Step 2: 計画プロンプトファイルを書き込み、orchestrate.sh launch を実行（dry-run 以外）

`--dry-run` の場合はこのステップをスキップして Step 3 へ進む。

1. **Write ツール**で計画プロンプトファイルを `<repo-root>/.outputs/claude/orchestrate-task-<session-slug>.md` に書き込む:

   ````markdown
   # orchestrate: 計画 → 実行

   以下のタスクを分析し、計画を立ててからこの worktree 内で実装してください。

   ## コンテキスト

   - session-id: <session-id>
   - session-name: <session-name>
   - repo-root: <repo-root>
   - worktree-path: <repo-root>@orchestrate-<session-id>-work
   - branch: orchestrate/<session-id>/work
   - plan-yaml-path: <repo-root>/.outputs/claude/orchestrate-plan-<session-slug>.yaml
   - manifest-path: ~/.orchestrate/<session-id>/manifest.json

   あなたは worktree 内（`<repo-root>@orchestrate-<session-id>-work`）で起動されています。すべてのファイル操作はこの worktree 内で行ってください。

   ## Bash ツール使用の制約

   以下の制約はすべての Bash 呼び出しに適用される（PreToolUse hook が強制）:
   - `&&`/`||`/`;` での複数コマンド連結は**禁止**。各コマンドを個別の Bash 呼び出しに分割すること
   - `$()` コマンド置換は**禁止**。前の Bash 呼び出し結果の出力から値を読み取ること
   - ファイル書き込みには Write ツールを使用すること（`echo >` や `cat >` は禁止）
   - `mkdir` は禁止。Write ツールはディレクトリを自動作成する
   - Bash から `/tmp/` へのリダイレクト（`> /tmp/...`）は禁止（Write ツールは使用可）

   ## Phase 1: 計画

   1. コードベースを読んでタスクの影響範囲を把握する
   2. サブタスクに分解する（実装順序を決定）
   3. **Write ツール**で以下の YAML を `<plan-yaml-path>` に書き込む:

   ```yaml
   session_name: "<session-name>"
   task_summary: "<30字以内の要約>"
   subtasks:
     - name: "<サブタスク名>"
       description: "<サブタスクの説明>"
       files: ["<対象ファイル>"]
     - name: "<サブタスク名>"
       description: "<サブタスクの説明>"
       files: ["<対象ファイル>"]
   ```

   ## Phase 2: 実装

   計画 YAML を書き込んだ後、この worktree 内でサブタスクを順番に実装する。

   1. 各サブタスクを順番に実装する
   2. テストがあれば実行して確認する
   3. 実装完了後、変更を git commit する（コミットメッセージはタスク内容を反映）
   4. **Write ツール**でマニフェストの `creation_state` を `"complete"` に更新する

   ## タスク記述

   <タスク記述（全文）>
   ````

2. **Bash ツール**で `orchestrate.sh launch` を実行する:
   ```
   bash ~/.claude/skills/orchestrate/orchestrate.sh launch "<repo-root>" --session-id "<session-id>" --session-name "<session-name>" --session-slug "<session-slug>" --prompt-file "<repo-root>/.outputs/claude/orchestrate-task-<session-slug>.md" --inherit-size
   ```

3. STATUS に応じて分岐する:

   | STATUS | 対応 |
   |--------|------|
   | `LAUNCHED` | 完了報告して終了 |
   | `ERROR` | MESSAGE を表示して終了 |

4. 完了報告を表示する:
   ```
   session 作成: <SESSION>  [session-id: <SESSION_ID>]
   worktree: <WORKTREE>
   計画→実行中...  (tmux attach -t <SESSION> で確認できます)
   クリーンアップ: /orchestrate cleanup <SESSION_ID>  (または <SESSION>)
   ```

   **元セッションの orchestrate skill はここで終了する。**

### Step 3: 計画 YAML の生成と表示（dry-run 専用）

`--dry-run` の場合のみ実行する。

1. 自身でタスクを分析して計画 YAML を生成し、`<repo-root>/.outputs/claude/orchestrate-plan-<session-slug>.yaml` に Write ツールで書き込む（tmux セッション・worktree は作成しない）。
2. YAML を Read して以下の形式で **現在のターミナル** に全文表示する:

   ```
   orchestrate 計画:
     セッション: <session-name>
     タスク: <task_summary>
     worktree: orchestrate/<session-id>/work

     サブタスク:
       1. <name>: <description>
          files: <files>
       2. <name>: <description>
          files: <files>
       ...
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
