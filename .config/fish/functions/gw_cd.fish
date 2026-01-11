function gw_cd -d "Change directory to a git worktree"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "gw_cd: Not in a git repository." >&2
        return 1
    end

    set -l main_worktree (git worktree list --porcelain | head -n1 | string replace 'worktree ' '')
    set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | string replace 'refs/remotes/origin/' '')

    if test "$argv[1]" = "/"
        if test -n "$main_worktree"
            if test "$PWD" = "$main_worktree"
                # 既に main worktree にいる場合は default branch にチェックアウト
                if test -n "$default_branch"
                    git checkout "$default_branch"
                end
            else
                cd "$main_worktree"
            end
        end
        return 0
    end

    set -l worktrees (git worktree list | awk '{print $1}')

    if test (count $worktrees) -le 1
        echo "gw_cd: No other worktrees found."
        return 0
    end

    set -l selected (printf '%s\n' $worktrees | fzf \
        --prompt="Select worktree> " \
        --preview="git -C {} log --oneline -5 2>/dev/null || echo 'No commits'")

    if test -z "$selected"
        return 0
    end

    if test "$selected" = "$main_worktree" -a "$PWD" = "$main_worktree"
        # main worktree を選択し、既にそこにいる場合は default branch にチェックアウト
        if test -n "$default_branch"
            git checkout "$default_branch"
        end
    else
        cd "$selected"
    end
end
