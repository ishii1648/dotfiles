#!/bin/bash
# PostToolUse hook (ExitPlanMode): 最新の plan ファイルを tmux pane で開く

# tmux 内でなければスキップ
if [[ -z "$TMUX" ]]; then
    exit 0
fi

# stdin から JSON を読み取り、cwd を取得
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

if [[ -z "$CWD" ]]; then
    exit 0
fi

PLANS_DIR="$CWD/.outputs/claude/plan"
PANE_TITLE="claude-plan"

# plans ディレクトリが存在しなければスキップ
if [[ ! -d "$PLANS_DIR" ]]; then
    exit 0
fi

# 最新の .md ファイルを取得
PLAN_FILE=$(find "$PLANS_DIR" -maxdepth 1 -name '*.md' -type f -print0 \
    | xargs -0 ls -t 2>/dev/null \
    | head -1)

if [[ -z "$PLAN_FILE" ]]; then
    exit 0
fi

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
tmux split-window -h -l 50% -c "$CWD" "nvim '$PLAN_FILE'"

# pane タイトルを設定（次回の特定用）
tmux select-pane -T "$PANE_TITLE"

# 元の pane（Claude Code）にフォーカスを戻す
tmux select-pane -t "$ORIGINAL_PANE"

exit 0
