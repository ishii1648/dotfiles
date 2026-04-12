---
name: dispatch
description: タスク記述（または issue 番号）を受け取り、実行戦略を動的に決定して worktree + Claude セッションを起動する統合エントリポイント。「/dispatch "認証ミドルウェアを修正"」「/dispatch --issue 53」「/dispatch --dry-run "タスク"」「/dispatch cleanup <session>」で起動。
argument-hint: '"<タスク記述>" | --issue <番号> | --dry-run "<タスク記述>" | cleanup <session>'
version: 0.1.0
---

# dispatch

タスク記述または issue 番号だけを受け取り、meta planner がタスクを分析して実行戦略（single/parallel/pipeline/hybrid）を自動決定する。各戦略に応じて git worktree と tmux ウィンドウを作成し、Claude セッションを起動する。

## 引数フォーマット

```
/dispatch "<タスク記述>"
/dispatch --issue <番号>
/dispatch --dry-run "<タスク記述>"
/dispatch --dry-run --issue <番号>
/dispatch cleanup <session-name>
```

- `<タスク記述>`: 実行したいタスクの自然言語説明
- `--issue <番号>`: `docs/issues.md` の ADR 番号を参照してタスクを起動（例: `--issue 53`）
- `--dry-run`: 実行計画を表示するが実際の起動は行わない
- `cleanup <session-name>`: 指定セッションのリソースをすべて削除

## ステップ

### Step 1: 引数の解析と事前チェック

1. 第1引数でサブコマンドを判定する
   - `cleanup` の場合は Step 6 へジャンプ
2. `--dry-run` フラグを検出してフラグ変数に保持する
3. `--issue <番号>` フラグを検出した場合は Step 1-3 へ
4. タスク記述を取得する（引数から `--dry-run` / `--issue` フラグを除いた残り）
5. tmux セッション外かチェック:
   - `tmux display-message -p '#{session_name}' 2>/dev/null` が空なら「tmux セッション外では動作しません」と表示して終了
6. git リポジトリ外かチェック:
   - `git rev-parse --show-toplevel 2>/dev/null` が空なら「git リポジトリ外では動作しません」と表示して終了

#### Step 1-3: issue 番号からタスク記述を取得

1. 番号を3桁ゼロ埋めして `docs/issues.md` の `ADR-NNN` セクションを Read して取得する
2. セクションの `**受け入れ条件**` と課題タイトルをタスク記述として使用する
3. 取得できない場合は「issues.md に ADR-NNN セクションが見つかりません」と表示して終了

### Step 2: meta planner によるタスク分析

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
- 出力は以下の YAML 形式で `/tmp/dispatch-plan-<timestamp>.yaml` に書き込む:

```yaml
strategy: parallel        # single / parallel / pipeline / hybrid
session_name: dispatch-YYYYMMDD-HHMMSS
task_summary: "<タスクの短い要約（30字以内）>"
worktrees:
  - name: "<worktree-name>"
    branch: "dispatch/<session-name>/<worktree-name>"
    depends_on: []          # 依存する worktree 名のリスト（pipeline/hybrid 用）
    prompt: |
      <このワーカーへ送信するプロンプト>
```

### Step 3: 計画の表示と確認

meta planner が生成した YAML を Read して以下の形式で表示する:

```
dispatch 計画:
  セッション: <session-name>
  戦略: <strategy>
  タスク: <task_summary>

  worktree 一覧:
    0: <name>  (branch: <branch>)
       → <promptの最初の1行>
    1: <name>  (branch: <branch>)
       依存: <depends_on>
       → <promptの最初の1行>
  ...
```

**`--dry-run` の場合はここで終了する。**

それ以外の場合は AskUserQuestion で「上記の計画で起動しますか？（yes/no）」を確認する。
- `no` の場合は「キャンセルしました」と表示して終了する。

### Step 4: worktree と tmux ウィンドウの作成

リポジトリルートを取得する: `git rev-parse --show-toplevel`

worktrees リストの各エントリについて順番に実行する:

1. **git worktree を作成する**:
   ```
   git -C <repo-root> worktree add .dispatch/<session-name>/<name> -b <branch>
   ```

2. **tmux ウィンドウを作成する**（ウィンドウ名 = worktree name）:
   - 最初のエントリ: セッションごと作成
     ```
     tmux new-session -d -s <session-name> -n <name> -c <worktree-path>
     ```
   - 2番目以降:
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

### Step 5: Claude の起動とプロンプト送信

各 worktree ウィンドウで:

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
  0: <name>  → .dispatch/<session-name>/<name>/
  1: <name>  → .dispatch/<session-name>/<name>/
  ...

確認方法:
  prefix+s                        : tmux セッション一覧でワーカー状態を確認
  tmux attach -t <session-name>   : セッションに接続

クリーンアップ:
  /dispatch cleanup <session-name>
```

### Step 6: cleanup サブコマンド

`/dispatch cleanup <session-name>` が指定された場合:

1. tmux セッションを削除する: `tmux kill-session -t <session-name>`
2. git worktree をすべて削除する:
   - `git worktree list` で `.dispatch/<session-name>/` を含む worktree を特定する
   - 各 worktree を `git worktree remove --force <path>` で削除する
3. dispatch ブランチを削除する:
   - `git branch | grep "dispatch/<session-name>/"` でブランチを特定する
   - 各ブランチを `git branch -D <branch>` で削除する
4. worktree ディレクトリを削除する: `rm -r <repo-root>/.dispatch/<session-name>`
5. 計画 YAML を削除する: `rm -f /tmp/dispatch-plan-*.yaml`（該当セッション分のみ）
6. role ファイルを削除する（該当セッションのペイン分のみ）

## 制約

- tmux セッション内でのみ動作する
- git リポジトリ内でのみ動作する
- ファイル削除には `rm` を使用する（`rm -rf` は禁止）
- `.dispatch/` ディレクトリは `.gitignore` に追加する
- ネットワーク通信を伴うコマンドは使用しない（aws, curl, terraform 等）
