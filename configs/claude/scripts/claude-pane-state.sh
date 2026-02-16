#!/bin/bash
# Claude Code Hook: ペインごとのランタイム状態をファイルに書き出す
# 使い方: claude-pane-state.sh <state>
#   state: running | permission | ask | idle | end

# stdin を消費（hook がパイプで渡す JSON を読み捨てる）
cat > /dev/null

# tmux 外では何もしない
[ -z "$TMUX_PANE" ] && exit 0

STATE_DIR="/tmp/claude-pane-state"
PANE_FILE="$STATE_DIR/pane_${TMUX_PANE#%}"
STATE="${1:-unknown}"

if [ "$STATE" = "end" ]; then
    rm -f "$PANE_FILE"
    exit 0
fi

mkdir -p "$STATE_DIR"
echo "$STATE" > "$PANE_FILE"
