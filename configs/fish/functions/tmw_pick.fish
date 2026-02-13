function tmw_pick --description 'fzfでリポジトリを選択し、worktreeを作成してtmux sessionに切替'
    set -l selected (__tmw_candidates | fzf --delimiter '\t' --with-nth 2 --cycle --prompt 'repo> ')

    if test -z "$selected"
        return 0
    end

    set -l repo_path (string split \t $selected)[1]
    set -l repo_rel (string split \t $selected)[2]

    # 直接セッションを開くリポジトリか判定
    set -l conf_file $__fish_config_dir/conf.d/tmw_direct_repos.conf
    set -l direct_repo false
    if test -f "$conf_file"
        for line in (string match -v '#*' < $conf_file | string trim)
            if test -n "$line" -a "$line" = "$repo_rel"
                set direct_repo true
                break
            end
        end
    end

    if test "$direct_repo" = true
        set -l session_name (__tm_session_name $repo_rel)
        if not tmux has-session -t $session_name 2>/dev/null
            tmux new-session -d -s $session_name -c $repo_path
        end
        if test -n "$TMUX"
            tmux switch-client -t $session_name
        else
            tmux attach-session -t $session_name
        end
        return 0
    end

    read -P "Worktree name: " worktree_name
    if test -z "$worktree_name"
        return 0
    end

    cd $repo_path
    gw_add -c $worktree_name
end
