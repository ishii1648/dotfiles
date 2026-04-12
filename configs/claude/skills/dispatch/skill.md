---
name: dispatch
description: タスク記述（または issue 番号・GitHub issue URL）を受け取り、実行戦略を動的に決定して worktree + Claude セッションを起動する統合エントリポイント。「/dispatch "認証ミドルウェアを修正"」「/dispatch --issue 53」「/dispatch <GitHub-issue-URL>」「/dispatch --repo ishii1648/tmux-sidebar "タスク"」「/dispatch cleanup <session>」で起動。
argument-hint: '"<タスク記述>" | --issue <番号> | <GitHub-issue-URL> | <owner/repo>#<number> | --repo <owner/repo> | --dry-run "<タスク記述>" | cleanup <session>'
version: 0.4.0
---

# dispatch

タスク記述または issue 番号だけを受け取り、meta planner がタスクを分析して実行戦略（single/parallel/pipeline/hybrid）を自動決定する。各戦略に応じて git worktree と tmux ウィンドウを作成し、Claude セッションを起動する。

## 引数フォーマット

```
/dispatch "<タスク記述>"
/dispatch --issue <番号>
/dispatch <GitHub-issue-URL>
/dispatch <owner/repo>#<number>
/dispatch --repo <owner/repo> "<タスク記述>"
/dispatch --repo <owner/repo> --issue <番号>
/dispatch --dry-run "<タスク記述>"
/dispatch --dry-run --issue <番号>
/dispatch cleanup <session-name>
```

- `<タスク記述>`: 実行したいタスクの自然言語説明
- `--issue <番号>`: `docs/issues.md` の ADR 番号を参照してタスクを起動（例: `--issue 53`）
- `<GitHub-issue-URL>`: `https://github.com/<owner>/<repo>/issues/<number>` 形式。issue title + body をタスク記述として使用し、owner/repo を自動設定する
- `<owner/repo>#<number>`: GitHub issue の shorthand 形式（例: `ishii1648/tmux-sidebar#2`）
- `--repo <owner/repo>`: 作業リポジトリを明示指定する。`ghq` のローカルパスを使用（例: `--repo ishii1648/tmux-sidebar`）
- `--dry-run`: 実行計画を表示するが実際の起動は行わない
- `cleanup <session-name>`: 指定セッションのリソースをすべて削除

## ステップ

### Step 1: 引数の解析と事前チェック

1. 第1引数でサブコマンドを判定する
   - `cleanup` の場合は Step 6 へジャンプ
2. `--dry-run` フラグを検出してフラグ変数に保持する
3. `--repo <owner/repo>` フラグを検出してリポジトリ変数に保持する
4. 残り引数から以下を順に検出する:
   a. `https://github.com/` で始まる文字列（GitHub issue URL）→ Step 1-4 へ（URL から owner/repo も自動設定）
   b. `<owner/repo>#<number>` パターン（例: `ishii1648/tmux-sidebar#2`）→ Step 1-4 へ（owner/repo を自動設定）
   c. `--issue <番号>` フラグ → Step 1-3 へ
   d. その他の文字列をタスク記述として使用する
5. tmux セッション外かチェック:
   - `tmux display-message -p '#{session_name}' 2>/dev/null` が空なら「tmux セッション外では動作しません」と表示して終了
6. リポジトリルートを決定する:
   - `--repo <owner/repo>` が指定された場合:
     - `ghq list -p <owner/repo>` でローカルパスを検索する
     - 見つかればそのパスを `repo-root` として使用する
     - 見つからない場合は「ローカルに `<owner/repo>` が見つかりません。`ghq get <owner/repo>` で取得してください」と表示して終了する
   - 指定なしの場合: `git rev-parse --show-toplevel 2>/dev/null` が空なら「git リポジトリ外では動作しません」と表示して終了
7. session-name を決定する（tmux セッション名として使用）:
   - `--repo <owner/repo>` が指定されている場合: session-name = `<owner>/<repo>`（例: `ishii1648/tmux-sidebar`）
   - 指定なしの場合: `git remote get-url origin 2>/dev/null` から `owner/repo` を抽出して session-name とする。取得できない場合はリポジトリのディレクトリ名を使用する。
   - 同名の tmux セッションが既存の場合（`tmux has-session -t <session-name>` が成功）: `-2`、`-3` と数字サフィックスを付加して衝突を回避する
8. session-slug を生成する: session-name の `/` を `-` に置換したファイルシステム安全な識別子（例: `ishii1648-tmux-sidebar`）
   - 計画 YAML の出力先: `<repo-root>/.outputs/claude/dispatch-plan-<session-slug>.yaml`
   - `.outputs/claude/` ディレクトリが存在しない場合は Write ツールで `.outputs/claude/.gitkeep` を作成して対応する
9. session-id を生成する: `<session-slug>-YYYYMMDD-HHMMSS-XXXX`（XXXX は4桁ランダム英数字）
   - **表示名（session-name）とは別の不変識別子**。後続のマニフェストパス・ブランチプレフィックス・worktree パスはすべて session-id でスコープする
   - マニフェストパス: `~/.dispatch/<session-id>/manifest.json`
10. **マニフェストを初期書き込みする（すべての副作用より前）**:
    - `~/.dispatch/<session-id>/manifest.json` を Write ツールで作成する
    ```json
    {
      "session_id": "<session-id>",
      "session_name": "<session-name>",
      "session_slug": "<session-slug>",
      "repo_root": "<repo-root>",
      "created_at": "<ISO8601-timestamp>",
      "creation_state": "partial",
      "worktrees": [],
      "tmux_session": "<session-name>",
      "tmux_created": false
    }
    ```
    - この時点ではまだ tmux も worktree も存在しない（`partial` + 空リスト）
    - クラッシュしても `~/.dispatch/` を走査すれば session-id でこのセッションを発見できる

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

### Step 2: tmux session の作成と planning ウィンドウで Claude を起動（dry-run 以外）

`--dry-run` の場合はこのステップをスキップする。

1. **計画プロンプトファイルを書き込む**: Write ツールで `/tmp/dispatch-task-<session-slug>.md` に以下の内容を書き込む:
   ```markdown
   # dispatch meta planning

   以下のタスクを分析し、`<plan-yaml-path>` に計画 YAML を生成してください。

   ## タスク記述

   <タスク記述（全文）>

   ## 分析内容

   1. タスクを独立したサブタスクに分解する（最大6件）
   2. サブタスク間の依存グラフを構築する
   3. 実行戦略を選択する:
      - single: 単一タスクまたは分解不要な小規模変更
      - parallel: 相互依存なしの複数独立タスク
      - pipeline: 前工程の成果物に後工程が依存する逐次処理
      - hybrid: 並列グループと逐次ハンドオフが混在
   4. worktree 数・名前・ブランチ名を決定する（ブランチ形式: `dispatch/<session-id>/<name>`）
   5. 各ワーカーへの詳細な指示書（プロンプト）を作成する

   ## 出力形式

   以下の YAML を `<plan-yaml-path>` に書き込んでください:

   ```yaml
   strategy: single
   session_name: "<session-name>"
   task_summary: "<30字以内の要約>"
   worktrees:
     - name: "<worktree-name>"
       branch: "dispatch/<session-id>/<worktree-name>"
       depends_on: []
       prompt: |
         <ワーカーへのプロンプト全文（受け入れ条件・実装対象・実装方針・確認手順を含む）>
   ```
   ```

2. **セッションを作成する**:
   ```
   tmux new-session -d -s <session-name> -n planning -c <repo-root>
   ```
   作成後、マニフェストの `tmux_created` を `true` に更新する（クラッシュ時に tmux が孤立していることを示す）。

3. **planning ウィンドウで Claude を起動し、計画プロンプトを送信する**:
   ```
   tmux send-keys -t <session-name>:planning "claude" Enter
   ```
   3 秒待機してから:
   ```
   tmux send-keys -t <session-name>:planning "/tmp/dispatch-task-<session-slug>.md を読んで指示通りに実行してください" Enter
   ```

4. ユーザに以下を表示する:
   ```
   session 作成: <session-name>  [session-id: <session-id>]
   planning ウィンドウで計画を作成中...  (tmux attach -t <session-name> で確認できます)
   クリーンアップ: /dispatch cleanup <session-id>  (または <session-name>)
   ```

### Step 3: 計画 YAML の完成を待機

planning ウィンドウの Claude が `<plan-yaml-path>` を書き込むまで待機する。
subagent（subagent_type=Explore）として以下を実行する:

- `<plan-yaml-path>` を Read する
- ファイルが存在しない / 空の場合は 5 秒待機して再試行する（最大 12 回 = 60 秒）
- ファイルが存在して内容があれば、YAML 内容を返す
- タイムアウトした場合は「計画の生成がタイムアウトしました。planning ウィンドウを確認してください」と表示して終了する

**`--dry-run` の場合:** セッションを作成せず、自身で計画 YAML を生成して `<plan-yaml-path>` に書き込む。

### Step 4: 計画の表示と確認

`<plan-yaml-path>` を Read して以下の形式で **現在のターミナル** に全文表示する（prompt も全文）:

```
dispatch 計画:
  セッション: <session-name>
  戦略: <strategy>
  タスク: <task_summary>

  worktree 一覧:
    0: <name>  (branch: <branch>)
       prompt:
         <promptの全文（各行4スペースインデント）>
    1: <name>  (branch: <branch>)
       依存: <depends_on>（なければ省略）
       prompt:
         <promptの全文（各行4スペースインデント）>
  ...
```

**`--dry-run` の場合はここで終了する。**

それ以外の場合は AskUserQuestion で「上記の計画で起動しますか？（yes/no）」を確認する。
- `no` の場合:
  - `tmux kill-session -t <session-name>` で session を削除する
  - 「キャンセルしました」と表示して終了する。

### Step 5: worktree と tmux ウィンドウの作成・Claude 起動

worktrees リストの各エントリについて順番に実行する:

1. **git worktree を作成する**:
   ```
   git -C <repo-root> worktree add .dispatch/<session-id>/<name> -b dispatch/<session-id>/<name>
   ```

2. **tmux ウィンドウを作成する**（ウィンドウ名 = worktree name）:
   - session はすでに存在するため、すべてのエントリで `new-window` を使用する:
     ```
     tmux new-window -t <session-name> -n <name> -c <worktree-path>
     ```

3. **ワーカーロールファイルを書き込む**（sidebar 用）:
   ```
   PANE_NUM=$(tmux display-message -p -t "<session-name>:<name>" "#{pane_id}" | tr -d '%')
   mkdir -p /tmp/claude-pane-state
   echo "<name>" > /tmp/claude-pane-state/pane_${PANE_NUM}_role
   ```

4. `.gitignore` に `.dispatch/` が含まれていない場合は追記する

5. **セッションマニフェストを事前に書き込む**（manifest-first: 副作用より前に書く）:
   - **最初の `git worktree add` より前に必ず書き込む**（クラッシュ時の回収基盤）
   - パス: `~/.dispatch/<session-id>/manifest.json`（session-id 形式でスコープ、エージェントから独立）
   - 書き込みタイミング: すべての worktree を `created: false` で事前宣言してから作成を開始する
   - フォーマット:
     ```json
     {
       "session_id": "<session-id>",
       "session_name": "<session-name>",
       "session_slug": "<session-slug>",
       "repo_root": "<repo-root>",
       "created_at": "<ISO8601-timestamp>",
       "creation_state": "partial",
       "strategy": "<strategy>",
       "task_summary": "<task_summary>",
       "worktrees": [
         {
           "name": "<worktree-name>",
           "path": "<repo-root>/.dispatch/<session-id>/<worktree-name>",
           "branch": "dispatch/<session-id>/<worktree-name>",
           "created": false
         }
       ],
       "tmux_session": "<session-name>"
     }
     ```
   - `creation_state` は起動開始時 `"partial"` で書き込み、全ウィンドウ起動完了後に `"complete"` へ更新する
   - 各 worktree の `"created"` は worktree 作成成功後に `true` へ更新する（事前宣言済みのため未作成は `false` のまま）
   - マニフェストが存在するセッションのみが cleanup 対象として安全に識別できる

全 worktree 作成後、`planning` ウィンドウを削除する:
```
tmux kill-window -t <session-name>:planning
```

各 worktree ウィンドウで Claude を起動してプロンプトを送信する:

1. Claude Code を起動する:
   ```
   tmux send-keys -t <session-name>:<name> "claude" Enter
   ```
   起動完了まで 3 秒待機する。

2. YAML の `prompt` フィールドの内容をそのまま送信する:
   ```
   tmux send-keys -t <session-name>:<name> "<prompt>" Enter
   ```

全ウィンドウ起動後、以下を表示する:

```
dispatch 開始: <session-name>
戦略: <strategy>
タスク: <task_summary>

worktree:
  0: <name>  → .dispatch/<session-slug>/<name>/
  1: <name>  → .dispatch/<session-slug>/<name>/
  ...

確認方法:
  prefix+s                        : tmux セッション一覧でワーカー状態を確認
  tmux attach -t <session-name>   : セッションに接続

クリーンアップ:
  /dispatch cleanup <session-name>
```

### Step 6: cleanup サブコマンド

`/dispatch cleanup <session-name|session-id>` が指定された場合:

**Step 6-1: マニフェストの読み込みと検証（fail-closed・呼び出し元リポジトリに依存しない）**
- 引数が `session-id` 形式（`<slug>-YYYYMMDD-HHMMSS-XXXX` パターン）の場合: `~/.dispatch/<session-id>/manifest.json` を直接 Read する（最も確実な指定方法）
- 引数が `session-name` 形式の場合: `~/.dispatch/` 以下を走査して `session_name` フィールドが一致するマニフェストを探す
  - `ls ~/.dispatch/` でサブディレクトリを列挙し、各 `manifest.json` の `session_name` フィールドを確認する
  - 一致するものを対象マニフェストとする
- マニフェストが見つからない場合は「マニフェストが見つかりません」と表示して**中断する**
- 複数見つかった場合は `session_id`・`created_at`・`creation_state`・`task_summary` を一覧表示してユーザに選択させる
- マニフェストから `repo_root` と `session_id` を取得する（呼び出し元の CWD は使用しない）
- 以下の検証をすべて通過しない場合は「マニフェスト検証失敗: <理由>」と表示して**中断する**:
  1. `worktrees[].path` がすべて `<manifest.repo_root>/.dispatch/<session_id>/` 配下であること
  2. `worktrees[].branch` がすべて `dispatch/<session_id>/` プレフィックスを持つこと
  3. `tmux_session` が `<session-name>` と一致すること

**Step 6-2: 実際の状態との reconciliation（クラッシュ時に manifest 未更新のリソースを回収）**
- `git -C <manifest.repo_root> worktree list --porcelain` で `<manifest.repo_root>/.dispatch/<session_id>/` 配下のすべての worktree を列挙する
- `git -C <manifest.repo_root> branch --list "dispatch/<session_id>/*"` でセッションに属するすべてのブランチを列挙する
- これらを manifest の `worktrees[]` と照合し、**manifest の有無に関わらず** `<session_id>` スコープに属するリソースをすべて削除対象とする
  - マニフェスト未記録のリソース（クラッシュ直前に作成されたもの）も確実に回収できる

**Step 6-3: リソースの削除**
1. tmux セッションを削除する（`tmux_created: true` の場合のみ）: `tmux kill-session -t <tmux_session>`
2. reconciliation で特定したすべての worktree を削除する:
   - `git -C <manifest.repo_root> worktree remove --force <path>`
3. reconciliation で特定したすべてのブランチを削除する:
   - `git -C <manifest.repo_root> branch -D <branch>`
4. worktree ディレクトリを削除する: `rm -r <manifest.repo_root>/.dispatch/<session_id>`
5. マニフェストファイルを削除する: `rm -r ~/.dispatch/<session_id>`
6. 計画 YAML を削除する: `rm <manifest.repo_root>/.outputs/claude/dispatch-plan-<session-slug>.yaml`
7. role ファイルを削除する（該当セッションのペイン分のみ）

## 制約

- tmux セッション内でのみ動作する
- git リポジトリ内でのみ動作する
- ファイル削除には `rm` を使用する（`rm -rf` は禁止）
- `.dispatch/` ディレクトリは `.gitignore` に追加する
- ネットワーク通信を伴うコマンドは使用しない（aws, curl, terraform 等）
