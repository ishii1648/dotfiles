function __dl_fzf_toggle --description 'dispatch_launcher fzf タブトグル（transform 用）'
    set -l mode_file /tmp/dl-fzf-pr-mode
    set -l bold_green (printf '\e[1;92m')
    set -l bold_cyan (printf '\e[1;96m')
    set -l yellow (printf '\e[33m')
    set -l dim (printf '\e[90m')
    set -l reset (printf '\e[0m')

    set -l tab_hint (printf '%stab: switch  ' $dim)
    set -l repos_active (printf '%srepos%s / %sPRs%s' $bold_green $reset $dim $reset)
    set -l prs_active (printf '%srepos%s / %sPRs%s    %s●%s open  %s●%s no session' $dim $reset $bold_cyan $reset $yellow $dim $dim $reset)

    if test -f $mode_file
        rm $mode_file
        echo "reload(fish -c __dl_repo_candidates)+change-prompt(> )+change-header(  $tab_hint$repos_active)"
    else
        touch $mode_file
        echo "reload(fish -c __dl_pr_worktree_candidates)+change-prompt(> )+change-header(  $tab_hint$prs_active)"
    end
end
