#!/bin/bash
# configs/codex/setup.sh
# ~/.codex/config.toml の hooks ブロックを dotfiles 側で全置換する（managed-keys sync）。
# ADR-063: ユーザー固有のキー (approval_policy / sandbox_mode / [projects.*] など)
# は保持し、hooks のみ dotfiles の値で上書きする。
#
# 実装方針:
#   - 差分検出は yq (TOML→JSON, read-only) で行う。round-trip は安全。
#   - 適用は awk によるテキスト置換: dest から `[hooks.*]` / `[[hooks.*]]` で始まる
#     top-level table セクションを除去し、src から抽出した同セクションを末尾に追記。
#   - `yq -p toml -o toml` の round-trip は `[projects."/path"]` のような quote 付き
#     dotted key を破壊するため使用しない。
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

# yq が無いと差分判定ができないため diff のみ警告して終了
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

# awk: `[hooks.X]` / `[[hooks.X]]` / `[hooks]` / `[[hooks]]` から始まる top-level
# table セクションを抽出 or 除去する。次の top-level table（`[A-Za-z_]` で開始）
# が現れた時点でセクション終了とみなす。
hooks_filter() {
    # $1 = file, $2 = mode ("extract" | "strip")
    awk -v mode="$2" '
    BEGIN { in_hooks = 0 }
    {
        if ($0 ~ /^[[:space:]]*\[\[?hooks\./ || $0 ~ /^[[:space:]]*\[\[?hooks\]/) {
            in_hooks = 1
        } else if ($0 ~ /^[[:space:]]*\[\[?[A-Za-z_]/) {
            in_hooks = 0
        }
        if (mode == "extract" && in_hooks) print
        if (mode == "strip" && !in_hooks) print
    }' "$1"
}

# 末尾の連続空行を 1 行にまとめる（ファイル末尾の空白除去）
trim_trailing_blank() {
    awk '
    {
        lines[NR] = $0
    }
    END {
        last = NR
        while (last > 0 && lines[last] ~ /^[[:space:]]*$/) last--
        for (i = 1; i <= last; i++) print lines[i]
    }' "$1"
}

tmp_stripped=$(mktemp)
tmp_out=$(mktemp)
trap 'rm -f "$tmp_stripped" "$tmp_out"' EXIT

hooks_filter "$SYNC_DEST" strip > "$tmp_stripped"
trim_trailing_blank "$tmp_stripped" > "$tmp_out"
echo "" >> "$tmp_out"
hooks_filter "$SYNC_SRC" extract >> "$tmp_out"

# 書き込み前 sanity check: yq で parse できなければ abort（dest を壊さない）
if ! yq -p toml -o json '.' "$tmp_out" >/dev/null 2>&1; then
    echo "  codex hooks sync: ERROR: generated file is invalid TOML; aborting" >&2
    exit 1
fi

cp "$SYNC_DEST" "${SYNC_DEST}.bk"
mv "$tmp_out" "$SYNC_DEST"
echo "  codex hooks sync: updated [backup: ${SYNC_DEST}.bk]"
