# Ctrl+R で履歴検索
function __fzf_history
    set -l query (commandline)
    history | fzf --exact --height 40% --reverse --query "$query" | read -l cmd
    if test -n "$cmd"
        commandline -r $cmd
    end
    commandline -f repaint
end

if status is-interactive
    bind \cr __fzf_history
end
