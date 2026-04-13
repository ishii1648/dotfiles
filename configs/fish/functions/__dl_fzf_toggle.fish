function __dl_fzf_toggle --description 'dispatch_launcher fzf タブトグル（transform 用）'
    set -l mode_file /tmp/dl-fzf-pr-mode
    if test -f $mode_file
        rm $mode_file
        echo 'reload(fish -c __dl_repo_candidates)+change-prompt(> )+change-header(  ▌repos▐  PRs          tab: switch)'
    else
        touch $mode_file
        echo 'reload(fish -c __dl_pr_worktree_candidates)+change-prompt(> )+change-header(   repos  ▌PRs▐         tab: switch)'
    end
end
