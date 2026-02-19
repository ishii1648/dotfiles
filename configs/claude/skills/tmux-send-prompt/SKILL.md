---
name: tmux-send-prompt
description: >-
  This skill should be used when the user wants to send a prompt or instruction to another tmux pane or session,
  such as "tmuxの別セッションにプロンプトを送りたい", "対向のClaudeに指示したい", "別のpaneにコマンドを送って",
  "tmuxペインに指示を転送して". This skill lists available panes, lets the user select a target,
  verifies the target is idle using a state file and pane_idle check, then safely sends the prompt using send-keys.
version: 1.0.0
allowed-tools: Bash, AskUserQuestion
argument-hint: "\"<prompt>\""
---

# tmux-send-prompt - 安全なプロンプト送信

## 概要

対象 tmux pane の idle 状態を確認してからプロンプトを送信するスキル。
`/tmp/claude-pane-state/` のstateファイルと `pane_idle` を二重チェックし、処理中のセッションへの誤送信を防ぐ。

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

# 全 pane 一覧を取得（pane_id・対象アドレス・コマンド・アイドル時間）
tmux list-panes -a -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{pane_current_command} idle:#{pane_idle}s' \
  | grep -v "^${MY_PANE} "
```

### Step 3: AskUserQuestion で送信先を選択

取得した pane 一覧を選択肢として AskUserQuestion を呼び出す。

**選択肢フォーマット例:**
```
main:0.0  bash  (idle: 42s)
main:1.0  claude  (idle: 120s)  [state: idle]
work:0.0  node  (idle: 8s)
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

#### 4b. pane_idle 確認（二重チェック）

```bash
IDLE_SECS=$(tmux display-message -t <selected_target> -p '#{pane_idle}')
```

| pane_idle | 対応 |
|-----------|------|
| 5秒以上 | OK → 送信へ |
| 5秒未満 | abort: "paneが処理中の可能性があります（last activity: ${IDLE_SECS}s ago）。" |

> **閾値の根拠**: Claude Code や shell コマンドがレスポンスを出力し終えた後、カーソルが安定するまでの遅延を考慮して5秒を設定。stateファイルが `idle` でも出力が続いている場合があるため二重チェックとして機能する。用途に応じて変更可能。

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
| pane_idle が 5秒未満 | "処理中の可能性あり" でabort |
| プロンプトが200文字超 | 警告を表示して続行 |
| send-keys 失敗 | エラーメッセージを表示 |
