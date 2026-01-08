function gwt -d "Git worktree wrapper for Claude Code multi-session support"
    set -l cmd $argv[1]
    set -l args $argv[2..-1]

    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "gwt: Not in a git repository." >&2
        return 1
    end

    switch $cmd
        case add
            _gwt_add $args
        case rm remove
            _gwt_rm $args
        case cd
            _gwt_cd $args
        case list ls
            git worktree list
        case prune
            git worktree prune -v
        case help -h --help ""
            _gwt_help
        case '*'
            echo "gwt: Unknown command '$cmd'" >&2
            _gwt_help
            return 1
    end
end

function _gwt_help
    echo "Usage: gwt <command> [args]"
    echo ""
    echo "Commands:"
    echo "  add [branch]   Create a new worktree in .worktree/<branch>"
    echo "  rm [worktree]  Remove a worktree (with optional branch deletion)"
    echo "  cd [worktree]  Change directory to a worktree"
    echo "  list, ls       List all worktrees"
    echo "  prune          Remove stale worktree references"
    echo "  help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  gwt add feat/new-feature    # Create worktree for new branch"
    echo "  gwt add                     # Select branch with fzf"
    echo "  gwt rm                      # Select worktree to remove with fzf"
    echo "  gwt cd                      # Select worktree to cd with fzf"
end

function _gwt_add
    set -l branch_name $argv[1]

    # Get main worktree path
    set -l main_worktree (_gwt_get_main_worktree)
    if test -z "$main_worktree"
        echo "gwt: Could not determine main worktree path" >&2
        return 1
    end

    # If no branch name provided, use fzf to select
    if test -z "$branch_name"
        set branch_name (_gwt_select_branch)
        if test -z "$branch_name"
            echo "Cancelled."
            return 0
        end
    end

    # Normalize branch name (remove origin/ prefix if present)
    set -l local_branch (string replace -r '^origin/' '' $branch_name)
    set -l worktree_path "$main_worktree/.worktree/$local_branch"

    # Check if worktree already exists
    if test -d "$worktree_path"
        echo "gwt: Worktree already exists at $worktree_path" >&2
        return 1
    end

    # Create .worktree directory if it doesn't exist
    mkdir -p "$main_worktree/.worktree"

    # Determine if branch exists locally, remotely, or needs to be created
    if git show-ref --verify --quiet "refs/heads/$local_branch" 2>/dev/null
        # Local branch exists
        echo "Creating worktree for existing local branch: $local_branch"
        git worktree add "$worktree_path" "$local_branch"
    else if git show-ref --verify --quiet "refs/remotes/origin/$local_branch" 2>/dev/null
        # Remote branch exists, create tracking branch
        echo "Creating worktree for remote branch: origin/$local_branch"
        git worktree add --track -b "$local_branch" "$worktree_path" "origin/$local_branch"
    else
        # Create new branch from current HEAD
        echo "Creating worktree with new branch: $local_branch"
        git worktree add -b "$local_branch" "$worktree_path"
    end

    if test $status -ne 0
        echo "gwt: Failed to create worktree" >&2
        return 1
    end

    # Create symlink for .claude directory
    set -l main_claude "$main_worktree/.claude"
    set -l worktree_claude "$worktree_path/.claude"

    if test -d "$main_claude"
        if test -e "$worktree_claude"
            echo "Note: .claude already exists in worktree, skipping symlink"
        else
            ln -s "$main_claude" "$worktree_claude"
            echo "Linked: .claude -> $main_claude"
        end
    else
        echo "Note: No .claude directory found in main worktree"
    end

    echo ""
    echo "Worktree created: $worktree_path"
    echo "To start working: cd $worktree_path"
end

function _gwt_rm
    set -l worktree_arg $argv[1]

    # Get main worktree path
    set -l main_worktree (_gwt_get_main_worktree)

    # If no worktree specified, use fzf to select from .worktree/
    if test -z "$worktree_arg"
        set -l worktrees (_gwt_list_secondary_worktrees)
        if test (count $worktrees) -eq 0
            echo "gwt: No secondary worktrees found in .worktree/"
            return 0
        end

        set worktree_arg (printf '%s\n' $worktrees | fzf \
            --prompt="Select worktree to remove> " \
            --header="Enter: select, Esc: cancel" \
            --header-first)

        if test -z "$worktree_arg"
            echo "Cancelled."
            return 0
        end
    end

    # Resolve worktree path
    set -l worktree_path
    if test -d "$worktree_arg"
        set worktree_path (realpath "$worktree_arg")
    else if test -d "$main_worktree/.worktree/$worktree_arg"
        set worktree_path "$main_worktree/.worktree/$worktree_arg"
    else
        echo "gwt: Worktree not found: $worktree_arg" >&2
        return 1
    end

    # Get branch name from worktree
    set -l branch_name (git worktree list --porcelain | grep -A2 "^worktree $worktree_path\$" | grep '^branch' | string replace 'branch refs/heads/' '')

    # Confirm removal
    echo "Removing worktree: $worktree_path"
    if test -n "$branch_name"
        echo "Associated branch: $branch_name"
    end
    echo ""

    # Remove worktree
    git worktree remove "$worktree_path"
    if test $status -ne 0
        echo ""
        read -l -P "Worktree has uncommitted changes. Force remove? [y/N]: " force
        if test "$force" = "y" -o "$force" = "Y"
            git worktree remove --force "$worktree_path"
            if test $status -ne 0
                echo "gwt: Failed to remove worktree" >&2
                return 1
            end
        else
            echo "Cancelled."
            return 0
        end
    end

    echo "Worktree removed."

    # Ask about branch deletion
    if test -n "$branch_name"
        echo ""
        read -l -P "Delete branch '$branch_name' as well? [y/N]: " delete_branch
        if test "$delete_branch" = "y" -o "$delete_branch" = "Y"
            git branch -d "$branch_name" 2>/dev/null
            if test $status -ne 0
                echo "Branch not fully merged. Force delete? [y/N]: "
                read -l force_delete
                if test "$force_delete" = "y" -o "$force_delete" = "Y"
                    git branch -D "$branch_name"
                end
            end
            if test $status -eq 0
                echo "Branch '$branch_name' deleted."
            end
        end
    end
end

function _gwt_cd
    set -l worktree_arg $argv[1]

    # If no worktree specified, use fzf to select
    if test -z "$worktree_arg"
        # Get all worktrees
        set -l worktrees (git worktree list | awk '{print $1}')
        if test (count $worktrees) -eq 0
            echo "gwt: No worktrees found"
            return 1
        end

        set worktree_arg (printf '%s\n' $worktrees | fzf \
            --prompt="Select worktree> " \
            --header="Enter: select, Esc: cancel" \
            --header-first \
            --preview="git -C {} log --oneline -5 2>/dev/null || echo 'No commits'")

        if test -z "$worktree_arg"
            echo "Cancelled."
            return 0
        end
    end

    # Resolve path
    set -l main_worktree (_gwt_get_main_worktree)
    set -l target_path

    if test -d "$worktree_arg"
        set target_path "$worktree_arg"
    else if test -d "$main_worktree/.worktree/$worktree_arg"
        set target_path "$main_worktree/.worktree/$worktree_arg"
    else
        echo "gwt: Worktree not found: $worktree_arg" >&2
        return 1
    end

    cd "$target_path"
    echo "Changed to: $target_path"
end

function _gwt_get_main_worktree
    # Get the main (first) worktree path
    git worktree list --porcelain | head -n1 | string replace 'worktree ' ''
end

function _gwt_list_secondary_worktrees
    set -l main_worktree (_gwt_get_main_worktree)
    set -l worktree_dir "$main_worktree/.worktree"

    if test -d "$worktree_dir"
        for dir in $worktree_dir/*/
            if test -d "$dir"
                basename "$dir"
            end
        end
    end
end

function _gwt_select_branch
    # Fetch to ensure we have latest remote branches
    git fetch --prune 2>/dev/null

    # Get all branches (local and remote)
    set -l branches (git branch -a --format='%(refname:short)' | grep -v '^HEAD$' | sort -u)

    if test (count $branches) -eq 0
        echo "gwt: No branches found" >&2
        return 1
    end

    # Use fzf to select, with option to create new
    set -l selected (printf '%s\n' $branches | fzf \
        --prompt="Select branch (or type new name)> " \
        --header="Enter: select, Esc: cancel" \
        --header-first \
        --print-query | tail -n1)

    echo $selected
end
