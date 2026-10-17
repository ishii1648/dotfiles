#!/bin/bash
# ADR: 095
# Purpose: board（master / worker セッションのタスク board）をビルドし、設定と LaunchAgent を配置する
set -euo pipefail

DRY_RUN=false
case "${1:-}" in
    --dry-run) DRY_RUN=true ;;
    "") ;;
    *) echo "Usage: $0 [--dry-run]" >&2; exit 1 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BIN="$HOME/.local/bin/board"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/board/config.json"
PLIST="$HOME/Library/LaunchAgents/com.user.board.plist"

if $DRY_RUN; then
    for f in "$BIN" "$CONFIG" "$PLIST"; do
        if [[ -e "$f" ]]; then echo "  board: ✓ $f"; else echo "  board: ✗ MISSING $f"; fi
    done
    exit 0
fi

GO_BIN="$(aqua -c "$DOTFILES_DIR/aqua.yaml" which go)"
mkdir -p "$(dirname "$BIN")"
# go1.22.2 の内部リンカは LC_UUID を出力せず、macOS 26 の dyld が起動を拒否する。
# aqua の go を上げるまでは外部リンカ（Xcode の ld）でリンクする。この経路では
# ld の署名の後に go がバイナリを書き換えて署名が壊れ、起動時に SIGKILL されるので署名し直す。
(cd "$DOTFILES_DIR/tools/board" && "$GO_BIN" build -ldflags=-linkmode=external -o "$BIN" .)
if [[ "$(uname)" == Darwin ]]; then
    codesign -s - -f "$BIN" 2>/dev/null
fi
echo "  board: built $BIN"

# 起点のリポジトリは端末ごとに違うため、setup-manifest.local.yml の
# components.board.setup_args（repo / repo_path）から受け取る
if [[ -n "${SETUP_REPO:-}" && -n "${SETUP_REPO_PATH:-}" ]]; then
    mkdir -p "$(dirname "$CONFIG")"
    python3 - "$CONFIG" "$SETUP_REPO" "${SETUP_REPO_PATH/#\~/$HOME}" <<'PYTHON'
import json
import sys
path, repo, repo_path = sys.argv[1:]
config = {}
try:
    with open(path) as f:
        config = json.load(f)
except FileNotFoundError:
    pass
config.update({"repo": repo, "repo_path": repo_path})
with open(path, "w") as f:
    json.dump(config, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYTHON
    echo "  board: wrote $CONFIG"
fi

if [[ ! -f "$CONFIG" ]]; then
    echo "  board: SKIP LaunchAgent (set components.board.setup_args.repo / repo_path in scripts/setup-manifest.local.yml)"
    exit 0
fi
if [[ "$(uname)" != Darwin ]]; then
    echo "  board: SKIP LaunchAgent (not macOS)"
    exit 0
fi
"$BIN" setup
