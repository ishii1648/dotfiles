#!/bin/bash
# configs/codex/setup.sh
# ~/.codex/config.toml の hooks ブロックを dotfiles 側で全置換する（managed-keys sync）。
# ADR-063: ユーザー固有のキー (approval_policy / sandbox_mode / [projects.*] など)
# は保持し、hooks のみ dotfiles の値で上書きする。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN="${DRY_RUN:-false}"

SYNC_SRC="$SCRIPT_DIR/config.toml"
SYNC_DEST="$HOME/.codex/config.toml"

mkdir -p "$HOME/.codex"

# 初回: dest が無ければ src をそのままコピー
if [[ ! -f "$SYNC_DEST" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  codex hooks sync: WARN: dest not found ($SYNC_DEST)"
        exit 0
    fi
    cp "$SYNC_SRC" "$SYNC_DEST"
    echo "  codex hooks sync: created $SYNC_DEST (copied from dotfiles)"
    exit 0
fi

# yq が無いと TOML マージできないため diff のみ警告して終了
if ! command -v yq >/dev/null 2>&1; then
    echo "  codex hooks sync: SKIP (yq not found — install via aqua and re-run)"
    exit 0
fi

src_hooks=$(yq -p toml -o json '.hooks // {}' "$SYNC_SRC")
dest_hooks=$(yq -p toml -o json '.hooks // {}' "$SYNC_DEST")

if [[ "$src_hooks" == "$dest_hooks" ]]; then
    echo "  codex hooks sync: ✓ no changes"
    exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
    echo "  codex hooks sync: WARN: hooks differ (would update $SYNC_DEST)"
    exit 0
fi

# dest の hooks を src の hooks で全置換（他キーは保持）
tmp=$(mktemp)
cp "$SYNC_DEST" "$tmp"
yq -p toml -o toml -i ".hooks = load(\"$SYNC_SRC\").hooks" "$tmp"

cp "$SYNC_DEST" "${SYNC_DEST}.bk"
mv "$tmp" "$SYNC_DEST"
echo "  codex hooks sync: updated [backup: ${SYNC_DEST}.bk]"
