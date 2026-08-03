#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# symlink_points_to / is_nix_managed_link（ADR-084: home-manager の二段リンク対応）
source "$SCRIPT_DIR/../../scripts/lib/path.sh"

# オプション解析
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

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

ok_count=0
fail_count=0
fix_count=0

# symlink を検証・作成する関数
check_or_link() {
    local target="$1"
    local source="$2"
    local display_name="$3"

    if [[ -L "$target" ]]; then
        local actual
        actual=$(readlink "$target")
        # home-manager が張った二段リンク（/nix/store 経由）も最終解決先が一致すれば OK
        # とみなす（ADR-084 Phase A の共存条件。scripts/lib/path.sh 参照）
        if symlink_points_to "$target" "$source"; then
            if $DRY_RUN; then
                if is_nix_managed_link "$target"; then
                    echo -e "  ${GREEN}${display_name}${NC}\t✓ OK (nix)"
                else
                    echo -e "  ${GREEN}${display_name}${NC}\t✓ OK"
                fi
            fi
            ok_count=$((ok_count + 1))
            return
        else
            if $DRY_RUN; then
                echo -e "  ${YELLOW}${display_name}${NC}\t✗ WRONG TARGET"
                echo "    Current:  $actual"
                echo "    Expected: $source"
                fail_count=$((fail_count + 1))
                return
            else
                rm "$target"
                ln -s "$source" "$target"
                echo -e "  ${GREEN}${display_name}${NC}\t✓ FIXED"
                fix_count=$((fix_count + 1))
                return
            fi
        fi
    elif [[ -e "$target" ]]; then
        if $DRY_RUN; then
            echo -e "  ${YELLOW}${display_name}${NC}\t✗ NOT A SYMLINK"
            fail_count=$((fail_count + 1))
        else
            echo -e "  ${YELLOW}${display_name}${NC}\t✗ NOT A SYMLINK (skipped: remove manually)"
            fail_count=$((fail_count + 1))
        fi
        return
    else
        if $DRY_RUN; then
            echo -e "  ${RED}${display_name}${NC}\t✗ MISSING"
            echo "    Fix: ln -s $source $target"
            fail_count=$((fail_count + 1))
            return
        else
            ln -s "$source" "$target"
            echo "Linked: ${display_name}"
            fix_count=$((fix_count + 1))
            return
        fi
    fi
}

# ディレクトリ symlink を実ディレクトリに切り替え
if [[ -L "$HOME/.config/fish" ]]; then
    CURRENT=$(readlink "$HOME/.config/fish")
    if [[ "${CURRENT%/}" == "${SCRIPT_DIR%/}" ]]; then
        if ! $DRY_RUN; then
            rm "$HOME/.config/fish"
            echo "Removed dir symlink: ~/.config/fish"
        fi
    fi
fi

if ! $DRY_RUN; then
    mkdir -p "$HOME/.config/fish/conf.d" "$HOME/.config/fish/functions"
fi

# completions はディレクトリ symlink のまま（dotfiles 管理のみ）
check_or_link "$HOME/.config/fish/completions" "$SCRIPT_DIR/completions" "completions"

# conf.d 個別 symlink（共通ファイルのみ）
for f in aliases.fish completions.fish env.fish fzf-fish-config.fish fzf.fish \
          herdr-ssh-tab.fish path.fish ssh-agent.fish; do
    check_or_link "$HOME/.config/fish/conf.d/$f" "$SCRIPT_DIR/conf.d/$f" "conf.d/$f"
done

# functions 個別 symlink（tracked ファイルのみ）
for f in "$SCRIPT_DIR/functions"/*.fish; do
    name=$(basename "$f")
    check_or_link "$HOME/.config/fish/functions/$name" "$f" "functions/$name"
done

# ルートファイル
# fish_variables は対象外（ADR-084）。fish は `set -U` のたびに一時ファイルを作って
# rename するため symlink が実ファイルに置き換わり、symlink 管理が維持できない。
# 実機では 2026-07-05 以降 symlink が剥がれたまま dotfiles 側（空ファイル）と乖離し、
# setup.sh --dry-run が NOT A SYMLINK で失敗し続けていた。
for f in config.fish fish_plugins; do
    check_or_link "$HOME/.config/fish/$f" "$SCRIPT_DIR/$f" "$f"
done

# デフォルトシェルを fish に設定
FISH_PATH=$(command -v fish 2>/dev/null || true)
if [[ -n "$FISH_PATH" ]]; then
    CURRENT_SHELL=$(dscl . -read /Users/"$(whoami)" UserShell 2>/dev/null | awk '{print $2}' || echo "$SHELL")
    if [[ "$CURRENT_SHELL" != "$FISH_PATH" ]]; then
        if [[ "${SETUP_INTERACTIVE:-true}" == "false" ]]; then
            # non-interactive モードでは chsh をスキップ（Docker 等でパスワード不可）
            if $DRY_RUN; then
                echo -e "  ${YELLOW}default shell${NC}\tSKIP (non-interactive mode)"
            else
                echo -e "  ${YELLOW}default shell${NC}\tSKIP (non-interactive mode)"
                echo "    Fix: chsh -s $FISH_PATH"
            fi
        elif $DRY_RUN; then
            echo -e "  ${YELLOW}default shell${NC}\t✗ NOT fish (current: $CURRENT_SHELL)"
            echo "    Fix: chsh -s $FISH_PATH"
            fail_count=$((fail_count + 1))
        else
            # /etc/shells に fish が登録されていなければ追加
            if ! grep -qx "$FISH_PATH" /etc/shells; then
                echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
                echo "  Added $FISH_PATH to /etc/shells"
            fi
            chsh -s "$FISH_PATH"
            echo -e "  ${GREEN}default shell${NC}\t✓ changed to fish"
            fix_count=$((fix_count + 1))
        fi
    else
        if $DRY_RUN; then
            echo -e "  ${GREEN}default shell${NC}\t✓ OK"
        fi
        ok_count=$((ok_count + 1))
    fi
fi

# --- launchd agent（ADR-083: 72h 超 worktree の自動削除） ---
PLIST_NAME="com.user.worktree-auto-cleanup.plist"
PLIST_SRC="$SCRIPT_DIR/launchd/$PLIST_NAME"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

if [[ ! -f "$PLIST_SRC" ]]; then
    if $DRY_RUN; then
        echo -e "  ${YELLOW}launchd agent (worktree-auto-cleanup)${NC}\tSKIP (source not found: $PLIST_SRC)"
    fi
elif [[ "$(uname)" != "Darwin" ]]; then
    if $DRY_RUN; then
        echo -e "  ${YELLOW}launchd agent (worktree-auto-cleanup)${NC}\tSKIP (not macOS)"
    fi
else
    if $DRY_RUN; then
        if [[ -f "$PLIST_DEST" ]]; then
            echo -e "  ${GREEN}launchd agent (worktree-auto-cleanup)${NC}\t✓ OK"
            ok_count=$((ok_count + 1))
        else
            echo -e "  ${RED}launchd agent (worktree-auto-cleanup)${NC}\t✗ MISSING"
            echo "    Fix: cp $PLIST_SRC $PLIST_DEST && launchctl load $PLIST_DEST"
            fail_count=$((fail_count + 1))
        fi
    else
        mkdir -p "$LAUNCH_AGENTS_DIR"
        if [[ -f "$PLIST_DEST" ]]; then
            cp "$PLIST_DEST" "${PLIST_DEST}.bk"
        fi
        cp "$PLIST_SRC" "$PLIST_DEST"
        launchctl unload "$PLIST_DEST" >/dev/null 2>&1 || true
        launchctl load "$PLIST_DEST"
        echo "  launchd agent (worktree-auto-cleanup): installed ($PLIST_DEST)"
        fix_count=$((fix_count + 1))
    fi
fi

if $DRY_RUN; then
    total=$((ok_count + fail_count))
    if [[ $fail_count -eq 0 ]]; then
        echo -e "  fish: ${GREEN}${ok_count}/${total} OK${NC}"
    else
        echo -e "  fish: ${RED}${ok_count}/${total} OK (${fail_count} failed)${NC}"
    fi
    if [[ $fail_count -gt 0 ]]; then
        exit 1
    fi
else
    echo "dotfiles fish setup complete."
fi
