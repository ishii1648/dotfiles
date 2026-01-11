function gw_remove -d "Remove worktrees that have the same HEAD as the default branch"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "gw_remove: Not in a git repository." >&2
        return 1
    end

    set -l main_worktree (git worktree list --porcelain | head -n1 | string replace 'worktree ' '')
    if test -z "$main_worktree"
        echo "gw_remove: Could not determine main worktree path" >&2
        return 1
    end

    # Detect default branch
    set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | string replace 'refs/remotes/origin/' '')
    if test -z "$default_branch"
        if git show-ref --verify --quiet refs/heads/main
            set default_branch "main"
        else if git show-ref --verify --quiet refs/heads/master
            set default_branch "master"
        else
            echo "gw_remove: Could not detect default branch" >&2
            return 1
        end
    end

    set -l default_head (git rev-parse "refs/heads/$default_branch" 2>/dev/null)
    if test -z "$default_head"
        echo "gw_remove: Could not get HEAD of $default_branch" >&2
        return 1
    end

    echo "Default branch: $default_branch ("(string sub -l 7 $default_head)")"
    echo ""

    set -l removed_count 0

    for line in (git worktree list)
        set -l parts (string split -m 2 " " (string trim $line))
        set -l wt_path $parts[1]

        if test "$wt_path" = "$main_worktree"
            continue
        end

        set -l wt_head (git -C "$wt_path" rev-parse HEAD 2>/dev/null)
        set -l wt_branch (git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null)

        if test "$wt_head" = "$default_head"
            echo "Removing: $wt_path (branch: $wt_branch)"

            git worktree remove --force "$wt_path" 2>/dev/null
            if test $status -eq 0
                set removed_count (math $removed_count + 1)

                if test -n "$wt_branch" -a "$wt_branch" != "$default_branch"
                    git branch -D "$wt_branch" 2>/dev/null
                    if test $status -eq 0
                        echo "  Deleted branch: $wt_branch"
                    end
                end
            else
                echo "  Failed to remove worktree" >&2
            end
        end
    end

    echo ""
    if test $removed_count -eq 0
        echo "No worktrees with the same HEAD as $default_branch found."
    else
        echo "Removed $removed_count worktree(s)."
    end

    git worktree prune
end
