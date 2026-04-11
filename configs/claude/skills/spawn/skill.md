---
name: spawn
description: TODO.md のタスクを解析して並列実行可能なものを tmux ウィンドウに分散して Claude セッションを起動する
argument-hint: "[TODO.md] | cleanup <session-name>"
version: 0.1.0
---

# spawn

TODO.md のタスクを並列グループに分割し、各グループを tmux ウィンドウに割り当てて Claude セッションを起動する。`orchestrate` と異なりワークフロータイプ・ハンドオフ文書・worktree は持たず、タスクファイル一枚から即起動できる。

## 引数フォーマット

```
/spawn [TODO.md-path]
/spawn cleanup <session-name>
```

- `TODO.md-path`: 解析するファイルパス（省略時は `./TODO.md`）
- `cleanup <session-name>`: 指定セッションの tmux セッションを削除

## ステップ

### Step 1: 引数の解析と事前チェック

1. 第1引数でサブコマンドを判定する
   - `cleanup` の場合は Step 5 へジャンプ
2. TODO.md パスを取得する（省略時は `./TODO.md`）
3. ファイルの存在チェック: 存在しない場合は「TODO.md が見つかりません: <path>」と表示して終了
4. tmux セッション外かチェック（`orchestrate` Step 1 と同じ）:
   - `tmux display-message -p '#{session_name}' 2>/dev/null` が空なら「tmux セッション外では動作しません」と表示して終了

### Step 2: タスクの解析と並列グループの特定

1. TODO.md を Read して未完了タスク（`- [ ]` 行）を抽出する
   - 完了済み（`- [x]`）は対象外
2. 各タスクの依存関係を分析して**並列グループ**を特定する:
   - 他のタスクに依存しないタスク → 独立グループ（1ウィンドウ = 1タスク）
   - 依存関係があるタスク群 → 同一グループにまとめて1ウィンドウで逐次実行
   - グループ数が 6 を超える場合は関連するものをまとめてグループ数を絞る
3. 分析結果をユーザーに提示する（AskUserQuestion）:
   ```
   以下の並列グループで起動します:
     グループ0 (並列): <タスク概要>
     グループ1 (並列): <タスク概要>
     グループ2 (逐次): <タスク概要A> → <タスク概要B>
   続行しますか？
   ```

### Step 3: セッションと tmux ウィンドウの作成

`orchestrate` の Step 2・Step 3-2 と同じパターンを使用する。

1. タイムスタンプ付きセッション名を生成する:
   - 形式: `spawn-YYYYMMDD-HHMMSS`
   - Bash: `date '+spawn-%Y%m%d-%H%M%S'`
2. グループラベルを決定する（タスク内容から短い英単語、例: `auth`, `payment`, `docs`）
3. 各グループについて tmux ウィンドウを作成する:
   - 最初のグループ:
     ```
     tmux new-session -d -s <session-name> -n <group-label> -c <cwd>
     ```
   - 2番目以降:
     ```
     tmux new-window -t <session-name> -n <group-label> -c <cwd>
     ```
4. ワーカーロールファイルを書き込む（`orchestrate` の pane_role と同じ）:
   ```
   PANE_NUM=$(tmux display-message -p -t "<session-name>:<group-label>" "#{pane_id}" | tr -d '%')
   mkdir -p /tmp/claude-pane-state
   echo "<group-label>" > /tmp/claude-pane-state/pane_${PANE_NUM}_role
   ```

### Step 4: Claude の起動とプロンプト送信

`orchestrate` の Step 3-3 と同じパターンを使用する。

1. 各ウィンドウで Claude Code を起動する:
   ```
   tmux send-keys -t <session-name>:<group-label> "claude" Enter
   ```
   起動完了まで 3 秒待機する。

2. タスクプロンプトを送信する:

**独立タスク（グループに1タスク）:**
```
以下のタスクを実行してください:

<task-description>
```

**逐次タスク（グループに複数タスク）:**
```
以下のタスクを上から順に実行してください:

1. <task-description-A>
2. <task-description-B>
...

各タスクが完了したら次に進んでください。
```

3. 全ウィンドウ起動後、以下を表示する:
   ```
   spawn 開始: <session-name>
   タスクファイル: <TODO.md-path>

   ウィンドウ:
     0: <group-label>  - <task-summary>
     1: <group-label>  - <task-summary>
     ...

   確認方法:
     prefix+s                       : ウィンドウ一覧でワーカー状態を確認
     tmux attach -t <session-name>  : セッションに接続
   ```

### Step 5: cleanup サブコマンド

`/spawn cleanup <session-name>` が指定された場合（`orchestrate` Step 5 と同じパターン）:

1. tmux セッションを削除する: `tmux kill-session -t <session-name>`
2. role ファイルを削除する（該当セッションのペイン分のみ）:
   - セッション内のペイン ID を取得してから `rm -f /tmp/claude-pane-state/pane_<ID>_role` を実行する
