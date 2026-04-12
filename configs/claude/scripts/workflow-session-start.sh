#!/bin/bash
set -euo pipefail

# SessionStart hook: workflow session log collector
# Reads session_id from stdin JSON.
# Mode B: checks ~/.workflow-sessions/pending/pane-<N>.json (written by dispatch-new-worker-window.sh)
# Mode A: checks ~/.workflow-sessions/config.json for tmux session name patterns

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')

if [[ -z "$SESSION_ID" ]]; then
    exit 0
fi

SESSIONS_DIR="$HOME/.workflow-sessions"

# --- Mode B: pane-specific pending context (e.g., dispatch workers) ---
PANE_NUM="${TMUX_PANE:-}"
PANE_NUM="${PANE_NUM#%}"

if [[ -n "$PANE_NUM" ]]; then
    PENDING_FILE="$SESSIONS_DIR/pending/pane-${PANE_NUM}.json"
    if [[ -f "$PENDING_FILE" ]]; then
        cp "$PENDING_FILE" "$SESSIONS_DIR/${SESSION_ID}.json"
        rm "$PENDING_FILE"
        exit 0
    fi
fi

# --- Mode A: config-based auto-log for tmux session patterns ---
CONFIG_FILE="$SESSIONS_DIR/config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi

if [[ -z "${TMUX:-}" ]]; then
    exit 0
fi

TMUX_SESSION=$(tmux display-message -p '#{session_name}' 2>/dev/null || true)
if [[ -z "$TMUX_SESSION" ]]; then
    exit 0
fi

WINDOW_NAME=$(tmux display-message -p '#{window_name}' 2>/dev/null || true)

# Find first matching pattern in config (glob: * → .*)
MATCH_JSON=$(jq -c --arg s "$TMUX_SESSION" \
    '(.auto_log // []) | map(select(.session_pattern as $p | $s | test("^" + ($p | gsub("\\*"; ".*")) + "$"))) | .[0]' \
    "$CONFIG_FILE" 2>/dev/null || echo "null")

if [[ "$MATCH_JSON" == "null" || -z "$MATCH_JSON" ]]; then
    exit 0
fi

# Get repo root from current working directory (claude inherits CWD from tmux pane)
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [[ -z "$REPO_ROOT" ]]; then
    exit 0
fi

WORKFLOW_SESSION_ID="$TMUX_SESSION"
ROLE="${WINDOW_NAME:-worker}"
LOG_DIR_TEMPLATE=$(printf '%s' "$MATCH_JSON" | jq -r '.log_dir // "docs/workflow-logs/{workflow_session_id}"')
LOG_DIR="${LOG_DIR_TEMPLATE//\{workflow_session_id\}/$WORKFLOW_SESSION_ID}"
LOG_DIR="${LOG_DIR//\{session_id\}/$SESSION_ID}"

mkdir -p "$SESSIONS_DIR"
jq -n \
    --arg wsi "$WORKFLOW_SESSION_ID" \
    --arg role "$ROLE" \
    --arg repo_root "$REPO_ROOT" \
    --arg log_dir "$LOG_DIR" \
    '{"workflow_session_id": $wsi, "role": $role, "repo_root": $repo_root, "log_dir": $log_dir}' \
    > "$SESSIONS_DIR/${SESSION_ID}.json"

exit 0
