---
name: dispatch
description: タスク記述（または issue 番号・GitHub issue URL）を受け取り、planning Claude を経由せず 1 worktree + 1 worker Claude を直接起動する軽量エントリポイント。「/dispatch "READMEを修正"」「/dispatch --issue 53」「/dispatch <GitHub-issue-URL>」「/dispatch <owner/repo>#<number>」「/dispatch --repo ishii1648/tmux-sidebar "タスク"」「/dispatch cleanup <session>」で起動。
argument-hint: '"<タスク記述>" | --issue <番号> | <GitHub-issue-URL> | <owner/repo>#<number> | --repo <owner/repo> | cleanup <session>'
version: 1.0.0
---

# dispatch

タスク記述または issue 番号を受け取り、**planning Claude を経由せず** 1 worktree + 1 worker Claude を直接起動する。単一ブランチで完結する作業（README 修正、単機能 fix 等）向けの軽量版。

複数ワーカーが必要な場合や計画フェーズが必要な場合は `/orchestrate` を使用する。

## 引数フォーマット

```
/dispatch "<タスク記述>"
/dispatch --issue <番号>
/dispatch <GitHub-issue-URL>
/dispatch <owner/repo>#<number>
/dispatch --repo <owner/repo> "<タスク記述>"
/dispatch --repo <owner/repo> --issue <番号>
/dispatch cleanup <session-name|session-id>
```

- `<タスク記述>`: 実行したいタスクの自然言語説明
- `--issue <番号>`: `docs/issues.md` の ADR 番号を参照してタスクを起動（例: `--issue 53`）
- `<GitHub-issue-URL>`: `https://github.com/<owner>/<repo>/issues/<number>` 形式。issue title + body をタスク記述として使用し、owner/repo を自動設定する
- `<owner/repo>#<number>`: GitHub issue の shorthand 形式（例: `ishii1648/tmux-sidebar#2`）
- `--repo <owner/repo>`: 作業リポジトリを明示指定する。`ghq` のローカルパスを使用（例: `--repo ishii1648/tmux-sidebar`）
- `cleanup <session-name|session-id>`: 指定セッションのリソースをすべて削除

## ステップ

### Step 1: 引数の解析と事前チェック

1. 第1引数でサブコマンドを判定する
   - `cleanup` の場合は Step 3 へジャンプ
2. `--repo <owner/repo>` フラグを検出してリポジトリ変数に保持する
3. 残り引数から以下を順に検出する:
   a. `https://github.com/` で始まる文字列（GitHub issue URL）→ Step 1-3 へ（URL から owner/repo も自動設定）
   b. `<owner/repo>#<number>` パターン（例: `ishii1648/tmux-sidebar#2`）→ Step 1-3 へ（owner/repo を自動設定）
   c. `--issue <番号>` フラグ → Step 1-2 へ
   d. その他の文字列をタスク記述として使用する
4. tmux セッション外かチェック:
   - **Bash ツール**で `tmux display-message -p '#{session_name}'` を実行し、出力が空なら「tmux セッション外では動作しません」と表示して終了
5. リポジトリルートを決定する:
   - `--repo <owner/repo>` が指定された場合:
     - **Bash ツール**で `ghq list -p <owner/repo>` でローカルパスを検索する
     - 見つかればそのパスを `repo-root` として使用する
     - 見つからない場合は「ローカルに `<owner/repo>` が見つかりません。`ghq get <owner/repo>` で取得してください」と表示して終了する
   - 指定なしの場合: **Bash ツール**で `git rev-parse --show-toplevel` を実行し、空なら「git リポジトリ外では動作しません」と表示して終了
6. session-name を決定する:
   - `--repo <owner/repo>` が指定されている場合: session-name = `<owner>/<repo>`
   - 指定なしの場合: **Bash ツール**で `git remote get-url origin` から `owner/repo` を抽出して session-name とする。取得できない場合はリポジトリのディレクトリ名を使用する
   - 同名セッションの存在チェックは **Bash ツール**で `tmux has-session -t <session-name>` を**単独呼び出し**で実行する。存在する場合は `-2`、`-3` と数字サフィックスを付加して再チェックする（`&&`/`||`/`;` での連結は禁止、1コマンド1呼び出し）
7. session-slug を生成する: session-name の `/` を `-` に置換したファイルシステム安全な識別子
8. session-id を生成する: `<session-slug>-YYYYMMDD-HHMMSS`（**Bash ツール**で `date +%Y%m%d-%H%M%S` で取得）
   - マニフェストパス: `~/.dispatch/<session-id>/manifest.json`
   - `.outputs/claude/` ディレクトリが存在しない場合は **Write ツール**で `.outputs/claude/.gitkeep` を作成して対応する
9. **マニフェストを初期書き込みする（すべての副作用より前）**:
   - `~/.dispatch/<session-id>/manifest.json` を Write ツールで作成する
   ```json
   {
     "session_id": "<session-id>",
     "session_name": "<session-name>",
     "session_slug": "<session-slug>",
     "repo_root": "<repo-root>",
     "created_at": "<ISO8601-timestamp>",
     "creation_state": "partial",
     "worktrees": [
       {
         "name": "main",
         "path": "<repo-root>@dispatch-<session-id>-main",
         "branch": "dispatch/<session-id>/main",
         "created": false
       }
     ],
     "tmux_session": "<session-name>",
     "tmux_created": false
   }
   ```

#### Step 1-2: issue 番号からタスク記述を取得

1. 番号を3桁ゼロ埋めして `docs/issues.md` の `ADR-NNN` セクションを Read して取得する
2. セクションの `**受け入れ条件**` と課題タイトルをタスク記述として使用する
3. 取得できない場合は「issues.md に ADR-NNN セクションが見つかりません」と表示して終了

#### Step 1-3: GitHub issue URL / shorthand からタスク記述を取得

1. URL 形式（`https://github.com/<owner>/<repo>/issues/<number>`）の場合:
   - URL から `<owner>/<repo>` を抽出する
   - `--repo` が未指定であれば自動設定する
   - `gh issue view <URL> --json title,body` で issue 情報を取得する
2. shorthand 形式（`<owner/repo>#<number>`）の場合:
   - `gh issue view <number> --repo <owner/repo> --json title,body` で取得する
   - `--repo` が未指定であれば `owner/repo` を自動設定する
3. issue の title と body を結合してタスク記述として使用する
4. 取得できない場合は「GitHub issue の取得に失敗しました」と表示して終了する

### Step 2: worktree 作成と worker Claude 起動

1. **tmux セッションを作成する**（現在のウィンドウサイズを継承）:
   **Bash ツール**でウィンドウサイズを取得する（各1呼び出し）:
   ```
   tmux display-message -p '#{window_width}'
   tmux display-message -p '#{window_height}'
   ```
   取得した値（`<W>` × `<H>`）を使って **Bash ツール**でセッションを作成する:
   ```
   tmux new-session -d -s <session-name> -n main -c <repo-root> -x <W> -y <H>
   ```
   **Write ツール**でマニフェストの `tmux_created` を `true` に更新する。

2. **git worktree を作成する**（1コマンド1呼び出し）:
   ```
   git -C <repo-root> worktree add <repo-root>@dispatch-<session-id>-main -b dispatch/<session-id>/main
   ```

3. **tmux ウィンドウを worker 用に切り替える**:
   **Bash ツール**で最初のウィンドウの作業ディレクトリを worktree に変更する:
   ```
   tmux send-keys -t <session-name>:main "cd <repo-root>@dispatch-<session-id>-main" Enter
   ```

4. **ワーカーロールファイルを書き込む**:
   ```
   dispatch-new-worker-window <session-name> main <repo-root>@dispatch-<session-id>-main <session-id> <repo-root>
   ```
   ただし既にウィンドウ `main` が存在するため、代わりにロールファイルを直接書き込む:
   **Bash ツール**でペイン ID を取得する:
   ```
   tmux display-message -p -t <session-name>:main '#{pane_id}'
   ```
   出力（例: `%42`）から `%` を除いた数値を `PANE_NUM` とする。
   **Bash ツール**で:
   ```
   mkdir -p /tmp/claude-pane-state
   ```
   **Write ツール**で `/tmp/claude-pane-state/pane_<PANE_NUM>_role` に `main` を書き込む。

5. **ワーカープロンプトファイルを書き込む**:
   **Write ツール**で `<repo-root>/.outputs/claude/dispatch-worker-<session-id>.md` に以下を書き込む:

   ````markdown
   # dispatch worker

   以下のタスクを実行してください。

   ## コンテキスト

   - session-id: <session-id>
   - session-name: <session-name>
   - repo-root: <repo-root>
   - worktree: <repo-root>@dispatch-<session-id>-main
   - branch: dispatch/<session-id>/main

   ## Bash ツール使用の制約

   以下の制約はすべての Bash 呼び出しに適用される（PreToolUse hook が強制）:
   - `&&`/`||`/`;` での複数コマンド連結は**禁止**。各コマンドを個別の Bash 呼び出しに分割すること
   - `$()` コマンド置換は**禁止**。前の Bash 呼び出し結果の出力から値を読み取ること
   - ファイル書き込みには Write ツールを使用すること（`echo >` や `cat >` は禁止）
   - `mkdir` は禁止。Write ツールはディレクトリを自動作成する
   - Bash から `/tmp/` へのリダイレクト（`> /tmp/...`）は禁止（Write ツールは使用可）

   ## タスク

   <タスク記述（全文）>
   ````

6. **worker ウィンドウで Claude を起動してプロンプトを送信する**:
   **Bash ツール**で Claude Code を起動する:
   ```
   tmux send-keys -t <session-name>:main "claude" Enter
   ```
   **Bash ツール**で 3 秒待機する:
   ```
   sleep 3
   ```
   **Bash ツール**でプロンプトを送信する:
   ```
   tmux send-keys -t <session-name>:main "<repo-root>/.outputs/claude/dispatch-worker-<session-id>.md を読んで指示通りに実行してください" Enter
   ```

7. **マニフェストを完了状態に更新する**:
   **Read ツール**でマニフェストを読み込み、`creation_state` を `"complete"`、worktree の `created` を `true` に更新して **Write ツール**で書き込む。

8. **ユーザに表示して終了する**:
   ```
   session 作成: <session-name>  [session-id: <session-id>]
   worktree: <repo-root>@dispatch-<session-id>-main  (branch: dispatch/<session-id>/main)
   クリーンアップ: /dispatch cleanup <session-id>  (または <session-name>)
   ```

### Step 3: cleanup サブコマンド

`/dispatch cleanup <session-name|session-id>` が指定された場合:

**Step 3-1: マニフェストの読み込みと検証（fail-closed・呼び出し元リポジトリに依存しない）**
- 引数が `session-id` 形式（`<slug>-YYYYMMDD-HHMMSS` パターン）の場合: **Read ツール**で `~/.dispatch/<session-id>/manifest.json` を直接読む
- 引数が `session-name` 形式の場合: `~/.dispatch/` 以下を走査して `session_name` フィールドが一致するマニフェストを探す
  - **Bash ツール**で `ls ~/.dispatch/` でサブディレクトリを列挙し、**Read ツール**で各 `manifest.json` の `session_name` フィールドを確認する
  - 一致するものを対象マニフェストとする
- マニフェストが見つからない場合は「マニフェストが見つかりません」と表示して**中断する**
- 複数見つかった場合は `session_id`・`created_at`・`creation_state` を一覧表示してユーザに選択させる
- マニフェストから `repo_root` と `session_id` を取得する（呼び出し元の CWD は使用しない）
- 以下の検証をすべて通過しない場合は「マニフェスト検証失敗: <理由>」と表示して**中断する**:
  1. `worktrees[].path` がすべて `<manifest.repo_root>@dispatch-<session_id>-` プレフィックスを持つこと
  2. `worktrees[].branch` がすべて `dispatch/<session_id>/` プレフィックスを持つこと
  3. `tmux_session` が `<session-name>` と一致すること

**Step 3-2: 実際の状態との reconciliation（クラッシュ時に manifest 未更新のリソースを回収）**
- **Bash ツール**で `git -C <manifest.repo_root> worktree list --porcelain` を実行し、`<manifest.repo_root>@dispatch-<session_id>-` プレフィックスを持つすべての worktree を列挙する
- **Bash ツール**で `git -C <manifest.repo_root> branch --list "dispatch/<session_id>/*"` を実行し、セッションに属するすべてのブランチを列挙する
- これらを manifest の `worktrees[]` と照合し、**manifest の有無に関わらず** `<session_id>` スコープに属するリソースをすべて削除対象とする

**Step 3-3: リソースの削除**
1. **Bash ツール**で tmux セッションを削除する（`tmux_created: true` の場合のみ）: `tmux kill-session -t <tmux_session>`
2. **Bash ツール**で reconciliation で特定したすべての worktree を削除する（各 path を個別呼び出し）:
   - `git -C <manifest.repo_root> worktree remove --force <path>`
3. **Bash ツール**で reconciliation で特定したすべてのブランチを削除する（各 branch を個別呼び出し）:
   - `git -C <manifest.repo_root> branch -D <branch>`
4. **Bash ツール**で各 worktree ディレクトリを個別に削除する（各 path を個別呼び出し）:
   - `rm <path>`（`rm -rf` は禁止。worktree remove 後は空ディレクトリのみ残る）
5. **Bash ツール**でマニフェストファイルを削除する: `rm -r ~/.dispatch/<session_id>`
6. **Bash ツール**で role ファイルを削除する（該当セッションのペイン分のみ）

## 制約

- tmux セッション内でのみ動作する
- git リポジトリ内でのみ動作する
- ファイル削除には `rm` を使用する（`rm -rf` は禁止）
- worktree パスは `<repo-root>@dispatch-<session-id>-main` 形式
- ネットワーク通信を伴うコマンドは使用しない（aws, curl, terraform 等）
- planning Claude は使用しない（1 worktree + 1 worker の直接起動のみ）
