function tm --description 'tmux session管理（既存session切替 + ghqから新規作成）'
    argparse 'sessions-only' 'new-repos-only' -- $argv

    set -l current_session (tmux display-message -p '#{session_name}' 2>/dev/null)
    set -l candidates_cmd __tm_candidates
    if set -q _flag_sessions_only
        set candidates_cmd '__tm_candidates --sessions-only'
    else if set -q _flag_new_repos_only
        set candidates_cmd '__tm_candidates --new-repos-only'
    end

    set -l output (fish -c "$candidates_cmd" | fzf --ansi \
        --print-query \
        --delimiter '\t' --with-nth 2 \
        --layout=reverse --cycle \
        --prompt '> ' \
        --header 'enter: switch | X: delete session | gw+enter: show repos' \
        --bind "start:unbind(y,n)" \
        --bind "X:change-prompt(delete? [y/N] > )+rebind(y,n)" \
        --bind "y:execute-silent(fish -c '__tm_delete_session {1} $current_session')+reload(fish -c '$candidates_cmd')+change-prompt(> )+unbind(y,n)" \
        --bind "n:change-prompt(> )+unbind(y,n)")

    set -l query $output[1]
    set -l selected $output[2]

    # gw を入力して Enter → セッションなし・メインリポジトリのみ表示
    if test "$query" = gw -a -z "$selected"
        tm --new-repos-only
        return
    end

    if test -z "$selected"
        return 0
    end

    set -l key (string split \t $selected)[1]
    set -l display_text (string split \t $selected)[2]

    if string match -qr '^.+:\d+$' -- $key
        # ウィンドウ選択 → セッション + ウィンドウ切替
        set -l parts (string match -r '^(.+):(\d+)$' -- $key)
        set -l target_session $parts[2]
        set -l target_window $parts[3]
        if test -n "$TMUX"
            tmux switch-client -t "$target_session"
            tmux select-window -t "$target_session:$target_window"
        else
            tmux attach-session -t "$target_session"
            tmux select-window -t "$target_session:$target_window"
        end
    else if test -n "$key"
        # 既存session → 切り替え
        if test -n "$TMUX"
            tmux switch-client -t $key
        else
            tmux attach-session -t $key
        end
    else
        # ghqリポジトリ → 新規session作成
        set -l entry (string trim $display_text)
        set -l session_name (__tm_session_name $entry)
        set -l project_path (ghq root)/$entry

        tmux new-session -d -s $session_name -c $project_path
        if test -n "$TMUX"
            tmux switch-client -t $session_name
        else
            tmux attach-session -t $session_name
        end
    end
end
