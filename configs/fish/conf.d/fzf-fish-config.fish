# fzf.fish configuration
# https://github.com/PatrickF1/fzf.fish

if status is-interactive
    # 履歴検索のオプション
    set -g fzf_history_opts --height=40% --layout=reverse --border

    # ファイル検索で隠しファイルも表示
    set -g fzf_fd_opts --hidden --exclude=.git

    # プレビューウィンドウの設定（eza/bat がある場合は使用）
    if type -q eza
        set -g fzf_preview_dir_cmd eza --all --color=always
    end
    if type -q bat
        set -g fzf_preview_file_cmd bat --style=numbers --color=always
    end

    # diff highlighter (delta がインストールされている場合)
    if type -q delta
        set -g fzf_diff_highlighter delta --paging=never --width=20
    end
end
