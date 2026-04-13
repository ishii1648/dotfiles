function __dl_pr_worktree_candidates --description 'PR付き worktree の fzf 候補を出力'
    set -l cache_file /tmp/dl-pr-worktrees.cache
    set -l cache_ttl 3600

    if test -f $cache_file
        set -l now (date +%s)
        set -l mtime (stat -f %m $cache_file)
        if test (math $now - $mtime) -gt $cache_ttl
            fish -c __dl_pr_cache_refresh &
            disown
        end
    else
        __dl_pr_cache_refresh
    end

    if not test -f $cache_file; or test (stat -f '%z' $cache_file) -eq 0
        return 0
    end

    set -l existing_sessions (tmux list-sessions -F '#{session_name}' 2>/dev/null)
    set -l yellow (printf '\e[33m')
    set -l cyan (printf '\e[36m')
    set -l dim (printf '\e[2m')
    set -l reset (printf '\e[0m')

    # cache format: wt_path\tpr_number\tis_draft\trepo_name\tbranch
    while read -l wt_path pr_number is_draft repo_name branch
        set -l session_name (basename $wt_path)

        # PR番号: draft=dim, open=cyan
        set -l pr_tag
        if test "$is_draft" = true
            set pr_tag "$dim#$pr_number$reset"
        else
            set pr_tag "$cyan#$pr_number$reset"
        end

        # セッション有無で repo_name の色を変える
        if contains $session_name $existing_sessions
            printf '%s\t%s %s  %s\n' $wt_path "$yellow$repo_name$reset" $pr_tag $branch
        else
            printf '%s\t%s %s  %s\n' $wt_path "$dim$repo_name$reset" $pr_tag $branch
        end
    end < $cache_file
end
