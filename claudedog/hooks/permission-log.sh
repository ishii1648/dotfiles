#!/bin/bash
# Claude Code Hook: permission UI 表示回数をログ記録
# PermissionRequest イベントで発火（tool_name・tool_input を直接取得可能）

read -r input
SESSION_ID=$(echo "$input" | jq -r '.session_id // ""')
TOOL_NAME=$(echo "$input" | jq -r '.tool_name // "unknown"')

# session_id が取れない場合は環境変数でフォールバック
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

# Bash の場合はコマンド名と internal/external を付記
case "$TOOL_NAME" in
  Bash)
    CMD=$(echo "$input" | jq -r '.tool_input.command // ""' | awk '{print $1}')
    FP=$(echo "$input" | jq -r '.tool_input.command // ""' | awk '{print $NF}')
    if [ -n "$FP" ] && [ -n "$PWD" ] && case "$FP" in "$PWD"/*) true;; *) false;; esac; then
      LOC="internal"
    else
      LOC="external"
    fi
    TOOL_NAME="Bash(${CMD}(${LOC}))"
    ;;
  Read|Write|Edit|Grep)
    FP=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""')
    if [ -n "$FP" ] && [ -n "$PWD" ] && case "$FP" in "$PWD"/*) true;; *) false;; esac; then
      TOOL_NAME="${TOOL_NAME}(internal)"
    else
      TOOL_NAME="${TOOL_NAME}(external)"
    fi
    ;;
esac

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) session=${SESSION_ID} tool=${TOOL_NAME}" \
  >> "$LOG_DIR/permission.log"
