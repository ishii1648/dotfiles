function __dl_fzf_toggle --description 'dispatch_launcher fzf タブトグル（claude/codex 切替）'
    set -l mode_file /tmp/dl-fzf-codex-mode
    set -l bold_green (printf '\e[1;92m')
    set -l bold_cyan (printf '\e[1;96m')
    set -l dim (printf '\e[90m')
    set -l reset (printf '\e[0m')

    set -l tab_hint (printf '%stab: switch  ' $dim)
    set -l claude_active (printf '%sclaude%s / %scodex%s' $bold_green $reset $dim $reset)
    set -l codex_active (printf '%sclaude%s / %scodex%s' $dim $reset $bold_cyan $reset)

    if test -f $mode_file
        rm $mode_file
        echo "reload(fish -c __dl_repo_candidates)+change-prompt(> )+change-header(  $tab_hint$claude_active)"
    else
        touch $mode_file
        echo "reload(fish -c __dl_repo_candidates)+change-prompt(> )+change-header(  $tab_hint$codex_active)"
    end
end
