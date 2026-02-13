function __gw_cd_switch_tmux_session --argument-names worktree_path
    if test -z "$TMUX"
        return
    end
    set -l session_name (basename $worktree_path)
    if tmux has-session -t $session_name 2>/dev/null
        tmux switch-client -t $session_name
    end
end

function gw_cd -d "Change directory to a git worktree"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "gw_cd: Not in a git repository." >&2
        return 1
    end

    set -l main_worktree (git worktree list --porcelain | head -n1 | string replace 'worktree ' '')
    # default branch を取得（origin/HEAD → main → master の順でフォールバック）
    set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | string replace 'refs/remotes/origin/' '')
    if test -z "$default_branch"
        if git show-ref --verify --quiet refs/remotes/origin/main
            set default_branch "main"
        else if git show-ref --verify --quiet refs/remotes/origin/master
            set default_branch "master"
        end
    end

    set -l worktrees (git worktree list | awk '{print $1}')

    if test -n "$argv[1]"
        if test "$argv[1]" = "/"
            # "/" の場合は main worktree に移動
            if test -n "$main_worktree"
                if test "$PWD" = "$main_worktree"
                    # 既に main worktree にいる場合は default branch にチェックアウト
                    if test -n "$default_branch"
                        git checkout "$default_branch"
                    end
                else
                    cd "$main_worktree"
                    __gw_cd_switch_tmux_session "$main_worktree"
                    git pull origin "$default_branch"
                end
            end
            return 0
        end

        # ブランチ名でworktreeを検索
        for wt in $worktrees
            set -l wt_branch (git -C "$wt" rev-parse --abbrev-ref HEAD 2>/dev/null)
            if test "$wt_branch" = "$argv[1]"
                cd "$wt"
                __gw_cd_switch_tmux_session "$wt"
                return 0
            end
        end

        # パスの一部としてマッチするworktreeを検索
        for wt in $worktrees
            if string match -q "*/$argv[1]" "$wt"; or string match -q "*/$argv[1]/*" "$wt"
                cd "$wt"
                __gw_cd_switch_tmux_session "$wt"
                return 0
            end
        end

        echo "gw_cd: Worktree for '$argv[1]' not found." >&2
        return 1
    end

    if test (count $worktrees) -le 1
        echo "gw_cd: No other worktrees found."
        return 0
    end

    set -l selected (printf '%s\n' $worktrees | fzf \
        --prompt="Select worktree> ")

    if test -z "$selected"
        return 0
    end

    if test "$selected" = "$main_worktree" -a "$PWD" = "$main_worktree"
        # main worktree を選択し、既にそこにいる場合は default branch にチェックアウト
        if test -n "$default_branch"
            git checkout "$default_branch"
        end
    else if test "$selected" = "$main_worktree"
        cd "$selected"
        __gw_cd_switch_tmux_session "$selected"
        git pull origin "$default_branch"
    else
        cd "$selected"
        __gw_cd_switch_tmux_session "$selected"
    end
end
