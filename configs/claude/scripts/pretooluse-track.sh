#!/bin/bash
# PreToolUse hook: permission.log 向けに tool_name を一時ファイルへ記録
# 全ツール対象（matcher なし）で発火し、session_id ごとに保持する

read -r input
SESSION_ID=$(echo "$input" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$input" | jq -r '.tool_name // "unknown"')

# ツールごとにコンテキスト情報を付記
# Bash: Bash(cmd(internal|external))  例: Bash(cp(external))
# Read/Write/Edit/Grep: Tool(internal|external)  例: Read(external)
case "$TOOL_NAME" in
  Bash)
    CMD=$(echo "$input" | jq -r '.tool_input.command // ""' | awk '{print $1}')
    FP=$(echo "$input" | jq -r '.tool_input.command // ""' | awk '{print $2}')
    if [ -n "$FP" ] && [ -n "$PWD" ] && case "$FP" in "$PWD"/*) true;; *) false;; esac; then
      LOC="internal"
    else
      LOC="external"
    fi
    DETAIL="${CMD}(${LOC})"
    ;;
  Read|Write|Edit|Grep)
    FP=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""')
    if [ -n "$FP" ] && [ -n "$PWD" ] && case "$FP" in "$PWD"/*) true;; *) false;; esac; then
      DETAIL="internal"
    else
      DETAIL="external"
    fi
    ;;
  *) DETAIL="" ;;
esac
[ -n "$DETAIL" ] && TOOL_NAME="$TOOL_NAME($DETAIL)"

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

echo "$TOOL_NAME" > "$LOG_DIR/last-tool-${SESSION_ID}"
