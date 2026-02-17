#!/bin/bash
# Claude Code Hook: ペインごとのランタイム状態をファイルに書き出す
# 使い方: claude-pane-state.sh <state> [source]
#   state:  running | permission | ask | idle | end
#   source: post (PostToolUse 経由の場合のみ指定)

# stdin を消費（hook がパイプで渡す JSON を読み捨てる）
cat > /dev/null

# tmux 外では何もしない
[ -z "$TMUX_PANE" ] && exit 0

STATE_DIR="/tmp/claude-pane-state"
PANE_FILE="$STATE_DIR/pane_${TMUX_PANE#%}"
STATE="${1:-unknown}"
SOURCE="${2:-}"

if [ "$STATE" = "end" ]; then
    rm -f "$PANE_FILE"
    exit 0
fi

# PostToolUse 経由の running 設定時、直近（5秒以内）の高優先度状態を保護
#   - permission/ask: 並列ツール完了による上書きを防止
#   - idle: Stop 直後の PostToolUse による上書きを防止
# UserPromptSubmit 経由（SOURCE 未指定）はガードなしで常に設定
if [ "$STATE" = "running" ] && [ "$SOURCE" = "post" ] && [ -f "$PANE_FILE" ]; then
    current=$(cat "$PANE_FILE")
    if [ "$current" = "permission" ] || [ "$current" = "ask" ] || [ "$current" = "idle" ]; then
        file_mtime=$(stat -f %m "$PANE_FILE" 2>/dev/null || echo 0)
        current_time=$(date +%s)
        age=$((current_time - file_mtime))
        if [ "$age" -lt 5 ]; then
            exit 0
        fi
    fi
fi

mkdir -p "$STATE_DIR"
echo "$STATE" > "$PANE_FILE"
