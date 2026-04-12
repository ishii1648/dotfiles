#!/bin/bash
set -euo pipefail

# SessionStart hook: workflow session log collector
# Reads session_id from stdin JSON.
# Mode B: checks ~/.workflow-sessions/pending/pane-<N>.json (written by dispatch-new-worker-window.sh)
# Mode C: checks ~/.workflow-sessions/pending/<session>-<window>.json (written by workflow-window-register.sh)

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

# --- Mode C: session+window pending context (written by workflow-window-register.sh) ---
if [[ -z "${TMUX:-}" ]]; then
    exit 0
fi

TMUX_SESSION=$(tmux display-message -p '#{session_name}' 2>/dev/null || true)
if [[ -z "$TMUX_SESSION" ]]; then
    exit 0
fi

WINDOW_NAME=$(tmux display-message -p '#{window_name}' 2>/dev/null || true)
if [[ -z "$WINDOW_NAME" ]]; then
    exit 0
fi

PENDING_FILE_C="$SESSIONS_DIR/pending/${TMUX_SESSION}-${WINDOW_NAME}.json"
if [[ -f "$PENDING_FILE_C" ]]; then
    cp "$PENDING_FILE_C" "$SESSIONS_DIR/${SESSION_ID}.json"
    rm "$PENDING_FILE_C"
    exit 0
fi

exit 0
