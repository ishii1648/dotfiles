#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ディレクトリ symlink を実ディレクトリに切り替え
if [[ -L "$HOME/.config/fish" ]]; then
    CURRENT=$(readlink "$HOME/.config/fish")
    if [[ "${CURRENT%/}" == "${SCRIPT_DIR%/}" ]]; then
        rm "$HOME/.config/fish"
        echo "Removed dir symlink: ~/.config/fish"
    fi
fi

mkdir -p "$HOME/.config/fish/conf.d" "$HOME/.config/fish/functions"

# completions はディレクトリ symlink のまま（dotfiles 管理のみ）
[[ ! -e "$HOME/.config/fish/completions" ]] && \
    ln -s "$SCRIPT_DIR/completions" "$HOME/.config/fish/completions"

# conf.d 個別 symlink（共通ファイルのみ）
for f in aliases.fish completions.fish env.fish fzf-fish-config.fish fzf.fish path.fish \
          tmw_direct_repos.conf.example; do
    target="$HOME/.config/fish/conf.d/$f"
    [[ ! -e "$target" ]] && ln -s "$SCRIPT_DIR/conf.d/$f" "$target" && echo "Linked: conf.d/$f"
done

# functions 個別 symlink（tracked ファイルのみ）
for f in "$SCRIPT_DIR/functions"/*.fish; do
    name=$(basename "$f")
    target="$HOME/.config/fish/functions/$name"
    [[ ! -e "$target" ]] && ln -s "$f" "$target" && echo "Linked: functions/$name"
done

# ルートファイル
for f in config.fish fish_plugins fish_variables; do
    target="$HOME/.config/fish/$f"
    [[ ! -e "$target" ]] && ln -s "$SCRIPT_DIR/$f" "$target" && echo "Linked: $f"
done

echo "dotfiles fish setup complete."
