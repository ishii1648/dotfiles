function __tm_candidates --description 'tm用のセッション候補一覧を生成（TAB区切り: key\t表示テキスト）'
    argparse 'sessions-only' -- $argv

    set -l existing_sessions (tmux list-sessions -F '#{session_name}' 2>/dev/null | string match -v 'main' | string match -v 'monitor' | string match -v 'prtrack')
    set -l current_session (tmux display-message -p '#{session_name}' 2>/dev/null)
    set -l all_repos (ghq list)
    set -l existing_repos
    set -l green (printf '\e[32m')
    set -l yellow (printf '\e[33m')
    set -l dim (printf '\e[2m')
    set -l reset (printf '\e[0m')

    for repo in $all_repos
        set -l name (__tm_session_name $repo)
        if contains $name $existing_sessions
            set -a existing_repos $repo
            if test "$name" = "$current_session"
                printf '%s\t%s\n' $name "$green$repo$reset"
            else
                printf '%s\t%s\n' $name "$yellow$repo$reset"
            end
            # ウィンドウ一覧（表示テキストにリポジトリパスを含めてフィルタ対象にする）
            for win in (tmux list-windows -t "$name" -F '#{window_index}:#{window_name}' 2>/dev/null)
                set -l win_idx (string replace -r ':.*' '' $win)
                set -l win_name (string replace -r '^[^:]+:' '' $win)
                set -l claude_badge ''
                set -l cs (__tm_claude_state $name $win_idx)
                if test -n "$cs"
                    set -l purple (printf '\e[35m')
                    set -l red (printf '\e[31m')
                    switch $cs
                        case running;    set claude_badge " $purple""[running]""$reset"
                        case permission; set claude_badge " $red""[perm]""$reset"
                        case ask;        set claude_badge " $red""[ask]""$reset"
                        case idle;       set claude_badge " $dim""[idle]""$reset"
                    end
                end
                printf '%s\t%s\n' "$name:$win_idx" "  $dim$win_idx: $win_name$claude_badge  $repo$reset"
            end
        end
    end

    # session名からghqパスに逆引きできなかったもの（worktree等）
    for s in $existing_sessions
        set -l found false
        for repo in $existing_repos
            if test (__tm_session_name $repo) = $s
                set found true
                break
            end
        end
        if test $found = false
            if test "$s" = "$current_session"
                printf '%s\t%s\n' $s "$green$s$reset"
            else
                printf '%s\t%s\n' $s "$yellow$s$reset"
            end
            # ウィンドウ一覧
            for win in (tmux list-windows -t "$s" -F '#{window_index}:#{window_name}' 2>/dev/null)
                set -l win_idx (string replace -r ':.*' '' $win)
                set -l win_name (string replace -r '^[^:]+:' '' $win)
                set -l claude_badge ''
                set -l cs (__tm_claude_state $s $win_idx)
                if test -n "$cs"
                    set -l purple (printf '\e[35m')
                    set -l red (printf '\e[31m')
                    switch $cs
                        case running;    set claude_badge " $purple""[running]""$reset"
                        case permission; set claude_badge " $red""[perm]""$reset"
                        case ask;        set claude_badge " $red""[ask]""$reset"
                        case idle;       set claude_badge " $dim""[idle]""$reset"
                    end
                end
                printf '%s\t%s\n' "$s:$win_idx" "  $dim$win_idx: $win_name$claude_badge  $s$reset"
            end
        end
    end

    if not set -q _flag_sessions_only
        for repo in $all_repos
            if not contains $repo $existing_repos
                printf '%s\t%s\n' '' "  $repo"
            end
        end
    end

    # worktree一覧への切替エントリ
    set -l cyan (printf '\e[36m')
    printf '%s\t%s\n' 'ww' "$cyan worktrees$reset"
end
