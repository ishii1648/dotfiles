---
name: orchestrate
description: タスク記述（または issue 番号・GitHub issue URL・TODO.md）を受け取り、meta planner が計画を立ててから単一 worktree で実行する。parent が worktree を事前作成し、planning Claude が計画→実行を担当する。「/orchestrate "タスク記述"」「/orchestrate --issue 53」「/orchestrate --from-todo TODO.md」「/orchestrate --dry-run "タスク"」「/orchestrate cleanup <session>」で起動。
argument-hint: '"<タスク記述>" | --issue <番号> | <GitHub-issue-URL> | <owner/repo>#<number> | --repo <owner/repo> | --from-todo [path] | --dry-run "<タスク記述>" | cleanup <session>'
version: 2.0.0
---

# orchestrate

タスク記述または issue 番号を受け取り、meta planner が計画を立ててから単一 worktree で実行する。parent が worktree・tmux セッションを事前作成し、planning Claude が計画策定→実装を一貫して担当する。

単一ブランチで完結する小規模作業には `/dispatch`（軽量版・planning なし）を使用する。

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

- `<タスク記述>`: 実行したいタスクの自然言語説明
- `--issue <番号>`: `docs/issues.md` の ADR 番号を参照してタスクを起動（例: `--issue 53`）
- `<GitHub-issue-URL>`: `https://github.com/<owner>/<repo>/issues/<number>` 形式。issue title + body をタスク記述として使用し、owner/repo を自動設定する
- `<owner/repo>#<number>`: GitHub issue の shorthand 形式（例: `ishii1648/tmux-sidebar#2`）
- `--repo <owner/repo>`: 作業リポジトリを明示指定する。`ghq` のローカルパスを使用（例: `--repo ishii1648/tmux-sidebar`）
- `--from-todo [path]`: TODO.md を読み込み、未完了タスクを一括でタスク記述として使用する（旧 spawn 相当）。path 省略時は `./TODO.md`
- `--dry-run`: 実行計画を表示するが実際の起動は行わない
- `cleanup <session-name|session-id>`: 指定セッションのリソースをすべて削除

## ステップ

### Step 1: 引数の解析と事前チェック

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
6. tmux セッション外かチェック:
   - **Bash ツール**で `tmux display-message -p '#{session_name}'` を実行し、出力が空なら「tmux セッション外では動作しません」と表示して終了
7. リポジトリルートを決定する:
   - `--repo <owner/repo>` が指定された場合:
     - **Bash ツール**で `ghq list -p <owner/repo>` でローカルパスを検索する
     - 見つかればそのパスを `repo-root` として使用する
     - 見つからない場合は「ローカルに `<owner/repo>` が見つかりません。`ghq get <owner/repo>` で取得してください」と表示して終了する
   - 指定なしの場合: **Bash ツール**で `git rev-parse --show-toplevel` を実行し、空なら「git リポジトリ外では動作しません」と表示して終了
8. session-name を決定する（tmux セッション名として使用）:
   - `--repo <owner/repo>` が指定されている場合: session-name = `<owner>/<repo>`（例: `ishii1648/tmux-sidebar`）
   - 指定なしの場合: **Bash ツール**で `git remote get-url origin` から `owner/repo` を抽出して session-name とする。取得できない場合はリポジトリのディレクトリ名を使用する。
   - 同名セッションの存在チェックは **Bash ツール**で `tmux has-session -t <session-name>` を**単独呼び出し**で実行する。ツール呼び出しがエラーなしで成功した（= セッションが存在する）場合は `-2`、`-3` と数字サフィックスを付加して再チェックする（`&&`/`||`/`;` での連結は禁止、1コマンド1呼び出しで繰り返す）
9. session-slug を生成する: session-name の `/` を `-` に置換したファイルシステム安全な識別子（例: `ishii1648-tmux-sidebar`）
   - 計画 YAML の出力先: `<repo-root>/.outputs/claude/orchestrate-plan-<session-slug>.yaml`
   - `.outputs/claude/` ディレクトリが存在しない場合は **Write ツール**で `.outputs/claude/.gitkeep` を作成して対応する
10. session-id を生成する: `<session-slug>-YYYYMMDD-HHMMSS`（**Bash ツール**で `date +%Y%m%d-%H%M%S` で取得）
    - **表示名（session-name）とは別の不変識別子**。後続のマニフェストパス・ブランチプレフィックス・worktree パスはすべて session-id でスコープする
    - マニフェストパス: `~/.orchestrate/<session-id>/manifest.json`
11. **マニフェストを初期書き込みする（すべての副作用より前）**:
    - `~/.orchestrate/<session-id>/manifest.json` を Write ツールで作成する
    - worktree 名は `work` 固定
    - worktree パス: `<repo-root>@orchestrate-<session-id>-work`
    - ブランチ名: `orchestrate/<session-id>/work`
    ```json
    {
      "session_id": "<session-id>",
      "session_name": "<session-name>",
      "session_slug": "<session-slug>",
      "repo_root": "<repo-root>",
      "created_at": "<ISO8601-timestamp>",
      "creation_state": "partial",
      "worktree": {
        "name": "work",
        "path": "<repo-root>@orchestrate-<session-id>-work",
        "branch": "orchestrate/<session-id>/work",
        "created": false
      },
      "tmux_session": "<session-name>",
      "tmux_created": false
    }
    ```
    - この時点ではまだ tmux も worktree も存在しない（`partial`）
    - クラッシュしても `~/.orchestrate/` を走査すれば session-id でこのセッションを発見できる
12. **worktree を作成する**:
    - **Bash ツール**で git worktree を作成する:
      ```
      git -C <repo-root> worktree add <repo-root>@orchestrate-<session-id>-work -b orchestrate/<session-id>/work
      ```
    - **Read ツール**でマニフェストを読み込み、`worktree.created` を `true` に更新して **Write ツール**で書き込む

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
   - 完了済み（`- [x]`）は対象外
4. 未完了タスクが 0 件の場合は「未完了タスクがありません」と表示して終了
5. 抽出したタスク一覧を以下の形式でタスク記述として構成する:
   ```
   TODO.md の以下の未完了タスクを実行してください:

   1. <タスク1の記述>
   2. <タスク2の記述>
   ...

   各タスクをサブタスクとして順番に実装してください。
   ```

### Step 2: worktree 内で tmux session を作成し planning Claude を起動（dry-run 以外）

`--dry-run` の場合はこのステップをスキップして Step 3 へ進む。

worktree パス: `<repo-root>@orchestrate-<session-id>-work`（Step 1-12 で作成済み）

1. **計画プロンプトファイルを書き込む**: Write ツールで `<repo-root>/.outputs/claude/orchestrate-task-<session-slug>.md` に以下の内容を書き込む（`<session-id>` 等は実際の値に展開してから書き込む）:

   ````markdown
   # orchestrate: 計画 → 実行

   以下のタスクを分析し、計画を立ててからこの worktree 内で実装してください。

   ## コンテキスト

   - session-id: <session-id>
   - session-name: <session-name>
   - repo-root: <repo-root>
   - worktree-path: <repo-root>@orchestrate-<session-id>-work
   - branch: orchestrate/<session-id>/work
   - plan-yaml-path: <plan-yaml-path>
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

2. **tmux セッションを作成する**（現在のウィンドウサイズを継承してサイドバー幅を正しく維持する）:
   **Bash ツール**でウィンドウサイズを取得する（各1呼び出し）:
   ```
   tmux display-message -p '#{window_width}'
   tmux display-message -p '#{window_height}'
   ```
   取得した値（`<W>` × `<H>`）を使って **Bash ツール**でセッションを作成する（worktree ディレクトリで起動）:
   ```
   tmux new-session -d -s <session-name> -n work -c <repo-root>@orchestrate-<session-id>-work -x <W> -y <H>
   ```

3. **ペイン role ファイルと pending context を書き込む**:
   **Bash ツール**で tmux ウィンドウのペイン role とペンディングコンテキストを設定する:
   ```
   dispatch-new-worker-window <session-name> work <repo-root>@orchestrate-<session-id>-work <session-id> <repo-root>
   ```
   ※ `dispatch-new-worker-window` が `tmux new-window` を内部で呼ぶが、既にウィンドウ `work` が存在する場合はペイン設定のみ行う。セッション作成時に `-n work` で作成済みのため、このスクリプトの挙動を確認し、必要に応じて tmux ウィンドウ作成をスキップする方法を使用する。
   **代替手順**（`dispatch-new-worker-window` が新規ウィンドウ前提の場合）:
   - **Bash ツール**でペインIDを取得: `tmux display-message -t <session-name>:work -p '#{pane_id}'`
   - **Write ツール**で role ファイルを書き込む（dispatch と同じ形式）

4. **Write ツール**でマニフェストの `tmux_created` を `true` に更新する

5. **work ウィンドウで Claude を起動し、計画プロンプトを送信する**:
   **Bash ツール**で Claude Code を起動する:
   ```
   tmux send-keys -t <session-name>:work "claude" Enter
   ```
   **Bash ツール**で 3 秒待機してから:
   ```
   sleep 3
   ```
   **Bash ツール**でプロンプトを送信する:
   ```
   tmux send-keys -t <session-name>:work "<repo-root>/.outputs/claude/orchestrate-task-<session-slug>.md を読んで指示通りに実行してください" Enter
   ```

6. ユーザに以下を表示して、**このセッションの処理を終了する**:
   ```
   session 作成: <session-name>  [session-id: <session-id>]
   worktree: <repo-root>@orchestrate-<session-id>-work
   計画→実行中...  (tmux attach -t <session-name> で確認できます)
   クリーンアップ: /orchestrate cleanup <session-id>  (または <session-name>)
   ```

   **元セッションの orchestrate skill はここで終了する。** worktree・tmux session の作成が完了した状態であり、その後の計画策定・実装はすべて work ウィンドウの Claude が担当する。

### Step 3: 計画 YAML の生成と表示（dry-run 専用）

`--dry-run` の場合のみ実行する。

1. 自身でタスクを分析して計画 YAML を生成し、`<plan-yaml-path>` に書き込む（tmux セッション・worktree は作成しない）。
2. `<plan-yaml-path>` を Read して以下の形式で **現在のターミナル** に全文表示する:

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

**Step 4-1: マニフェストの読み込みと検証（fail-closed・呼び出し元リポジトリに依存しない）**
- 引数が `session-id` 形式（`<slug>-YYYYMMDD-HHMMSS` パターン）の場合: **Read ツール**で `~/.orchestrate/<session-id>/manifest.json` を直接読む（最も確実な指定方法）
- 引数が `session-name` 形式の場合: `~/.orchestrate/` 以下を走査して `session_name` フィールドが一致するマニフェストを探す
  - **Bash ツール**で `ls ~/.orchestrate/` でサブディレクトリを列挙し、**Read ツール**で各 `manifest.json` の `session_name` フィールドを確認する
  - 一致するものを対象マニフェストとする
- マニフェストが見つからない場合は「マニフェストが見つかりません」と表示して**中断する**
- 複数見つかった場合は `session_id`・`created_at`・`creation_state`・`task_summary` を一覧表示してユーザに選択させる
- マニフェストから `repo_root` と `session_id` を取得する（呼び出し元の CWD は使用しない）
- 以下の検証をすべて通過しない場合は「マニフェスト検証失敗: <理由>」と表示して**中断する**:
  1. `worktree.path` が `<manifest.repo_root>@orchestrate-<session_id>-` プレフィックスを持つこと
  2. `worktree.branch` が `orchestrate/<session_id>/` プレフィックスを持つこと
  3. `tmux_session` が `<session-name>` と一致すること

**Step 4-2: 実際の状態との reconciliation（クラッシュ時に manifest 未更新のリソースを回収）**
- **Bash ツール**で `git -C <manifest.repo_root> worktree list --porcelain` を実行し、`<manifest.repo_root>@orchestrate-<session_id>-` プレフィックスを持つ worktree を確認する
- **Bash ツール**で `git -C <manifest.repo_root> branch --list "orchestrate/<session_id>/*"` を実行し、セッションに属するブランチを確認する
- manifest の `worktree` と照合し、`<session_id>` スコープに属するリソースをすべて削除対象とする

**Step 4-3: リソースの削除**
1. **Bash ツール**で tmux セッションを削除する（`tmux_created: true` の場合のみ）: `tmux kill-session -t <tmux_session>`
2. **Bash ツール**で worktree を削除する:
   - `git -C <manifest.repo_root> worktree remove --force <worktree.path>`
3. **Bash ツール**でブランチを削除する:
   - `git -C <manifest.repo_root> branch -D <worktree.branch>`
4. **Bash ツール**で worktree ディレクトリが残っていれば削除する:
   - `rm <worktree.path>`（`rm -rf` は禁止。worktree remove 後は空ディレクトリのみ残る）
5. **Bash ツール**でマニフェストディレクトリを削除する: `rm -r ~/.orchestrate/<session_id>`
6. **Bash ツール**で計画 YAML を削除する: `rm <manifest.repo_root>/.outputs/claude/orchestrate-plan-<session-slug>.yaml`
7. **Bash ツール**で role ファイルを削除する（該当セッションのペイン分のみ）

## 制約

- tmux セッション内でのみ動作する
- git リポジトリ内でのみ動作する
- ファイル削除には `rm` を使用する（`rm -rf` は禁止）
- worktree パスは `gw_add` と同じ `<repo-root>@<branch-slug>` 形式（ブランチ名の `/` を `-` に置換）
- ネットワーク通信を伴うコマンドは使用しない（aws, curl, terraform 等）
