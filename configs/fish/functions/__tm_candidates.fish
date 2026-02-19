function __tm_candidates --description 'tm用のセッション候補一覧を生成（TAB区切り: key\t表示テキスト）'
    argparse 'sessions-only' 'new-repos-only' -- $argv

    set -l existing_sessions (tmux list-sessions -F '#{session_name}' 2>/dev/null | string match -v 'main' | string match -v 'monitor' | string match -v 'prtrack')
    set -l current_session (tmux display-message -p '#{session_name}' 2>/dev/null)
    set -l all_repos (ghq list)
    set -l existing_repos
    set -l green (printf '\e[32m')
    set -l yellow (printf '\e[33m')
    set -l dim (printf '\e[2m')
    set -l reset (printf '\e[0m')

    if set -q _flag_new_repos_only
        # セッションなし・window化なし・worktreeリポジトリ（@含む）のみ表示
        set -l ghq_root (ghq root)
        set -l all_sessions (tmux list-sessions -F '#{session_name}' 2>/dev/null)
        set -l open_paths (tmux list-panes -a -F '#{pane_current_path}' 2>/dev/null)
        for repo in $all_repos
            string match -q '*@*' $repo; or continue
            set -l repo_path "$ghq_root/$repo"
            # gw_add は basename でセッション名を作るのでそれで判定
            set -l session_name (basename $repo_path)
            contains $session_name $all_sessions; and continue
            # ウィンドウのカレントパスとも比較
            set -l windowed false
            for p in $open_paths
                if string match -q "$repo_path*" $p
                    set windowed true
                    break
                end
            end
            test $windowed = true; and continue
            printf '%s\t%s\n' '' "  $repo"
        end
        return
    end

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
                set -l cs_raw (__tm_claude_state $name $win_idx)
                if test -n "$cs_raw"
                    set -l cs_parts (string split ' ' $cs_raw)
                    set -l cs $cs_parts[1]
                    set -l purple (printf '\e[35m')
                    set -l red (printf '\e[31m')
                    switch $cs
                        case running
                            if set -q cs_parts[2]
                                set claude_badge " $purple""[running("$cs_parts[2]"m)]""$reset"
                            else
                                set claude_badge " $purple""[running]""$reset"
                            end
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
                set -l cs_raw (__tm_claude_state $s $win_idx)
                if test -n "$cs_raw"
                    set -l cs_parts (string split ' ' $cs_raw)
                    set -l cs $cs_parts[1]
                    set -l purple (printf '\e[35m')
                    set -l red (printf '\e[31m')
                    switch $cs
                        case running
                            if set -q cs_parts[2]
                                set claude_badge " $purple""[running("$cs_parts[2]"m)]""$reset"
                            else
                                set claude_badge " $purple""[running]""$reset"
                            end
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
end
