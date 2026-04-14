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
    set -l green (printf '\e[32m')
    set -l purple (printf '\e[38;5;141m')
    set -l red (printf '\e[31m')
    set -l dim (printf '\e[90m')
    set -l reset (printf '\e[0m')

    # cache format: wt_path\tpr_number\tpr_state\trepo_name\tbranch
    while read -l wt_path pr_number pr_state repo_name branch
        set -l session_name (basename $wt_path)

        # PR番号の色: draft=灰, open=緑, merged=紫, closed=赤
        set -l pr_tag
        switch $pr_state
            case draft;  set pr_tag "$dim#$pr_number$reset"
            case open;   set pr_tag "$green#$pr_number$reset"
            case merged; set pr_tag "$purple#$pr_number$reset"
            case closed; set pr_tag "$red#$pr_number$reset"
            case '*';    set pr_tag "#$pr_number"
        end

        if contains $session_name $existing_sessions
            printf '%s\t%s %s  %s\n' $wt_path "$yellow$repo_name$reset" $pr_tag $branch
        else
            printf '%s\t%s %s  %s\n' $wt_path "$dim$repo_name$reset" $pr_tag $branch
        end
    end < $cache_file
end
