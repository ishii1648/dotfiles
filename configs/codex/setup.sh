#!/bin/bash
set -euo pipefail

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

# npm 必須（aqua の nodejs を想定）
if ! command -v npm >/dev/null 2>&1; then
    echo -e "  ${YELLOW}npm not found, skipping codex install${NC}"
    exit 0
fi

if command -v codex >/dev/null 2>&1; then
    echo -e "  ${GREEN}codex${NC}\t✓ already installed"
    exit 0
fi

if $DRY_RUN; then
    echo -e "  ${YELLOW}codex${NC}\tnot installed (would run: npm install -g @openai/codex)"
    exit 0
fi

echo "  Installing codex via npm..."
npm install -g @openai/codex
echo -e "  ${GREEN}codex${NC}\tinstalled"
