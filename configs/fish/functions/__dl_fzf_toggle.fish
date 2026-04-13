function __dl_fzf_toggle --description 'dispatch_launcher fzf タブトグル（transform 用）'
    set -l mode_file /tmp/dl-fzf-pr-mode
    set -l bold_green (printf '\e[1;92m')
    set -l bold_cyan (printf '\e[1;96m')
    set -l dim (printf '\e[90m')
    set -l reset (printf '\e[0m')

    if test -f $mode_file
        rm $mode_file
        set -l header (printf '  %stab: switch  %srepos%s / %sPRs%s' $dim $bold_green $reset $dim $reset)
        echo "reload(fish -c __dl_repo_candidates)+change-prompt(> )+change-header($header)"
    else
        touch $mode_file
        set -l header (printf '  %stab: switch  %srepos%s / %sPRs%s' $dim $dim $reset $bold_cyan $reset)
        echo "reload(fish -c __dl_pr_worktree_candidates)+change-prompt(> )+change-header($header)"
    end
end
