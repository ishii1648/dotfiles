function gw_add -d "Add a git worktree and cd into it"
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "gw_add: Not in a git repository." >&2
        return 1
    end

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

    set -l worktree_path "$main_worktree/.worktrees/$worktree_name"

    if test -d "$worktree_path"
        echo "gw_add: Warning: Worktree already exists at $worktree_path" >&2
        cd "$worktree_path"
        return 0
    end

    mkdir -p "$main_worktree/.worktrees"

    # リモートブランチの存在確認
    set -l remote_branch_exists (git ls-remote --heads origin "$worktree_name" 2>/dev/null)

    if test -n "$remote_branch_exists"
        # リモートブランチが存在する場合: fetch してから追跡ブランチとして作成
        git fetch origin "$worktree_name":"$worktree_name"
        git worktree add "$worktree_path" "$worktree_name"
    else
        # リモートブランチが存在しない場合: 新規ブランチ作成
        git worktree add "$worktree_path" -b "$worktree_name"
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
end
