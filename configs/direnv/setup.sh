#!/bin/bash
# ADR: 096
# Purpose: direnv の whitelist（自動で allow するディレクトリ）を端末ごとの値から生成する
set -euo pipefail

DRY_RUN=false
case "${1:-}" in
    --dry-run) DRY_RUN=true ;;
    "") ;;
    *) echo "Usage: $0 [--dry-run]" >&2; exit 1 ;;
esac

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/direnv/direnv.toml"

# whitelist の対象（起点のリポジトリの clone や Orca の worktree の置き場所）は端末ごとに
# 違うため、setup-manifest.local.yml の components.direnv.setup_args.whitelist_prefix
# （":" 区切り）から受け取る
if [[ -z "${SETUP_WHITELIST_PREFIX:-}" ]]; then
    echo "  direnv: SKIP whitelist (set components.direnv.setup_args.whitelist_prefix in scripts/setup-manifest.local.yml)"
    exit 0
fi
if $DRY_RUN; then
    if [[ -f "$CONFIG" ]]; then echo "  direnv: ✓ $CONFIG"; else echo "  direnv: ✗ MISSING $CONFIG"; fi
    exit 0
fi

mkdir -p "$(dirname "$CONFIG")"
python3 - "$CONFIG" "$SETUP_WHITELIST_PREFIX" "$HOME" <<'PYTHON'
import json
import sys
path, prefixes, home = sys.argv[1:]
items = [p.replace("~", home, 1) if p.startswith("~") else p for p in prefixes.split(":") if p]
with open(path, "w") as f:
    f.write("# configs/direnv/setup.sh が生成する（手で編集しない）\n")
    f.write("[whitelist]\n")
    f.write("prefix = [" + ", ".join(json.dumps(p) for p in items) + "]\n")
PYTHON
echo "  direnv: wrote $CONFIG"
