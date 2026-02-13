function __tm_delete_session --description 'tmuxセッションを削除（worktreeの場合はgit操作も実行）'
    set -l session $argv[1]
    set -l current_session $argv[2]

    # 空session名 or 現在のセッション → スキップ
    if test -z "$session"
        return 0
    end
    # ウィンドウ選択行（session:N 形式）はスキップ
    if string match -qr ':\d+' -- $session
        return 0
    end
    if test "$session" = "$current_session"
        return 0
    end

    # セッションの開始ディレクトリを取得
    set -l session_path (tmux display-message -t "$session" -p '#{session_path}' 2>/dev/null)
    if test -z "$session_path"
        return 0
    end

    # worktree判定: session_pathがgitリポジトリ内かつmain worktreeと異なるか
    set -l main_worktree ''
    set -l wt_branch ''

    if test -d "$session_path/.git" -o -f "$session_path/.git"
        set main_worktree (git -C "$session_path" worktree list --porcelain 2>/dev/null | head -n1 | string replace 'worktree ' '')
    end

    if test -n "$main_worktree" -a "$session_path" != "$main_worktree"
        # worktree: session kill → worktree remove → branch -D → prune
        set wt_branch (git -C "$session_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
        tmux kill-session -t "$session" 2>/dev/null
        git -C "$main_worktree" worktree remove --force "$session_path" 2>/dev/null
        if test -n "$wt_branch" -a "$wt_branch" != "HEAD"
            git -C "$main_worktree" branch -D "$wt_branch" 2>/dev/null
        end
        git -C "$main_worktree" worktree prune 2>/dev/null
    else
        # 非worktree: session killのみ
        tmux kill-session -t "$session" 2>/dev/null
    end
end
