function gw_cd -d "Change directory to a git worktree"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "gw_cd: Not in a git repository." >&2
        return 1
    end

    if test "$argv[1]" = "/"
        set -l main_worktree (git worktree list --porcelain | head -n1 | string replace 'worktree ' '')
        if test -n "$main_worktree"
            cd "$main_worktree"
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

    cd "$selected"
end
