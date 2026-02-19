---
name: tmux-send-prompt
description: >-
  This skill should be used when the user wants to send a prompt or instruction to another tmux pane or session,
  such as "tmuxの別セッションにプロンプトを送りたい", "対向のClaudeに指示したい", "別のpaneにコマンドを送って",
  "tmuxペインに指示を転送して". This skill lists available panes (claude/codex panes only), lets the user select a target,
  verifies the target is idle using a state file and child-process check, then safely sends the prompt using send-keys.
  Accepts optional partial target (session, session:window, session:window.pane) as argument and resolves missing parts interactively.
version: 1.1.0
allowed-tools: Bash, AskUserQuestion
argument-hint: "[session[:window[.pane]]] \"<prompt>\""
---

# tmux-send-prompt - 安全なプロンプト送信

## 概要

対象 tmux pane の idle 状態を確認してからプロンプトを送信するスキル。
`/tmp/claude-pane-state/` のstateファイルと子プロセスの有無（`pgrep -P`）を二重チェックし、処理中のセッションへの誤送信を防ぐ。

**送信対象**: `claude` / `codex` コマンドが動作している pane のみを対象とする。shell や editor など他のコマンドの pane は除外する。

> **Note**: `#{pane_idle}` / `#{pane_activity}` は `monitor-activity` が無効な環境では値が取得できないため、代わりに `pgrep -P <pane_pid>` で子プロセスの有無を確認する。

## ワークフロー

### Step 1: 引数のパース

引数は `[target] [prompt]` の形式で渡される。`target` は省略可能。

**target のフォーマット:**
- `session` — セッション名のみ
- `session:window` — セッション名 + ウィンドウインデックス
- `session:window.pane` — 完全指定（tmux 標準アドレス形式）

**パース手順:**

1. 引数全体を受け取る（例: `"main:1 テストを実行して"` や `"テストを実行して"`）
2. 先頭トークンが tmux のターゲット形式（スペースなし、かつ既存セッション名またはコロン/ドットを含む）かどうか判定する
   - 判定方法: `tmux list-sessions -F '#{session_name}'` で取得したセッション名一覧と照合する
   - 先頭トークンがセッション名に前方一致すれば target として扱う
3. target として認識した場合は target と残りの文字列（prompt）に分割する
4. target として認識しない場合は引数全体を prompt として扱う

**パース結果の変数:**
```
TARGET_SESSION=""   # 抽出されたセッション名（空の場合は未指定）
TARGET_WINDOW=""    # 抽出されたウィンドウ番号（空の場合は未指定）
TARGET_PANE=""      # 抽出されたペイン番号（空の場合は未指定）
PROMPT=""           # 送信プロンプト（空の場合は後でAskUserQuestion）
```

プロンプトが空の場合は AskUserQuestion で入力してもらう。
プロンプトが200文字を超える場合は警告を表示するが送信は続行する。

### Step 2: 利用可能な pane 一覧を取得（claude/codex のみ）

自身の pane を除外し、`claude` / `codex` コマンドが動作している pane のみを収集する：

```bash
# 自身の pane ID を取得（自己送信防止のため除外対象として使用）
MY_PANE=$(tmux display-message -p '#{pane_id}')

# 全 pane 一覧を取得し、自身を除外してから claude/codex のみを抽出
tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{pane_pid} #{pane_current_command}' \
  | grep -v "^${MY_PANE} " \
  | grep -E ' (claude|codex)$'
```

候補が0件の場合は "利用可能なpane（claude/codex）がありません" でabort。

### Step 3: ターゲットの解決

Step 1 のパース結果と Step 2 の候補一覧を使って送信先を決定する。
各ケースで不足情報がある場合のみ AskUserQuestion を呼び出す。

#### ケース A: ターゲット完全指定（session:window.pane）

- Step 2 の候補一覧に一致する pane が存在するか確認する
- 存在すれば Step 4 へ進む
- 存在しなければ "指定されたターゲットが見つかりません" でabort

#### ケース B: セッション + ウィンドウのみ（session:window）

- 候補一覧から `session:window` に前方一致する pane を絞り込む
- 絞り込み結果が1件 → そのまま決定してStep 4へ
- 絞り込み結果が複数件 → AskUserQuestion でペインを選択してもらう
- 絞り込み結果が0件 → "該当するpaneが見つかりません" でabort

#### ケース C: セッション名のみ（session）

- 候補一覧から `session` に前方一致する pane を絞り込む
- 絞り込み結果が1件 → そのまま決定してStep 4へ
- 絞り込み結果が複数件 → AskUserQuestion でウィンドウ+ペインを選択してもらう
- 絞り込み結果が0件 → "該当するpaneが見つかりません" でabort

#### ケース D: ターゲット未指定

- Step 2 の全候補一覧を AskUserQuestion の選択肢として提示する

**選択肢フォーマット例:**
```
main:0.0  bash   [no children → idle]
work:0.0  node   [has children → busy?]
```

stateファイルが存在する場合は state 情報も付加する：

```bash
for pane_id in $PANE_IDS; do
  PANE_NUM=$(echo $pane_id | tr -d '%')
  STATE=$(cat /tmp/claude-pane-state/pane_${PANE_NUM} 2>/dev/null || echo "")
  # 選択肢に state を付加
done
```

### Step 4: 選択された pane の state チェック

#### 4a. stateファイル確認

```bash
PANE_ID=$(tmux display-message -t <selected_target> -p '#{pane_id}')
PANE_NUM=$(echo $PANE_ID | tr -d '%')
STATE=$(cat /tmp/claude-pane-state/pane_${PANE_NUM} 2>/dev/null)
```

| stateの値 | 対応 |
|-----------|------|
| ファイルなし or `idle` | OK → 次のチェックへ |
| `running` | abort: "現在処理中です。完了後に再試行してください。" |
| `ask` | abort: "入力待ち状態です（ask）。手動で操作してください。" |
| `permission` | abort: "権限確認待ち状態です（permission）。手動で操作してください。" |

#### 4b. 子プロセス確認（二重チェック）

`#{pane_idle}` / `#{pane_activity}` は `monitor-activity` が無効な環境では値が取得できないため、`pgrep -P <pane_pid>` で子プロセスの有無を確認する。

```bash
PANE_PID=$(tmux display-message -t <selected_target> -p '#{pane_pid}')
PANE_CMD=$(tmux display-message -t <selected_target> -p '#{pane_current_command}')

# stateファイルがある pane (claude 等) は stateファイルが信頼できるためスキップ
if [ -z "$STATE" ] || [ "$STATE" = "idle" ]; then
  # stateファイルなし（fish/bash 等）の場合のみ子プロセスチェック
  if [ -z "$STATE" ] && pgrep -P "$PANE_PID" > /dev/null 2>&1; then
    abort: "子プロセスが動作中の可能性があります。完了後に再試行してください。"
  fi
fi
```

| 条件 | 対応 |
|------|------|
| stateファイルあり（`idle`） | スキップ → 送信へ（stateファイルが信頼できる） |
| stateファイルなし + 子プロセスなし | OK → 送信へ |
| stateファイルなし + 子プロセスあり | abort: "子プロセスが動作中の可能性があります。" |

### Step 5: send-keys でプロンプト送信

```bash
tmux send-keys -t <selected_target> "<prompt>" Enter
```

### Step 6: 完了報告

```
✓ プロンプトを送信しました
  送信先: <target>
  内容: "<prompt>"
```

## 引数

| 引数 | 説明 |
|------|------|
| `[session[:window[.pane]]]` | 送信先のターゲット（省略可能・部分指定可） |
| `"<prompt>"` | 送信するプロンプトテキスト（省略時はStep 1で入力） |

**target フォーマット例:**
- `main` — セッション `main` の中からpaneをインタラクティブに選択
- `main:1` — セッション `main` のウィンドウ `1` の中からpaneをインタラクティブに選択
- `main:1.0` — セッション `main` のウィンドウ `1` ペイン `0` に直接送信

## 使用例

```bash
# プロンプトのみ指定（送信先をインタラクティブに選択）
/tmux-send-prompt "テストを実行して結果を報告してください"

# セッションのみ指定（ウィンドウ/paneをインタラクティブに選択）
/tmux-send-prompt main "テストを実行して結果を報告してください"

# セッション+ウィンドウ指定（paneをインタラクティブに選択）
/tmux-send-prompt main:1 "テストを実行して結果を報告してください"

# 完全指定（インタラクションなし）
/tmux-send-prompt main:1.0 "テストを実行して結果を報告してください"

# 引数なしで実行（送信先・プロンプト両方をインタラクティブに入力）
/tmux-send-prompt
```

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| claude/codex候補paneが0件 | "利用可能なpane（claude/codex）がありません" でabort |
| 指定ターゲットに一致するpaneなし | "指定されたターゲットが見つかりません" でabort |
| state が running / ask / permission | 状態を表示してabort（リトライは手動） |
| stateファイルなし + 子プロセスあり | "子プロセスが動作中の可能性あり" でabort |
| プロンプトが200文字超 | 警告を表示して続行 |
| send-keys 失敗 | エラーメッセージを表示 |
