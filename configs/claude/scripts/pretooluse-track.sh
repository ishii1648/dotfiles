#!/bin/bash
# PreToolUse hook: permission.log 向けに tool_name を一時ファイルへ記録
# 全ツール対象（matcher なし）で発火し、session_id ごとに保持する

read -r input
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$input" | jq -r '.tool_name // "unknown"')

# Bash の場合はコマンドの先頭2語を付記（例: Bash(git push)）
if [ "$TOOL_NAME" = "Bash" ]; then
  BASE_CMD=$(echo "$input" | jq -r '.tool_input.command // ""' | awk '{print $1, $2}' | xargs)
  [ -n "$BASE_CMD" ] && TOOL_NAME="Bash($BASE_CMD)"
fi

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

echo "$TOOL_NAME" > "$LOG_DIR/last-tool-${SESSION_ID}"
