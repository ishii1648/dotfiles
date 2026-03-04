#!/bin/bash
# Claude Code Hook: permission UI 表示回数をログ記録
# Notification: permission_prompt イベントで発火

read -r input
SESSION_ID=$(echo "$input" | jq -r '.session_id // ""')
TOOL_NAME=$(echo "$input" | jq -r '.tool_name // "unknown"')

# session_id が取れない場合は環境変数でフォールバック
[ -z "$SESSION_ID" ] && SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) session=${SESSION_ID} tool=${TOOL_NAME}" \
  >> "$LOG_DIR/permission.log"
