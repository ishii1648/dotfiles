---
name: orchestrate
description: マルチエージェントオーケストレーションを実行する。feature/bugfix/refactor/security/custom のワークフロータイプを指定して各エージェントを tmux ウィンドウ + git worktree で起動し、ハンドオフ文書で引き継ぐ。「/orchestrate feature "新機能追加"」「/orchestrate bugfix」「orchestrate cleanup <session>」などで起動。
argument-hint: "<feature|bugfix|refactor|security|custom> [task] | custom <agents> [task] | cleanup <session>"
disable-model-invocation: true
version: 0.1.0
---

# orchestrate

マルチエージェントオーケストレーションを tmux + git worktree モードで実行する。

## ワークフロータイプ

| タイプ | エージェントチェーン |
|--------|---------------------|
| `feature` | planner → tdd-guide → code-reviewer → security-reviewer |
| `bugfix` | planner → tdd-guide → code-reviewer |
| `refactor` | architect → code-reviewer → tdd-guide |
| `security` | security-reviewer → code-reviewer → architect |
| `custom` | 引数で指定した任意エージェント列（カンマ区切り） |

## 引数フォーマット

```
/orchestrate <workflow-type> [task-description]
/orchestrate custom <agents> [task-description]
/orchestrate cleanup <session-name>
```

- `workflow-type`: feature / bugfix / refactor / security / custom
- `task-description`: タスクの説明（省略時は AskUserQuestion で確認）
- `custom` の `agents`: カンマ区切りのエージェント名（例: `planner,code-reviewer`）
- `cleanup <session-name>`: 指定セッションのリソースを削除

## ステップ

### Step 1: 引数の解析と事前チェック

1. 第1引数でサブコマンドを判定する
   - `cleanup` の場合は Step 5 へジャンプ
2. ワークフロータイプを取得する（feature / bugfix / refactor / security / custom）
3. `custom` の場合は第2引数からエージェントリストをカンマ分割で取得する
4. task-description が空の場合は AskUserQuestion で確認する
5. tmux セッション外かチェック:
   - `tmux display-message -p '#{session_name}' 2>/dev/null` が空なら「tmux セッション外では動作しません」と表示して終了
6. git リポジトリ外かチェック:
   - `git rev-parse --show-toplevel 2>/dev/null` が空なら「git リポジトリ外では動作しません」と表示して終了

### Step 2: セッション名とワークスペースの準備

1. タイムスタンプ付きセッション名を生成する:
   - 形式: `orch-YYYYMMDD-HHMMSS`（例: `orch-20240101-120000`）
   - Bash コマンド: `date '+orch-%Y%m%d-%H%M%S'`
2. リポジトリルートを取得する: `git rev-parse --show-toplevel`
3. ハンドオフ文書ディレクトリを作成する:
   - パス: `<repo-root>/.orchestrate/<session-name>/`
4. `.gitignore` に `.orchestrate/` が含まれていない場合は追記する

### Step 3: ワーカーの起動

ワークフロータイプに応じたエージェントリストを決定し、順番に以下を実行する。

#### 3-1: エージェントリストの決定

| タイプ | エージェントリスト |
|--------|------------------|
| feature | planner, tdd-guide, code-reviewer, security-reviewer |
| bugfix | planner, tdd-guide, code-reviewer |
| refactor | architect, code-reviewer, tdd-guide |
| security | security-reviewer, code-reviewer, architect |
| custom | 引数で受け取ったリスト |

#### 3-2: 各エージェントの git worktree と tmux ウィンドウを作成する

エージェントリストの各エージェントについて:

1. **git worktree を作成する**:
   ```
   git -C <repo-root> worktree add .orchestrate/<session-name>/<agent> -b orch/<session-name>/<agent>
   ```

2. **tmux ウィンドウを作成する**（ウィンドウ名 = エージェント名）:
   - 最初のエージェント: セッションごと作成
     ```
     tmux new-session -d -s <session-name> -n <agent> -c <worktree-path>
     ```
   - 2番目以降:
     ```
     tmux new-window -t <session-name> -n <agent> -c <worktree-path>
     ```

3. **ワーカーロールファイルを書き込む**（`prefix+s` popup 用）:
   ```
   PANE_NUM=$(tmux display-message -p -t "<session-name>:<agent>" "#{pane_id}" | tr -d '%')
   mkdir -p /tmp/claude-pane-state
   echo "<agent>" > /tmp/claude-pane-state/pane_${PANE_NUM}_role
   ```

#### 3-3: Claude Code を起動してプロンプトを送信する

各エージェントウィンドウで:

1. Claude Code を起動する:
   ```
   tmux send-keys -t <session-name>:<agent> "claude" Enter
   ```
   起動完了まで 3 秒待機する。

2. プロンプトをウィンドウに送信する:

**最初のエージェント（planner / architect / security-reviewer）向け:**
```
tmux send-keys -t <session-name>:<agent> "あなたは <agent> エージェントです。以下のタスクを担当してください。\n\nタスク: <task-description>\n\n作業完了後、次のエージェント（<next-agent>）向けのハンドオフ文書を以下のパスに作成してください:\n<repo-root>/.orchestrate/<session-name>/HANDOFF-<agent>-to-<next-agent>.md\n\nハンドオフ文書の形式:\n# HANDOFF: <agent> → <next-agent>\n## 完了した作業\n## 次のエージェントへの具体的な指示\n## 重要なファイルパス" Enter
```

**2番目以降のエージェント向け（最後のエージェント以外）:**
```
あなたは <agent> エージェントです。

前のエージェント（<prev-agent>）のハンドオフ文書が届いたら作業を開始してください:
<repo-root>/.orchestrate/<session-name>/HANDOFF-<prev-agent>-to-<agent>.md

ファイルがまだ存在しない場合は、Read ツールで定期的に確認しながら待機してください（最大30分）。

作業完了後、次のエージェント（<next-agent>）向けのハンドオフ文書を作成してください:
<repo-root>/.orchestrate/<session-name>/HANDOFF-<agent>-to-<next-agent>.md
```

- `<agent>` が `tdd-guide` / `code-reviewer` / `security-reviewer` の場合は、プロンプト末尾に以下を追記する:
```
作業対象を独立したコンポーネント・ファイル単位に分割できる場合は、Agent ツールでサブエージェントを起動して並列実装してください。依存関係のある部分は逐次処理してください。
```

**最後のエージェント向け:**
```
あなたは <agent> エージェントです。

前のエージェント（<prev-agent>）のハンドオフ文書が届いたら作業を開始してください:
<repo-root>/.orchestrate/<session-name>/HANDOFF-<prev-agent>-to-<agent>.md

ファイルがまだ存在しない場合は、定期的に確認しながら待機してください。

作業完了後、最終レポートを以下のパスに作成してください:
<repo-root>/.orchestrate/<session-name>/FINAL-REPORT.md
```

- `<agent>` が `tdd-guide` / `code-reviewer` / `security-reviewer` の場合は、プロンプト末尾に以下を追記する:
```
作業対象を独立したコンポーネント・ファイル単位に分割できる場合は、Agent ツールでサブエージェントを起動して並列実装してください。依存関係のある部分は逐次処理してください。
```

### Step 4: 起動確認と案内

全ワーカー起動後、以下を表示する:

```
オーケストレーション開始: <session-name>
ワークフロー: <workflow-type>
タスク: <task-description>

ワーカー:
  0: planner      → .orchestrate/<session-name>/planner/
  1: tdd-guide    → .orchestrate/<session-name>/tdd-guide/
  ...

確認方法:
  prefix+s        : tmux セッション一覧でワーカー状態を確認
  claude-sessions-status.sh <session-name>  : 詳細状態を表示
  tmux attach -t <session-name>             : セッションに接続
```

### Step 5: cleanup サブコマンド

`/orchestrate cleanup <session-name>` が指定された場合:

1. tmux セッションを削除する: `tmux kill-session -t <session-name>`
2. git worktree をすべて削除する:
   - `git worktree list` で `orch/<session-name>/` を含む worktree を特定する
   - 各 worktree を `git worktree remove --force <path>` で削除する
3. orch ブランチを削除する:
   - `git branch -D orch/<session-name>/<agent>` を各エージェント分実行する
4. ハンドオフ文書ディレクトリを削除する: `rm -r <repo-root>/.orchestrate/<session-name>`
5. role ファイルを削除する: `rm -f /tmp/claude-pane-state/pane_*_role` （該当セッション分のみ）

## エージェント役割一覧

| エージェント | 役割 |
|-------------|------|
| `planner` | タスク分析・実装計画の策定 |
| `tdd-guide` | TDD アプローチでのテスト設計と実装 |
| `code-reviewer` | コードレビューと改善提案 |
| `security-reviewer` | セキュリティ観点でのレビューと脆弱性検査 |
| `architect` | アーキテクチャ設計とリファクタリング計画 |

## 制約

- tmux セッション内でのみ動作する
- git リポジトリ内でのみ動作する
- ファイル削除には `rm` を使用する（`rm -rf` は禁止）
- `.orchestrate/` ディレクトリは `.gitignore` に追加する
