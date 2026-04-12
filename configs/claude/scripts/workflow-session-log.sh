#!/bin/bash
set -euo pipefail

# Stop hook: workflow session log collector
# Reads session_id and transcript_path from stdin JSON.
# If ~/.workflow-sessions/<session_id>.json exists, copies transcript to log_dir.

INPUT=$(cat)

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')

if [[ -z "$SESSION_ID" || -z "$TRANSCRIPT_PATH" ]]; then
    exit 0
fi

MARKER_FILE="$HOME/.workflow-sessions/${SESSION_ID}.json"

if [[ ! -f "$MARKER_FILE" ]]; then
    exit 0
fi

REPO_ROOT=$(jq -r '.repo_root' "$MARKER_FILE")
LOG_DIR=$(jq -r '.log_dir' "$MARKER_FILE")
ROLE=$(jq -r '.role' "$MARKER_FILE")

LOG_DEST_DIR="${REPO_ROOT}/${LOG_DIR}"
mkdir -p "$LOG_DEST_DIR"
cp "$TRANSCRIPT_PATH" "${LOG_DEST_DIR}/${ROLE}.jsonl"

exit 0
