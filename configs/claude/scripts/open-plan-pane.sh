#!/bin/bash
# PostToolUse hook (Write): plan ファイルが書き込まれたら tmux pane で開く

LOG="/tmp/open-plan-pane.log"
echo "[$(date)] hook started" >> "$LOG"
echo "[$(date)] TMUX=$TMUX" >> "$LOG"

# tmux 内でなければスキップ
if [[ -z "$TMUX" ]]; then
    echo "[$(date)] EXIT: not in tmux" >> "$LOG"
    exit 0
fi

# stdin から JSON を読み取り
INPUT=$(cat)
echo "[$(date)] INPUT=$INPUT" >> "$LOG"

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
PLAN_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

echo "[$(date)] CWD=$CWD" >> "$LOG"
echo "[$(date)] PLAN_FILE=$PLAN_FILE" >> "$LOG"

if [[ -z "$CWD" || -z "$PLAN_FILE" ]]; then
    echo "[$(date)] EXIT: CWD or PLAN_FILE is empty" >> "$LOG"
    exit 0
fi

# plan ディレクトリへの書き込みでなければスキップ
PLANS_DIR=".outputs/claude/plan"
if [[ "$PLAN_FILE" != *"$PLANS_DIR"* ]]; then
    echo "[$(date)] EXIT: not a plan file ($PLAN_FILE)" >> "$LOG"
    exit 0
fi

PANE_TITLE="claude-plan"

# 現在の pane ID を記録（フォーカスを戻すため）
ORIGINAL_PANE=$(tmux display-message -p '#{pane_id}')

# 既存の plan pane があれば閉じる
EXISTING_PANE=$(tmux list-panes -F '#{pane_id} #{pane_title}' \
    | grep "$PANE_TITLE" \
    | awk '{print $1}')

if [[ -n "$EXISTING_PANE" ]]; then
    tmux kill-pane -t "$EXISTING_PANE" 2>/dev/null
fi

# 右側に 50% 幅で split して nvim を起動（プロジェクトディレクトリから）
echo "[$(date)] running: tmux split-window -h -l 50% -c $CWD nvim $PLAN_FILE" >> "$LOG"
tmux split-window -h -l 50% -c "$CWD" "nvim '$PLAN_FILE'"
echo "[$(date)] split-window exit=$?" >> "$LOG"

# pane タイトルを設定（次回の特定用）
tmux select-pane -T "$PANE_TITLE"

# 元の pane（Claude Code）にフォーカスを戻す
tmux select-pane -t "$ORIGINAL_PANE"

exit 0
