#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN="${DRY_RUN:-false}"
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# --- dotfiles 管理キーの同期 ---
# SYNC_KEYS: source の値で全置換するキー
SYNC_KEYS=("hooks" "statusLine")
# MERGE_KEYS: source のキーを dest にマージするキー（dest 固有のキーは保持）
MERGE_KEYS=("env")
SYNC_SRC="$SCRIPT_DIR/settings.json"
SYNC_DEST="$HOME/.claude/settings.json"

if [[ -f "$SYNC_DEST" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        has_diff=false
        for key in "${SYNC_KEYS[@]}"; do
            src_val=$(jq -c --arg k "$key" '.[$k]' "$SYNC_SRC")
            dest_val=$(jq -c --arg k "$key" '.[$k]' "$SYNC_DEST")
            if [[ "$src_val" != "$dest_val" ]]; then
                echo "  managed-keys sync: WARN: key '$key' differs (src ≠ dest)"
                has_diff=true
            fi
        done
        for key in "${MERGE_KEYS[@]}"; do
            missing=$(jq -r --arg k "$key" --slurpfile dest "$SYNC_DEST" \
                '.[$k] // {} | to_entries[] | select($dest[0][$k][.key] == null) | .key' "$SYNC_SRC")
            if [[ -n "$missing" ]]; then
                echo "  managed-keys merge: WARN: key '$key' missing entries: $missing"
                has_diff=true
            fi
        done
        if [[ "$has_diff" == "false" ]]; then
            echo "  managed-keys sync: ✓ OK"
        fi
    else
        tmp=$(mktemp)
        cp "$SYNC_DEST" "$tmp"
        changed=false
        for key in "${SYNC_KEYS[@]}"; do
            src_val=$(jq -c --arg k "$key" '.[$k]' "$SYNC_SRC")
            dest_val=$(jq -c --arg k "$key" '.[$k]' "$SYNC_DEST")
            if [[ "$src_val" != "$dest_val" ]]; then
                jq -s --arg k "$key" '.[0][$k] as $v | .[1] | .[$k] = $v' "$SYNC_SRC" "$tmp" > "$tmp.new" && mv "$tmp.new" "$tmp"
                changed=true
            fi
        done
        for key in "${MERGE_KEYS[@]}"; do
            merged=$(jq -s --arg k "$key" '.[0][$k] as $src | .[1] | .[$k] = ((.[$k] // {}) * $src)' "$SYNC_SRC" "$tmp")
            if [[ "$(jq -c --arg k "$key" '.[$k]' "$tmp")" != "$(echo "$merged" | jq -c --arg k "$key" '.[$k]')" ]]; then
                echo "$merged" > "$tmp.new" && mv "$tmp.new" "$tmp"
                changed=true
            fi
        done
        if [[ "$changed" == "true" ]]; then
            cp "$SYNC_DEST" "${SYNC_DEST}.bk"
            mv "$tmp" "$SYNC_DEST"
            echo "  managed-keys sync: updated [backup: ${SYNC_DEST}.bk]"
        else
            rm -f "$tmp"
            echo "  managed-keys sync: ✓ no changes"
        fi
    fi
else
    echo "  managed-keys sync: SKIP (dest not found)"
fi

# --- skills symlinks ---
SKILLS_SRC="$SCRIPT_DIR/skills"
SKILLS_DEST="$HOME/.claude/skills"

# ~/.claude/skills がディレクトリ symlink の場合、実ディレクトリに変換して
# 中の各 skill を個別 symlink として再作成する（dotfiles 側で上書き可能にするため）
if [[ -L "$SKILLS_DEST" && -d "$SKILLS_DEST" ]]; then
    old_target=$(readlink "$SKILLS_DEST")
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  skills dir: WARN: directory symlink → $old_target (needs conversion)"
    else
        rm "$SKILLS_DEST"
        mkdir -p "$SKILLS_DEST"
        # 旧リンク先の各 skill を個別 symlink として復元
        shopt -s nullglob
        for sd in "$old_target"/*/; do
            sn=$(basename "$sd")
            ln -s "$sd" "$SKILLS_DEST/$sn"
        done
        shopt -u nullglob
        echo "  skills dir: converted directory symlink → individual symlinks (from $old_target)"
    fi
fi

if [[ -d "$SKILLS_SRC" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        shopt -s nullglob
        for skill_dir in "$SKILLS_SRC"/*/; do
            skill_name=$(basename "$skill_dir")
            link="$SKILLS_DEST/$skill_name"
            if [[ -L "$link" && "$(readlink "$link")" == "$skill_dir" ]]; then
                echo "  skill symlink: ✓ OK ($skill_name)"
            elif [[ -L "$link" ]]; then
                echo "  skill symlink: WARN: $skill_name → wrong target"
            else
                echo "  skill symlink: WARN: $skill_name not linked"
            fi
        done
        shopt -u nullglob
    else
        mkdir -p "$SKILLS_DEST"
        shopt -s nullglob
        for skill_dir in "$SKILLS_SRC"/*/; do
            skill_name=$(basename "$skill_dir")
            link="$SKILLS_DEST/$skill_name"
            if [[ -L "$link" && "$(readlink "$link")" == "$skill_dir" ]]; then
                echo "  skill symlink: ✓ OK ($skill_name)"
            elif [[ -L "$link" ]]; then
                rm "$link"
                ln -s "$skill_dir" "$link"
                echo "  skill symlink: updated → $skill_name (dotfiles overrides)"
            else
                ln -s "$skill_dir" "$link"
                echo "  skill symlink: created → $skill_name"
            fi
        done
        shopt -u nullglob
    fi
else
    echo "  skills symlink: SKIP (no configs/claude/skills directory)"
fi

# --- launchd agent ---
PLIST_NAME="com.user.session-index-backfill.plist"
PLIST_SRC="$SCRIPT_DIR/launchd/$PLIST_NAME"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

if [[ ! -f "$PLIST_SRC" ]]; then
    echo "  launchd agent: SKIP (source not found: $PLIST_SRC)"
    exit 0
fi

if [[ "$(uname)" != "Darwin" ]]; then
    echo "  launchd agent: SKIP (not macOS)"
    echo "  To enable hourly backfill on Linux/remote, add to crontab:"
    echo "    0 * * * * python3 ~/.claude/scripts/session-index-backfill-batch.py"
    exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
    if [[ -f "$PLIST_DEST" ]]; then
        echo "  launchd agent: ✓ OK ($PLIST_DEST)"
    else
        echo "  launchd agent: ✗ MISSING ($PLIST_DEST)"
        exit 1
    fi
    exit 0
fi

mkdir -p "$LAUNCH_AGENTS_DIR"
if [[ -f "$PLIST_DEST" ]]; then
    cp "$PLIST_DEST" "${PLIST_DEST}.bk"
fi
cp "$PLIST_SRC" "$PLIST_DEST"
launchctl load "$PLIST_DEST"
echo "  launchd agent: installed ($PLIST_DEST)"
