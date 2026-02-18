function tm --description 'tmux session管理（既存session切替 + ghqから新規作成）'
    argparse 'sessions-only' -- $argv

    set -l current_session (tmux display-message -p '#{session_name}' 2>/dev/null)
    set -l candidates_cmd __tm_candidates
    if set -q _flag_sessions_only
        set candidates_cmd '__tm_candidates --sessions-only'
    end

    set -l fzf_output (fish -c "$candidates_cmd" | fzf --ansi \
        --print-query \
        --delimiter '\t' --with-nth 2 \
        --layout=reverse --cycle \
        --prompt '> ' \
        --header 'enter: switch | X: delete session' \
        --bind "start:unbind(y,n)" \
        --bind "X:change-prompt(delete? [y/N] > )+rebind(y,n)" \
        --bind "y:execute-silent(fish -c '__tm_delete_session {1} $current_session')+reload(fish -c '$candidates_cmd')+change-prompt(> )+unbind(y,n)" \
        --bind "n:change-prompt(> )+unbind(y,n)")
    set -l fzf_status $status

    # escape/ctrl-c → 何もしない
    if test $fzf_status -eq 130
        return 0
    end

    set -l query $fzf_output[1]
    set -l selected $fzf_output[2]

    # query が ww → worktree一覧へ
    if test "$query" = gw
        __tm_select_worktree
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
