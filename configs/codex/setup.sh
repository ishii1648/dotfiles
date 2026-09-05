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

# --- managed file symlinks ---
link_managed_file() {
    local src="$1" dest="$2" label="$3"

    if [[ ! -f "$src" ]]; then
        echo "  ${label}: SKIP (source not found: $src)"
        return 0
    fi

    if $DRY_RUN; then
        if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
            echo "  ${label}: ✓ OK"
        elif [[ -e "$dest" ]]; then
            echo "  ${label}: WARN: $dest exists but is not the expected symlink"
        else
            echo "  ${label}: WARN: not linked ($dest)"
        fi
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        echo "  ${label}: ✓ OK"
    elif [[ -e "$dest" ]]; then
        cp "$dest" "${dest}.bk"
        rm -f "$dest"
        ln -s "$src" "$dest"
        echo "  ${label}: linked → $dest [backup: ${dest}.bk]"
    else
        ln -s "$src" "$dest"
        echo "  ${label}: linked → $dest"
    fi
}

link_managed_file "$SCRIPT_DIR/hooks.json" "${CODEX_HOOKS_DEST:-$HOME/.codex/hooks.json}" "hooks.json"
link_managed_file "$SCRIPT_DIR/AGENTS.md" "${CODEX_AGENTS_DEST:-$HOME/.codex/AGENTS.md}" "AGENTS.md"

exit "$legacy_rc"
