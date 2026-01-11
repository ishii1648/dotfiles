function gw_add -d "Add a git worktree and cd into it"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "gw_add: Not in a git repository." >&2
        return 1
    end

    set -l branch_name $argv[1]
    if test -z "$branch_name"
        read -P "Branch name: " branch_name
        if test -z "$branch_name"
            echo "gw_add: Branch name is required." >&2
            return 1
        end
    end

    set -l main_worktree (git worktree list --porcelain | head -n1 | string replace 'worktree ' '')
    if test -z "$main_worktree"
        echo "gw_add: Could not determine main worktree path" >&2
        return 1
    end

    set -l worktree_path "$main_worktree/.worktrees/$branch_name"

    if test -d "$worktree_path"
        echo "gw_add: Warning: Worktree already exists at $worktree_path" >&2
        cd "$worktree_path"
        return 0
    end

    mkdir -p "$main_worktree/.worktrees"

    git worktree add "$worktree_path" -b "$branch_name"
    if test $status -ne 0
        echo "gw_add: Failed to create worktree" >&2
        return 1
    end

    cd "$worktree_path"
end
