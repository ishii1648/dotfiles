#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$SCRIPT_DIR/settings.json"
LOCAL="${1:-}"
DEST="$HOME/.claude/settings.json"

# マージ結果生成
if [[ -n "$LOCAL" && -f "$LOCAL" ]]; then
    generated=$(jq -Ss 'reduce .[] as $item ({}; . * $item)' "$BASE" "$LOCAL")
else
    generated=$(jq -S . "$BASE")
fi

# 初回
if [[ ! -f "$DEST" ]]; then
    echo "$generated" > "$DEST"
    echo "Created: $DEST"
    exit 0
fi

current=$(jq -S . "$DEST")

# 差分なし
if [[ "$generated" == "$current" ]]; then
    echo "No changes: ~/.claude/settings.json is up to date"
    exit 0
fi

# current が behind（generated が current を包含）→ 自動上書き
is_behind=$(jq -n --argjson g "$generated" --argjson c "$current" '$g | contains($c)')
if [[ "$is_behind" == "true" ]]; then
    echo "$generated" > "$DEST"
    echo "Updated: ~/.claude/settings.json"
    exit 0
fi

# ローカル編集あり → 警告して停止
echo "[WARN] ~/.claude/settings.json has local changes not in dotfiles/sandbox:"
diff <(echo "$generated") <(echo "$current") || true
echo ""
echo "Reflect the above changes in dotfiles or overlay (e.g. settings.overlay.json), then re-run setup.sh."
exit 1
