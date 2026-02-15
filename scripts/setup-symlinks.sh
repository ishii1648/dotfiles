#!/bin/bash
# dotfiles のシンボリックリンクを設定する
#
# 使い方:
#   setup-symlinks.sh [--dry-run] [--profile <name>]
#
# オプション:
#   --dry-run              チェックのみ（変更しない）
#   --profile <name>       プロファイル指定（デフォルト: full）
#
# プロファイル:
#   full    - 全コンポーネント（デフォルト）
#   remote  - fish, nvim, claude, aqua のみ（リモートマシン用）
#
# チェック対象:
#   1. ~/.config/ 配下のディレクトリ (fish, nvim)
#   2. ~/.config/ghostty/config (ファイル単体)
#   3. ~/.config/wezterm/wezterm.lua (ファイル単体)
#   4. ~/.tmux.conf
#   5. ~/.local/bin/tmux-fzf-url-pr-filter
#   6. ~/.claude/ 配下 (configs/claude/* の各エントリ)
#      - agents/, commands/, scripts/, skills/ (ディレクトリ)
#      - CLAUDE.md, statusline.js (ファイル)
#   7. ~/.config/aquaproj-aqua/aqua.yaml
#
# 終了コード:
#   0 - 全てOK
#   1 - 問題あり（--dry-run時）または設定失敗

set -euo pipefail

# オプション解析
DRY_RUN=false
PROFILE="full"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --profile)
            PROFILE="${2:-}"
            if [[ -z "$PROFILE" ]]; then
                echo "Error: --profile requires a value" >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# プロファイル検証
case "$PROFILE" in
    full|remote) ;;
    *)
        echo "Error: Unknown profile: $PROFILE (available: full, remote)" >&2
        exit 1
        ;;
esac

# dotfiles リポジトリのパスを取得（このスクリプトの位置から算出）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ok_count=0
fix_count=0
fail_count=0
total_count=0

# シンボリックリンクを作成する関数
create_symlink() {
    local link_path="$1"
    local target="$2"

    # 親ディレクトリがなければ作成
    local parent_dir
    parent_dir="$(dirname "$link_path")"
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
    fi

    ln -s "$target" "$link_path"
}

# シンボリックリンクをチェック・設定する関数
# 引数: $1=表示名, $2=リンクパス, $3=期待するターゲット
ensure_symlink() {
    local name="$1"
    local link_path="$2"
    local expected_target="$3"

    total_count=$((total_count + 1))

    # シンボリックリンクが存在するかチェック
    if [[ ! -e "$link_path" && ! -L "$link_path" ]]; then
        if $DRY_RUN; then
            echo -e "  ${RED}$name${NC}\t✗ MISSING"
            echo "    Fix: ln -s $expected_target $link_path"
            fail_count=$((fail_count + 1))
        else
            create_symlink "$link_path" "$expected_target"
            echo -e "  ${GREEN}$name${NC}\t✓ CREATED"
            fix_count=$((fix_count + 1))
        fi
        return
    fi

    # シンボリックリンクであるかチェック
    if [[ ! -L "$link_path" ]]; then
        if $DRY_RUN; then
            echo -e "  ${YELLOW}$name${NC}\t✗ NOT A SYMLINK"
            echo "    Fix: rm -rf $link_path && ln -s $expected_target $link_path"
            fail_count=$((fail_count + 1))
        else
            echo -e "  ${YELLOW}$name${NC}\t✗ NOT A SYMLINK (skipped: remove manually)"
            echo "    Fix: rm -rf $link_path && ln -s $expected_target $link_path"
            fail_count=$((fail_count + 1))
        fi
        return
    fi

    # リンク先が正しいかチェック
    local actual_target
    actual_target=$(readlink "$link_path")
    local expected_normalized="${expected_target%/}"
    local actual_normalized="${actual_target%/}"
    if [[ "$actual_normalized" != "$expected_normalized" ]]; then
        if $DRY_RUN; then
            echo -e "  ${YELLOW}$name${NC}\t✗ WRONG TARGET"
            echo "    Current:  $actual_target"
            echo "    Expected: $expected_target"
            echo "    Fix: rm $link_path && ln -s $expected_target $link_path"
            fail_count=$((fail_count + 1))
        else
            rm "$link_path"
            create_symlink "$link_path" "$expected_target"
            echo -e "  ${GREEN}$name${NC}\t✓ FIXED (was: $actual_target)"
            fix_count=$((fix_count + 1))
        fi
        return
    fi

    # OK
    echo -e "  ${GREEN}$name${NC}\t✓ OK"
    ok_count=$((ok_count + 1))
}

# ========================================
# コンポーネント関数
# ========================================

setup_fish() {
    echo -e "${CYAN}~/.config/ directories:${NC}"
    if [[ -d "$DOTFILES_DIR/configs/fish" ]]; then
        ensure_symlink "fish" "$HOME/.config/fish" "$DOTFILES_DIR/configs/fish"
    fi
}

setup_nvim() {
    if [[ -d "$DOTFILES_DIR/configs/nvim" ]]; then
        ensure_symlink "nvim" "$HOME/.config/nvim" "$DOTFILES_DIR/configs/nvim"
    fi
}

setup_ghostty() {
    echo -e "${CYAN}~/.config/ghostty/:${NC}"
    if [[ -f "$DOTFILES_DIR/configs/ghostty/config" ]]; then
        ensure_symlink "config" "$HOME/.config/ghostty/config" "$DOTFILES_DIR/configs/ghostty/config"
    fi
}

setup_wezterm() {
    echo -e "${CYAN}~/.config/wezterm/:${NC}"
    if [[ -f "$DOTFILES_DIR/configs/wezterm/wezterm.lua" ]]; then
        ensure_symlink "wezterm.lua" "$HOME/.config/wezterm/wezterm.lua" "$DOTFILES_DIR/configs/wezterm/wezterm.lua"
    fi
}

setup_tmux() {
    echo -e "${CYAN}~/:${NC}"
    if [[ -f "$DOTFILES_DIR/configs/tmux/tmux.conf" ]]; then
        ensure_symlink "tmux.conf" "$HOME/.tmux.conf" "$DOTFILES_DIR/configs/tmux/tmux.conf"
    fi
    echo ""
    echo -e "${CYAN}~/.local/bin/:${NC}"
    if [[ -f "$DOTFILES_DIR/configs/tmux/tmux-fzf-url-pr-filter" ]]; then
        ensure_symlink "tmux-fzf-url-pr-filter" "$HOME/.local/bin/tmux-fzf-url-pr-filter" "$DOTFILES_DIR/configs/tmux/tmux-fzf-url-pr-filter"
    fi
}

setup_claude() {
    echo -e "${CYAN}~/.claude/:${NC}"
    local CLAUDE_SOURCE_DIR="$DOTFILES_DIR/configs/claude"
    local CLAUDE_ENTRIES=(
        "agents"
        "CLAUDE.md"
        "commands"
        "scripts"
        "skills"
        "statusline.js"
    )
    for name in "${CLAUDE_ENTRIES[@]}"; do
        local entry="$CLAUDE_SOURCE_DIR/$name"
        if [[ -e "$entry" ]]; then
            ensure_symlink "$name" "$HOME/.claude/$name" "$entry"
        else
            echo -e "  ${YELLOW}$name${NC}\t⚠ SOURCE NOT FOUND: $entry"
        fi
    done
}

setup_aqua() {
    echo -e "${CYAN}~/.config/aquaproj-aqua/:${NC}"
    if [[ -f "$DOTFILES_DIR/aqua.yaml" ]]; then
        ensure_symlink "aqua.yaml" "$HOME/.config/aquaproj-aqua/aqua.yaml" "$DOTFILES_DIR/aqua.yaml"
    fi
}

# ========================================
# プロファイル定義
# ========================================

run_profile_full() {
    setup_fish
    setup_nvim
    echo ""
    setup_ghostty
    echo ""
    setup_wezterm
    echo ""
    setup_tmux
    echo ""
    setup_claude
    echo ""
    setup_aqua
}

run_profile_remote() {
    setup_fish
    setup_nvim
    echo ""
    setup_claude
    echo ""
    setup_aqua
}

# ========================================
# メイン実行
# ========================================

if $DRY_RUN; then
    echo "Checking dotfiles symlinks... (dry-run, profile: $PROFILE)"
else
    echo "Setting up dotfiles symlinks... (profile: $PROFILE)"
fi
echo "Dotfiles: $DOTFILES_DIR"
echo ""

case "$PROFILE" in
    full)   run_profile_full ;;
    remote) run_profile_remote ;;
esac

echo ""

# ========================================
# 結果サマリー
# ========================================
echo "========================================"
if $DRY_RUN; then
    if [[ $fail_count -eq 0 ]]; then
        echo -e "Result: ${GREEN}$ok_count/$total_count OK${NC}"
    else
        echo -e "Result: ${RED}$ok_count/$total_count OK ($fail_count failed)${NC}"
    fi
else
    if [[ $fail_count -eq 0 ]]; then
        echo -e "Result: ${GREEN}All $total_count symlinks OK${NC} (created/fixed: $fix_count)"
    else
        echo -e "Result: ${YELLOW}$ok_count OK, $fix_count fixed, $fail_count failed${NC}"
    fi
fi

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
exit 0
