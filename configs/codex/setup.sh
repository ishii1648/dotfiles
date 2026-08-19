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

CODEX_CONFIG_DEST="${CODEX_CONFIG_DEST:-$HOME/.codex/config.toml}"

has_obsolete_hooks() {
    [[ -f "$1" ]] && grep -q 'agent-pane-state\.sh' "$1"
}

remove_obsolete_hooks() {
    local config_file="$1" tmp mode
    tmp="$(mktemp "${config_file}.tmp.XXXXXX")"

    # A top-level [[hooks.<Event>]] and its nested [[hooks.<Event>.hooks]] tables
    # form one matcher group. Drop only groups that still invoke the removed
    # tmux-era agent-pane-state.sh; preserve all other user settings and hook state.
    awk '
        function flush_group() {
            if (!capturing) return
            if (buffer !~ /agent-pane-state[.]sh/) printf "%s", buffer
            buffer = ""
            capturing = 0
        }
        /^\[\[hooks\.[^.]+\]\][[:space:]]*$/ {
            flush_group()
            capturing = 1
            buffer = $0 ORS
            next
        }
        capturing && /^\[/ && !/^\[\[hooks\.[^.]+\.hooks\]\][[:space:]]*$/ {
            flush_group()
            print
            next
        }
        capturing {
            buffer = buffer $0 ORS
            next
        }
        { print }
        END { flush_group() }
    ' "$config_file" >"$tmp"

    mode="$(stat -f '%Lp' "$config_file" 2>/dev/null || stat -c '%a' "$config_file")"
    chmod "$mode" "$tmp"
    mv "$tmp" "$config_file"
}

legacy_rc=0
if has_obsolete_hooks "$CODEX_CONFIG_DEST"; then
    if $DRY_RUN; then
        echo "  config.toml: WARN: obsolete agent-pane-state.sh hooks found"
        legacy_rc=1
    else
        remove_obsolete_hooks "$CODEX_CONFIG_DEST"
        echo "  config.toml: removed obsolete agent-pane-state.sh hooks"
    fi
else
    echo "  config.toml: ✓ no obsolete hooks"
fi

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
HOOKS_DEST="${CODEX_HOOKS_DEST:-$HOME/.codex/hooks.json}"

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
    exit "$legacy_rc"
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
