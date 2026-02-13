function tmw --description 'git worktreeをfzfで選択してtmux sessionを作成/アタッチ'
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "tmw: Not in a git repository." >&2
        return 1
    end

    set -l worktree (git worktree list | fzf | awk '{print $1}')
    if test -z "$worktree"
        return 0
    end

    set -l session_name (basename $worktree)

    if not tmux has-session -t $session_name 2>/dev/null
        tmux new-session -d -s $session_name -c $worktree
    end

    if test -n "$TMUX"
        tmux switch-client -t $session_name
    else
        tmux attach-session -t $session_name
    end
end
