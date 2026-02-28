#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
        if [[ "${actual%/}" == "${source%/}" ]]; then
            if $DRY_RUN; then
                echo -e "  ${GREEN}${display_name}${NC}\t✓ OK"
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
for f in aliases.fish completions.fish env.fish fzf-fish-config.fish fzf.fish path.fish \
          tmw_direct_repos.conf.example; do
    check_or_link "$HOME/.config/fish/conf.d/$f" "$SCRIPT_DIR/conf.d/$f" "conf.d/$f"
done

# functions 個別 symlink（tracked ファイルのみ）
for f in "$SCRIPT_DIR/functions"/*.fish; do
    name=$(basename "$f")
    check_or_link "$HOME/.config/fish/functions/$name" "$f" "functions/$name"
done

# ルートファイル
for f in config.fish fish_plugins fish_variables; do
    check_or_link "$HOME/.config/fish/$f" "$SCRIPT_DIR/$f" "$f"
done

# デフォルトシェルを fish に設定
FISH_PATH=$(command -v fish 2>/dev/null || true)
if [[ -n "$FISH_PATH" ]]; then
    CURRENT_SHELL=$(dscl . -read /Users/"$(whoami)" UserShell 2>/dev/null | awk '{print $2}' || echo "$SHELL")
    if [[ "$CURRENT_SHELL" != "$FISH_PATH" ]]; then
        if $DRY_RUN; then
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
