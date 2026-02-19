---
name: tmux-send-prompt
description: >-
  This skill should be used when the user wants to send a prompt or instruction to another tmux pane or session,
  such as "tmuxの別セッションにプロンプトを送りたい", "対向のClaudeに指示したい", "別のpaneにコマンドを送って",
  "tmuxペインに指示を転送して". This skill lists available panes, lets the user select a target,
  verifies the target is idle using a state file and child-process check, then safely sends the prompt using send-keys.
version: 1.0.0
allowed-tools: Bash, AskUserQuestion
argument-hint: "\"<prompt>\""
---

# tmux-send-prompt - 安全なプロンプト送信

## 概要

対象 tmux pane の idle 状態を確認してからプロンプトを送信するスキル。
`/tmp/claude-pane-state/` のstateファイルと子プロセスの有無（`pgrep -P`）を二重チェックし、処理中のセッションへの誤送信を防ぐ。

> **Note**: `#{pane_idle}` / `#{pane_activity}` は `monitor-activity` が無効な環境では値が取得できないため、代わりに `pgrep -P <pane_pid>` で子プロセスの有無を確認する。

## ワークフロー

### Step 1: 送信プロンプトの確認

引数としてプロンプトが渡されている場合はそのまま使用する。
渡されていない場合は AskUserQuestion でプロンプトを入力してもらう。

プロンプトが200文字を超える場合は警告を表示するが送信は続行する。

### Step 2: 利用可能な pane 一覧を取得

自身の pane を除外しながら全 pane の情報を収集する：

```bash
# 自身の pane ID を取得（自己送信防止のため除外対象として使用）
MY_PANE=$(tmux display-message -p '#{pane_id}')

# 全 pane 一覧を取得（pane_id・対象アドレス・PID・コマンド）
# ※ #{pane_idle} / #{pane_activity} は monitor-activity が無効な環境で取得不可のため使わない
tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{pane_pid} #{pane_current_command}' \
  | grep -v "^${MY_PANE} "
```

### Step 3: AskUserQuestion で送信先を選択

取得した pane 一覧を選択肢として AskUserQuestion を呼び出す。

**選択肢フォーマット例:**
```
main:0.0  bash   [no children → idle]
main:1.0  claude  [state: idle]
work:0.0  node   [has children → busy?]
```

stateファイルが存在する場合は state 情報も付加する：

```bash
for pane_id in $PANE_IDS; do
  PANE_NUM=$(echo $pane_id | tr -d '%')
  STATE=$(cat /tmp/claude-pane-state/pane_${PANE_NUM} 2>/dev/null || echo "unknown")
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
| `"<prompt>"` | 送信するプロンプトテキスト（省略時はStep 1で入力） |

## 使用例

```bash
# プロンプトを引数で指定
/tmux-send-prompt "テストを実行して結果を報告してください"

# 引数なしで実行（スキル内で入力を求める）
/tmux-send-prompt
```

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| tmux セッションが存在しない | "利用可能なpaneがありません" でabort |
| state が running / ask / permission | 状態を表示してabort（リトライは手動） |
| stateファイルなし + 子プロセスあり | "子プロセスが動作中の可能性あり" でabort |
| プロンプトが200文字超 | 警告を表示して続行 |
| send-keys 失敗 | エラーメッセージを表示 |
