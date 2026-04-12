---
name: dispatch
description: タスク記述（または issue 番号・GitHub issue URL）を受け取り、実行戦略を動的に決定して worktree + Claude セッションを起動する統合エントリポイント。「/dispatch "認証ミドルウェアを修正"」「/dispatch --issue 53」「/dispatch <GitHub-issue-URL>」「/dispatch --repo ishii1648/tmux-sidebar "タスク"」「/dispatch cleanup <session>」で起動。
argument-hint: '"<タスク記述>" | --issue <番号> | <GitHub-issue-URL> | <owner/repo>#<number> | --repo <owner/repo> | --dry-run "<タスク記述>" | cleanup <session>'
version: 0.3.0
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

### Step 2: tmux session の作成（dry-run 以外）

`--dry-run` の場合はこのステップをスキップする。

`planning` ウィンドウを持つ dispatch セッションを作成する:

```
tmux new-session -d -s <session-name> -n planning -c <repo-root>
```

作成後、ユーザに以下を表示する:

```
session 作成: <session-name>  (planning ウィンドウで分析中...)
```

### Step 3: meta planner によるタスク分析

以下の処理を subagent（subagent_type=Explore）として実行し、計画 YAML を生成する。

**subagent への指示内容:**
- タスク記述を受け取り、以下を分析する:
  1. **タスク分解**: タスクを独立したサブタスクに分解する（最大6件）
  2. **依存関係分析**: サブタスク間の依存グラフを構築する
  3. **実行戦略選択**: 下記パターンから選択する
     | パターン | 条件 |
     |---|---|
     | single | 独立した単一タスク、または分解不要な小規模変更 |
     | parallel | 独立したサブタスクが複数あり相互依存なし |
     | pipeline | 前工程の成果物に後工程が依存する逐次処理 |
     | hybrid | 並列グループと逐次ハンドオフが混在 |
  4. **worktree 設計**: 必要な worktree 数・名前・ブランチ名を決定する
     - ブランチ名形式: `dispatch/<session-name>/<worktree-name>`
  5. **ワーカー指示書作成**: 各 Claude セッションへ送るプロンプトを生成する
     - pipeline/hybrid の場合、待機するハンドオフファイルパスを明示する
- 出力は以下の YAML 形式で `<repo-root>/.outputs/claude/dispatch-plan-<session-slug>.yaml` に書き込む:

```yaml
strategy: parallel        # single / parallel / pipeline / hybrid
session_name: "<session-name>"
task_summary: "<タスクの短い要約（30字以内）>"
worktrees:
  - name: "<worktree-name>"
    branch: "dispatch/<session-name>/<worktree-name>"
    depends_on: []          # 依存する worktree 名のリスト（pipeline/hybrid 用）
    prompt: |
      <このワーカーへ送信するプロンプト>
```

### Step 4: 計画の表示と確認

meta planner が生成した YAML を Read して以下の手順で表示する。

**planning ウィンドウへの表示（dry-run 以外）:**
以下のコマンドで planning ウィンドウに計画 YAML の全内容を表示する:
```
tmux send-keys -t <session-name>:planning "cat <plan-yaml-path>" Enter
```

**現在のターミナルへの表示（prompt は全文表示）:**
```
dispatch 計画:
  セッション: <session-name>
  戦略: <strategy>
  タスク: <task_summary>

  worktree 一覧:
    0: <name>  (branch: <branch>)
       prompt:
         <promptの全文（各行2スペースインデント）>
    1: <name>  (branch: <branch>)
       依存: <depends_on>（なければ省略）
       prompt:
         <promptの全文（各行2スペースインデント）>
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
   git -C <repo-root> worktree add .dispatch/<session-slug>/<name> -b <branch>
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

5. **セッションマニフェストを書き込む**（部分失敗時の復旧・cleanup の基盤）:
   - パス: `~/.dispatch/<session-slug>/manifest.json`（リポジトリ外に配置しエージェントによる改ざんを防ぐ）
   - 各リソース作成後に都度更新し、cleanup はこのファイルを参照する
   - フォーマット:
     ```json
     {
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
           "path": "<repo-root>/.dispatch/<session-slug>/<worktree-name>",
           "branch": "dispatch/<session-name>/<worktree-name>",
           "created": false
         }
       ],
       "tmux_session": "<session-name>"
     }
     ```
   - `creation_state` は起動開始時 `"partial"` で書き込み、全ウィンドウ起動完了後に `"complete"` へ更新する
   - 各 worktree の `"created"` は worktree 作成成功後に `true` へ更新する
   - 中断時は `creation_state: "partial"` のまま残り、復旧時の基準となる
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

`/dispatch cleanup <session-name>` が指定された場合:

**Step 6-1: マニフェストの読み込みと検証（fail-closed）**
- session-slug = session-name の `/` を `-` に置換して求める（例: `ishii1648/tmux-sidebar` → `ishii1648-tmux-sidebar`）
- `~/.dispatch/<session-slug>/manifest.json` を Read する（リポジトリ外の dispatcher-owned ファイル）
- マニフェストが存在しない場合は「マニフェストが見つかりません。手動で以下を確認してください: git worktree list, git branch -l 'dispatch/<session-name>/*'」と表示して**中断する**
- 以下の検証をすべて通過しない場合は「マニフェスト検証失敗: <理由>」と表示して**中断する**:
  1. `repo_root` が現在の `git rev-parse --show-toplevel` と一致すること
  2. `worktrees[].path` がすべて `<repo_root>/.dispatch/<session-slug>/` 配下であること
  3. `worktrees[].branch` がすべて `dispatch/<session-name>/` プレフィックスを持つこと
  4. `tmux_session` が `<session-name>` と一致すること

**Step 6-2: リソースの削除（`created: true` のもののみ）**
1. tmux セッションを削除する: `tmux kill-session -t <tmux_session>`
2. マニフェストの `worktrees[].created == true` の各 worktree を削除する:
   - `git worktree remove --force <path>`
3. マニフェストの `worktrees[].created == true` の各ブランチを削除する:
   - `git -C <repo_root> branch -D <branch>`
4. worktree ディレクトリを削除する: `rm -r <repo_root>/.dispatch/<session-slug>`
   - マニフェストファイルを削除する: `rm -r ~/.dispatch/<session-slug>`
5. 計画 YAML を削除する: `rm <repo_root>/.outputs/claude/dispatch-plan-<session-slug>.yaml`
6. role ファイルを削除する（該当セッションのペイン分のみ）

## 制約

- tmux セッション内でのみ動作する
- git リポジトリ内でのみ動作する
- ファイル削除には `rm` を使用する（`rm -rf` は禁止）
- `.dispatch/` ディレクトリは `.gitignore` に追加する
- ネットワーク通信を伴うコマンドは使用しない（aws, curl, terraform 等）
