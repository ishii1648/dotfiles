function __tm_select_worktree --description 'worktree一覧をfzf表示し、選択でsession作成/切替'
    set -l fzf_output (fish -c __tm_worktree_candidates | fzf --ansi --exact \
        --expect ctrl-s \
        --delimiter '\t' --with-nth 2 \
        --layout=reverse --cycle \
        --prompt 'wt> ' \
        --header 'enter: switch/create session | ctrl-s: back to sessions')
    set -l fzf_status $status

    if test $fzf_status -eq 130
        return 0
    end

    set -l pressed_key $fzf_output[1]
    set -l selected $fzf_output[2]

    # ctrl-s → session一覧に戻る
    if test "$pressed_key" = ctrl-s
        tm --sessions-only
        return
    end

    if test -z "$selected"
        return 0
    end

    set -l wt_path (string split \t $selected)[1]

    if test -z "$wt_path"
        return 0
    end

    set -l session_name (basename $wt_path)

    if tmux has-session -t $session_name 2>/dev/null
        # 既存session → 切り替え
        if test -n "$TMUX"
            tmux switch-client -t $session_name
        else
            tmux attach-session -t $session_name
        end
    else
        # 新規session作成
        tmux new-session -d -s $session_name -c $wt_path
        if test -n "$TMUX"
            tmux switch-client -t $session_name
        else
            tmux attach-session -t $session_name
        end
    end
end
