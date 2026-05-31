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

# --- agmsg (dispatch / review-loop skills の配布元) ---
# ADR-072: dispatch / review-loop は dotfiles で vendor せず agmsg-go から配布する。
# binary を pin 導入し、skills を ~/.claude/skills へ実ファイル展開する。
AGMSG_VERSION="v0.0.1"
AGMSG_PKG="github.com/ishii1648/agmsg-go/cmd/agmsg"

# 旧 dotfiles vendor を指す stale symlink を ~/.claude/skills と ~/.codex/skills の両方から
# 除去する。残すと agmsg skills install が既存ファイルとして skip し、symlink 越しに
# dotfiles 側へ書き込む事故になる（ADR-072）。
CODEX_SKILLS_DEST="$HOME/.codex/skills"
for legacy in dispatch review-loop; do
    for dest in "$SKILLS_DEST" "$CODEX_SKILLS_DEST"; do
        link="$dest/$legacy"
        if [[ -L "$link" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "  agmsg skills: WARN: stale symlink $link → $(readlink "$link") (needs removal)"
            else
                rm "$link"
                echo "  agmsg skills: removed stale symlink ($link)"
            fi
        fi
    done
done

if [[ "$DRY_RUN" == "true" ]]; then
    if command -v agmsg >/dev/null 2>&1 || { command -v go >/dev/null 2>&1 && [[ -x "$(go env GOPATH)/bin/agmsg" ]]; }; then
        echo "  agmsg: ✓ OK"
    else
        echo "  agmsg: WARN: not installed (go install $AGMSG_PKG@$AGMSG_VERSION)"
    fi
    if [[ -f "$SKILLS_DEST/review-loop/review-loop.sh" && ! -L "$SKILLS_DEST/review-loop" ]]; then
        echo "  agmsg skills: ✓ OK (installed)"
    else
        echo "  agmsg skills: WARN: not installed (agmsg skills install)"
    fi
else
    # pin を保証するため、go があれば常に @VERSION を go install する（module cache 済みなら高速）。
    # PATH に別バージョンの agmsg があっても GOPATH/bin の pin 版を優先する（ADR-072）。
    agmsg_bin=""
    if command -v go >/dev/null 2>&1; then
        echo "  agmsg: ensuring $AGMSG_PKG@$AGMSG_VERSION ..."
        if go install "$AGMSG_PKG@$AGMSG_VERSION"; then
            agmsg_bin="$(go env GOPATH)/bin/agmsg"
        else
            echo "  agmsg: WARN: go install failed"
        fi
    fi
    # go が無い/失敗した場合は PATH の agmsg にフォールバック（pin は保証できない）
    if [[ -z "$agmsg_bin" ]] && command -v agmsg >/dev/null 2>&1; then
        agmsg_bin="$(command -v agmsg)"
        echo "  agmsg: WARN: using PATH agmsg (go 不在のため $AGMSG_VERSION を保証できません)"
    fi
    # skills を実ファイル展開（--force で常に pin 版へ揃える）。codex CLI があれば codex 用にも展開
    if [[ -n "$agmsg_bin" && -x "$agmsg_bin" ]]; then
        "$agmsg_bin" skills install --force
        echo "  agmsg skills: installed → $SKILLS_DEST (dispatch / review-loop)"
        if command -v codex >/dev/null 2>&1 || [[ -d "$CODEX_SKILLS_DEST" ]]; then
            mkdir -p "$CODEX_SKILLS_DEST"
            "$agmsg_bin" skills install --dest "$CODEX_SKILLS_DEST" --force
            echo "  agmsg skills: installed → $CODEX_SKILLS_DEST (codex)"
        fi
    else
        echo "  agmsg: SKIP (go/agmsg 不在; Go 1.25+ を入れて再実行)"
        echo "  agmsg skills: SKIP (agmsg unavailable)"
    fi
fi

# --- workflow-sessions config symlink ---
WF_CONFIG_SRC="$SCRIPT_DIR/workflow-sessions.json"
WF_CONFIG_DEST="$HOME/.workflow-sessions/config.json"

if [[ "$DRY_RUN" == "true" ]]; then
    if [[ -L "$WF_CONFIG_DEST" && "$(readlink "$WF_CONFIG_DEST")" == "$WF_CONFIG_SRC" ]]; then
        echo "  workflow-sessions config: ✓ OK"
    else
        echo "  workflow-sessions config: WARN: not linked ($WF_CONFIG_DEST)"
    fi
else
    mkdir -p "$HOME/.workflow-sessions"
    if [[ -L "$WF_CONFIG_DEST" && "$(readlink "$WF_CONFIG_DEST")" == "$WF_CONFIG_SRC" ]]; then
        echo "  workflow-sessions config: ✓ OK"
    else
        ln -sf "$WF_CONFIG_SRC" "$WF_CONFIG_DEST"
        echo "  workflow-sessions config: linked → $WF_CONFIG_DEST"
    fi
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
