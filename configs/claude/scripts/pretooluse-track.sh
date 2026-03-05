#!/bin/bash
# PreToolUse hook: permission.log 向けに tool_name を一時ファイルへ記録
# 全ツール対象（matcher なし）で発火し、session_id ごとに保持する

read -r input
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$input" | jq -r '.tool_name // "unknown"')

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

echo "$TOOL_NAME" > "$LOG_DIR/last-tool-${SESSION_ID}"
