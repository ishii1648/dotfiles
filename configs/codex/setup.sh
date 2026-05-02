#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# --- codex CLI install ---
if ! command -v npm >/dev/null 2>&1; then
    echo -e "  ${YELLOW}npm not found, skipping codex install${NC}"
elif command -v codex >/dev/null 2>&1; then
    echo -e "  ${GREEN}codex${NC}\t✓ already installed"
elif $DRY_RUN; then
    echo -e "  ${YELLOW}codex${NC}\tnot installed (would run: npm install -g @openai/codex)"
else
    echo "  Installing codex via npm..."
    npm install -g @openai/codex
    echo -e "  ${GREEN}codex${NC}\tinstalled"
fi

# --- hooks.json symlink ---
HOOKS_SRC="$SCRIPT_DIR/hooks.json"
HOOKS_DEST="$HOME/.codex/hooks.json"

if [[ ! -f "$HOOKS_SRC" ]]; then
    echo "  hooks.json: SKIP (source not found: $HOOKS_SRC)"
    exit 0
fi

if $DRY_RUN; then
    if [[ -L "$HOOKS_DEST" && "$(readlink "$HOOKS_DEST")" == "$HOOKS_SRC" ]]; then
        echo "  hooks.json: ✓ OK"
    elif [[ -e "$HOOKS_DEST" ]]; then
        echo "  hooks.json: WARN: $HOOKS_DEST exists but is not the expected symlink"
    else
        echo "  hooks.json: WARN: not linked ($HOOKS_DEST)"
    fi
    exit 0
fi

mkdir -p "$HOME/.codex"
if [[ -L "$HOOKS_DEST" && "$(readlink "$HOOKS_DEST")" == "$HOOKS_SRC" ]]; then
    echo "  hooks.json: ✓ OK"
elif [[ -e "$HOOKS_DEST" ]]; then
    cp "$HOOKS_DEST" "${HOOKS_DEST}.bk"
    rm -f "$HOOKS_DEST"
    ln -s "$HOOKS_SRC" "$HOOKS_DEST"
    echo "  hooks.json: linked → $HOOKS_DEST [backup: ${HOOKS_DEST}.bk]"
else
    ln -s "$HOOKS_SRC" "$HOOKS_DEST"
    echo "  hooks.json: linked → $HOOKS_DEST"
fi
