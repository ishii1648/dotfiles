#!/bin/bash
# dotfiles のシンボリックリンクが適切に設定されているかチェック
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
#
# 終了コード:
#   0 - 全てOK
#   1 - 問題あり

set -euo pipefail

# dotfiles リポジトリのパスを取得（このスクリプトの位置から算出）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

ok_count=0
fail_count=0
total_count=0

# シンボリックリンクをチェックする関数
# 引数: $1=表示名, $2=リンクパス, $3=期待するターゲット
check_symlink() {
    local name="$1"
    local link_path="$2"
    local expected_target="$3"

    total_count=$((total_count + 1))

    # シンボリックリンクが存在するかチェック
    if [[ ! -e "$link_path" && ! -L "$link_path" ]]; then
        echo -e "  ${RED}$name${NC}\t✗ MISSING"
        echo "    Fix: ln -s $expected_target $link_path"
        fail_count=$((fail_count + 1))
        return
    fi

    # シンボリックリンクであるかチェック
    if [[ ! -L "$link_path" ]]; then
        echo -e "  ${YELLOW}$name${NC}\t✗ NOT A SYMLINK"
        echo "    Fix: rm -rf $link_path && ln -s $expected_target $link_path"
        fail_count=$((fail_count + 1))
        return
    fi

    # リンク先が正しいかチェック
    local actual_target
    actual_target=$(readlink "$link_path")
    # 末尾スラッシュの有無を無視して比較
    local expected_normalized="${expected_target%/}"
    local actual_normalized="${actual_target%/}"
    if [[ "$actual_normalized" != "$expected_normalized" ]]; then
        echo -e "  ${YELLOW}$name${NC}\t✗ WRONG TARGET"
        echo "    Current:  $actual_target"
        echo "    Expected: $expected_target"
        echo "    Fix: rm $link_path && ln -s $expected_target $link_path"
        fail_count=$((fail_count + 1))
        return
    fi

    # OK
    echo -e "  ${GREEN}$name${NC}\t✓ OK"
    ok_count=$((ok_count + 1))
}

echo "Checking dotfiles symlinks..."
echo "Dotfiles: $DOTFILES_DIR"
echo ""

# ========================================
# 1. ~/.config/ 配下のディレクトリ
# ========================================
echo -e "${CYAN}~/.config/ directories:${NC}"

# fish
if [[ -d "$DOTFILES_DIR/configs/fish" ]]; then
    check_symlink "fish" "$HOME/.config/fish" "$DOTFILES_DIR/configs/fish"
fi

# nvim
if [[ -d "$DOTFILES_DIR/configs/nvim" ]]; then
    check_symlink "nvim" "$HOME/.config/nvim" "$DOTFILES_DIR/configs/nvim"
fi

echo ""

# ========================================
# 2. ~/.config/ghostty/config (ファイル単体)
# ========================================
echo -e "${CYAN}~/.config/ghostty/:${NC}"

if [[ -f "$DOTFILES_DIR/configs/ghostty/config" ]]; then
    check_symlink "config" "$HOME/.config/ghostty/config" "$DOTFILES_DIR/configs/ghostty/config"
fi

echo ""

# ========================================
# 3. ~/.config/wezterm/wezterm.lua (ファイル単体)
# ========================================
echo -e "${CYAN}~/.config/wezterm/:${NC}"

if [[ -f "$DOTFILES_DIR/configs/wezterm/wezterm.lua" ]]; then
    check_symlink "wezterm.lua" "$HOME/.config/wezterm/wezterm.lua" "$DOTFILES_DIR/configs/wezterm/wezterm.lua"
fi

echo ""

# ========================================
# 4. ~/.tmux.conf
# ========================================
echo -e "${CYAN}~/:${NC}"

if [[ -f "$DOTFILES_DIR/configs/tmux/tmux.conf" ]]; then
    check_symlink "tmux.conf" "$HOME/.tmux.conf" "$DOTFILES_DIR/configs/tmux/tmux.conf"
fi

echo ""

# ========================================
# 5. ~/.local/bin/
# ========================================
echo -e "${CYAN}~/.local/bin/:${NC}"

if [[ -f "$DOTFILES_DIR/configs/tmux/tmux-fzf-url-pr-filter" ]]; then
    check_symlink "tmux-fzf-url-pr-filter" "$HOME/.local/bin/tmux-fzf-url-pr-filter" "$DOTFILES_DIR/configs/tmux/tmux-fzf-url-pr-filter"
fi

if [[ -f "$DOTFILES_DIR/configs/ghostty/ghostty-tmux-init.sh" ]]; then
    check_symlink "ghostty-tmux-init" "$HOME/.local/bin/ghostty-tmux-init" "$DOTFILES_DIR/configs/ghostty/ghostty-tmux-init.sh"
fi

echo ""

# ========================================
# 6. ~/.claude/ 配下 (configs/claude/* の各エントリ)
# ========================================
echo -e "${CYAN}~/.claude/:${NC}"

CLAUDE_SOURCE_DIR="$DOTFILES_DIR/configs/claude"

# チェック対象を明示的に定義（README.mdと同期すること）
CLAUDE_ENTRIES=(
    "agents"
    "CLAUDE.md"
    "commands"
    "scripts"
    "skills"
    "statusline.js"
)

for name in "${CLAUDE_ENTRIES[@]}"; do
    entry="$CLAUDE_SOURCE_DIR/$name"
    if [[ -e "$entry" ]]; then
        check_symlink "$name" "$HOME/.claude/$name" "$entry"
    else
        echo -e "  ${YELLOW}$name${NC}\t⚠ SOURCE NOT FOUND: $entry"
    fi
done

echo ""

# ========================================
# 結果サマリー
# ========================================
echo "========================================"
if [[ $fail_count -eq 0 ]]; then
    echo -e "Result: ${GREEN}$ok_count/$total_count OK${NC}"
else
    echo -e "Result: ${RED}$ok_count/$total_count OK ($fail_count failed)${NC}"
fi

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
exit 0
