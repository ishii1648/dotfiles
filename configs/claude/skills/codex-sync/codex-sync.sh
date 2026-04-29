#!/usr/bin/env bash
set -euo pipefail

# codex-sync.sh - ~/.claude/skills/<name> を ~/.codex/skills/<name> にディレクトリ symlink
#
# Usage: codex-sync.sh [--dry-run]

DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) echo "Usage: $(basename "$0") [--dry-run]"; exit 0 ;;
        *) echo "Usage: $(basename "$0") [--dry-run]" >&2; exit 1 ;;
    esac
done

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

CLAUDE_SKILLS="${HOME}/.claude/skills"
CODEX_SKILLS="${HOME}/.codex/skills"

if [[ ! -d "$CLAUDE_SKILLS" ]]; then
    echo "Error: $CLAUDE_SKILLS does not exist" >&2
    exit 1
fi

mkdir -p "$CODEX_SKILLS"

created=0
existed=0
conflicts=0
warns=0
skipped=0

for entry in "$CLAUDE_SKILLS"/*; do
    name="$(basename "$entry")"

    case "$name" in
        .*) continue ;;
    esac

    if [[ ! -d "$entry" ]]; then
        printf "  ${YELLOW}%-24s${NC} SKIP: not a directory (broken symlink?)\n" "$name"
        skipped=$((skipped + 1))
        continue
    fi

    if [[ ! -f "$entry/SKILL.md" ]]; then
        printf "  ${YELLOW}%-24s${NC} WARN: SKILL.md not found (codex で認識されない可能性)\n" "$name"
        warns=$((warns + 1))
    fi

    target_real="$(cd "$entry" && pwd -P)"
    link="${CODEX_SKILLS}/${name}"

    if [[ -L "$link" ]]; then
        existing_real="$(cd "$link" 2>/dev/null && pwd -P || true)"
        if [[ "$existing_real" == "$target_real" ]]; then
            printf "  ${GREEN}%-24s${NC} ✓ OK\n" "$name"
            existed=$((existed + 1))
            continue
        fi
        printf "  ${RED}%-24s${NC} CONFLICT: existing symlink -> %s (target: %s)\n" "$name" "$existing_real" "$target_real"
        conflicts=$((conflicts + 1))
        continue
    fi

    if [[ -e "$link" ]]; then
        printf "  ${RED}%-24s${NC} CONFLICT: regular file/dir already exists\n" "$name"
        conflicts=$((conflicts + 1))
        continue
    fi

    if $DRY_RUN; then
        printf "  ${YELLOW}%-24s${NC} would create: %s -> %s\n" "$name" "$link" "$target_real"
    else
        ln -s "$target_real" "$link"
        printf "  ${GREEN}%-24s${NC} ✓ CREATED\n" "$name"
    fi
    created=$((created + 1))
done

echo
echo "Summary: ${created} created, ${existed} existed, ${conflicts} conflicts, ${warns} warns, ${skipped} skipped"

if [[ $conflicts -gt 0 ]]; then
    exit 2
fi
exit 0
