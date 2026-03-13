function gw_add -d "Add a git worktree and cd into it"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "gw_add: Not in a git repository." >&2
        return 1
    end

    argparse 'c/claude' -- $argv
    or return 1

    set -l worktree_name $argv[1]
    if test -z "$worktree_name"
        read -P "Worktree name: " worktree_name
        if test -z "$worktree_name"
            echo "gw_add: Worktree name is required." >&2
            return 1
        end
    end

    set -l main_worktree (git worktree list --porcelain | head -n1 | string replace 'worktree ' '')
    if test -z "$main_worktree"
        echo "gw_add: Could not determine main worktree path" >&2
        return 1
    end

    set -l worktree_dir_name (string replace -a '/' '-' "$worktree_name")
    set -l worktree_path "$main_worktree@$worktree_dir_name"

    if test -d "$worktree_path"
        echo "gw_add: Warning: Worktree already exists at $worktree_path" >&2
        cd "$worktree_path"
        # tmux session 自動作成・切替
        if test -n "$TMUX"
            set -l session_name (basename $worktree_path)
            if not tmux has-session -t $session_name 2>/dev/null
                tmux new-session -d -s $session_name -c $worktree_path
            end
            if set -q _flag_claude
                tmux send-keys -t $session_name "claude" Enter
            end
            tmux switch-client -t $session_name
        else
            if set -q _flag_claude
                claude
            end
        end
        return 0
    end

    # ブランチが既にいずれかの worktree でチェックアウトされているか確認
    set -l existing_worktree_line (git worktree list | string match -r -- "^\S+.*\[$worktree_name\]\$")
    if test -n "$existing_worktree_line"
        set -l existing_worktree_path (string split -n " " $existing_worktree_line)[1]
        echo "gw_add: Branch '$worktree_name' is already checked out at $existing_worktree_path" >&2
        cd "$existing_worktree_path"
        if test -n "$TMUX"
            set -l session_name (basename $existing_worktree_path)
            if not tmux has-session -t $session_name 2>/dev/null
                tmux new-session -d -s $session_name -c $existing_worktree_path
            end
            if set -q _flag_claude
                tmux send-keys -t $session_name "claude" Enter
            end
            tmux switch-client -t $session_name
        else
            if set -q _flag_claude
                claude
            end
        end
        return 0
    end

    # リモートの最新情報を取得
    git fetch origin

    # リモートブランチの存在確認（fetch済みのローカルリモート追跡ブランチを確認）
    if git rev-parse --verify "refs/remotes/origin/$worktree_name" >/dev/null 2>&1
        # リモートブランチが存在する場合: fetch してから追跡ブランチとして作成
        git fetch origin "$worktree_name":"$worktree_name"
        or return 1
        git worktree add "$worktree_path" "$worktree_name"
    else
        # リモートブランチが存在しない場合: origin/HEAD をベースに新規ブランチ作成
        set -l default_branch (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | string replace 'refs/remotes/origin/' '')
        if test -z "$default_branch"
            set default_branch main
        end
        git worktree add "$worktree_path" -b "$worktree_name" "origin/$default_branch"
    end

    if test $status -ne 0
        echo "gw_add: Failed to create worktree" >&2
        return 1
    end

    # .claude/settings.local.json をコピー
    if test -f "$main_worktree/.claude/settings.local.json"
        mkdir -p "$worktree_path/.claude"
        cp "$main_worktree/.claude/settings.local.json" "$worktree_path/.claude/settings.local.json"
    end

    cd "$worktree_path"
    # tmux session 自動作成・切替
    if test -n "$TMUX"
        set -l session_name (basename $worktree_path)
        if not tmux has-session -t $session_name 2>/dev/null
            tmux new-session -d -s $session_name -c $worktree_path
        end
        if set -q _flag_claude
            tmux send-keys -t $session_name "claude" Enter
        end
        tmux switch-client -t $session_name
    else
        if set -q _flag_claude
            claude
        end
    end
end
