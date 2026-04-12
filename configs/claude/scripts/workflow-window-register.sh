#!/bin/bash
set -euo pipefail

# PostToolUse:Bash hook: detect tmux new-window/new-session and write pending context.
# If an active-skill marker exists for this session and the Bash command creates a new
# tmux window or session, writes ~/.workflow-sessions/pending/<session>-<window>.json
# for the SessionStart hook (Mode C) to pick up.

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$SESSION_ID" || -z "$COMMAND" ]]; then
    exit 0
fi

# Skip dispatch-new-worker-window calls — Mode B handles those
case "$COMMAND" in
    *dispatch-new-worker-window*) exit 0 ;;
esac

# Only proceed if an active-skill marker exists for this session
ACTIVE_SKILL_FILE="$HOME/.workflow-sessions/active-skill-${SESSION_ID}.json"
if [[ ! -f "$ACTIVE_SKILL_FILE" ]]; then
    exit 0
fi

# Only act on tmux new-window or tmux new-session commands
case "$COMMAND" in
    *"tmux new-window"* | *"tmux new-session"*) ;;
    *) exit 0 ;;
esac

# Extract session name: -s <name> (new-session) or -t <name> (new-window)
TMUX_SESSION=$(printf '%s' "$COMMAND" | grep -oE '\-(s|t) [^ ]+' | head -1 | sed 's/^-[st] //' | sed 's/:.*//')
# Extract window name: -n <name>
WINDOW_NAME=$(printf '%s' "$COMMAND" | grep -oE '\-n [^ ]+' | head -1 | sed 's/^-n //')

if [[ -z "$TMUX_SESSION" || -z "$WINDOW_NAME" ]]; then
    exit 0
fi

# Build log_dir from template in active-skill config
LOG_DIR_TEMPLATE=$(jq -r '.log_dir // "docs/workflow-logs/{session_name}"' "$ACTIVE_SKILL_FILE")
LOG_DIR="${LOG_DIR_TEMPLATE//\{session_name\}/$TMUX_SESSION}"
LOG_DIR="${LOG_DIR//\{workflow_session_id\}/$TMUX_SESSION}"

# Resolve repo_root from current working directory
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$REPO_ROOT" ]]; then
    exit 0
fi

mkdir -p "$HOME/.workflow-sessions/pending"
jq -n \
    --arg wsi "$TMUX_SESSION" \
    --arg role "$WINDOW_NAME" \
    --arg repo_root "$REPO_ROOT" \
    --arg log_dir "$LOG_DIR" \
    '{"workflow_session_id": $wsi, "role": $role, "repo_root": $repo_root, "log_dir": $log_dir}' \
    > "$HOME/.workflow-sessions/pending/${TMUX_SESSION}-${WINDOW_NAME}.json"

exit 0
