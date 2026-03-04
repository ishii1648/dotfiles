#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN="${DRY_RUN:-false}"

PLIST_NAME="com.user.session-index-backfill.plist"
PLIST_SRC="$SCRIPT_DIR/launchd/$PLIST_NAME"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

if [[ "$(uname)" != "Darwin" ]]; then
    echo "  launchd agent: SKIP (not macOS)"
    echo "  To enable hourly backfill on Linux/remote, add to crontab:"
    echo "    0 * * * * python3 ~/.claude/scripts/session-index-backfill-batch.py"
    exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
    if [[ -f "$PLIST_DEST" ]]; then
        echo "  launchd agent: ✓ OK ($PLIST_DEST)"
    else
        echo "  launchd agent: ✗ MISSING ($PLIST_DEST)"
        exit 1
    fi
    exit 0
fi

mkdir -p "$LAUNCH_AGENTS_DIR"
cp "$PLIST_SRC" "$PLIST_DEST"
launchctl load "$PLIST_DEST"
echo "  launchd agent: installed ($PLIST_DEST)"
