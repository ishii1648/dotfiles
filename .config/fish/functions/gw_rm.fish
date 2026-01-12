function gw_rm -d "Remove stale worktrees (merged, no remote, old, or same HEAD as default branch)"
    # Parse arguments
    set -l dry_run false
    set -l days 30

    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case --dry-run -n
                set dry_run true
            case --days
                set i (math $i + 1)
                if test $i -le (count $argv)
                    set days $argv[$i]
                else
                    echo "gw_rm: --days requires a number" >&2
                    return 1
                end
            case '-*'
                echo "gw_rm: Unknown option $argv[$i]" >&2
                echo "Usage: gw_rm [--dry-run | -n] [--days N]" >&2
                return 1
        end
        set i (math $i + 1)
    end

    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "gw_rm: Not in a git repository." >&2
        return 1
    end

    set -l main_worktree (git worktree list --porcelain | head -n1 | string replace 'worktree ' '')
    if test -z "$main_worktree"
        echo "gw_rm: Could not determine main worktree path" >&2
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
            echo "gw_rm: Could not detect default branch" >&2
            return 1
        end
    end

    set -l default_head (git rev-parse "refs/heads/$default_branch" 2>/dev/null)
    if test -z "$default_head"
        echo "gw_rm: Could not get HEAD of $default_branch" >&2
        return 1
    end

    # Get list of merged branches (remove leading "  ", "* ", "+ " markers)
    set -l merged_branches (git branch --merged "$default_branch" 2>/dev/null | string sub -s 3)

    # Calculate threshold timestamp (days ago)
    set -l threshold_ts (math (date +%s) - $days \* 86400)

    echo "Default branch: $default_branch ("(string sub -l 7 $default_head)")"
    echo "Stale threshold: $days days"
    if test "$dry_run" = true
        echo ""
        echo "[DRY-RUN] Would remove:"
    end
    echo ""

    set -l removed_count 0
    set -l targets

    for line in (git worktree list)
        set -l parts (string split -m 2 " " (string trim $line))
        set -l wt_path $parts[1]

        if test "$wt_path" = "$main_worktree"
            continue
        end

        set -l wt_head (git -C "$wt_path" rev-parse HEAD 2>/dev/null)
        set -l wt_branch (git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null)

        set -l reason ""

        # Check 1: Same HEAD as default branch (existing logic)
        if test "$wt_head" = "$default_head"
            set reason "same HEAD as $default_branch"
        end

        # Check 2: Branch is merged into default branch
        if test -z "$reason"
            if contains -- "$wt_branch" $merged_branches
                set reason "merged into $default_branch"
            end
        end

        # Check 3: No corresponding remote branch
        if test -z "$reason"
            if not git show-ref --verify --quiet "refs/remotes/origin/$wt_branch" 2>/dev/null
                set reason "no remote branch"
            end
        end

        # Check 4: Not updated for N days
        if test -z "$reason"
            set -l last_modified (stat -f %m "$wt_path" 2>/dev/null)
            if test -n "$last_modified" -a "$last_modified" -lt "$threshold_ts"
                set -l days_ago (math \(( date +%s ) - $last_modified \) / 86400)
                set reason "not updated for $days_ago days"
            end
        end

        if test -n "$reason"
            if test "$dry_run" = true
                echo "  $wt_path ($reason)"
                set removed_count (math $removed_count + 1)
            else
                echo "Removing: $wt_path ($reason)"

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
    end

    echo ""
    if test $removed_count -eq 0
        echo "No stale worktrees found."
    else if test "$dry_run" = true
        echo "Found $removed_count stale worktree(s)."
        echo ""
        echo "Run without --dry-run to actually remove."
    else
        echo "Removed $removed_count worktree(s)."
    end

    if test "$dry_run" = false
        git worktree prune
    end
end
