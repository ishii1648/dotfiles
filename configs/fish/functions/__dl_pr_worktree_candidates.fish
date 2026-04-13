function __dl_pr_worktree_candidates --description 'PR付き worktree の fzf 候補を出力'
    set -l cache_file /tmp/dl-pr-worktrees.cache
    set -l cache_ttl 3600

    # キャッシュ鮮度チェック → stale なら bg refresh
    if test -f $cache_file
        set -l now (date +%s)
        set -l mtime (stat -f %m $cache_file)
        if test (math $now - $mtime) -gt $cache_ttl
            fish -c __dl_pr_cache_refresh &
            disown
        end
    else
        fish -c __dl_pr_cache_refresh &
        disown
    end

    if not test -f $cache_file; or test (stat -f %s $cache_file) -eq 0
        return 0
    end

    set -l existing_sessions (tmux list-sessions -F '#{session_name}' 2>/dev/null)
    set -l yellow (printf '\e[33m')
    set -l cyan (printf '\e[36m')
    set -l dim (printf '\e[2m')
    set -l reset (printf '\e[0m')

    while read -l wt_path pr_number is_draft repo_short
        set -l session_name (basename $wt_path)
        set -l pr_badge "$cyan#$pr_number$reset"
        if test "$is_draft" = true
            set pr_badge "$dim#$pr_number draft$reset"
        end

        if contains $session_name $existing_sessions
            printf '%s\t%s  %s\n' $wt_path "$yellow$repo_short$reset" $pr_badge
        else
            printf '%s\t%s  %s\n' $wt_path "$dim$repo_short$reset" $pr_badge
        end
    end < $cache_file
end
