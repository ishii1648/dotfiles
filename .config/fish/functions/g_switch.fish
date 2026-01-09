function g_switch -d "Interactive git branch switch with fzf"
    # Gitリポジトリチェック
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo "g_switch: Not in a git repository." >&2
        return 1
    end

    # 現在のブランチを取得
    set -l current_branch (git branch --show-current)

    # ローカル + リモートブランチを取得（現在ブランチ除外）
    set -l branches (git branch -a --format='%(refname:short)' | \
        grep -v "^$current_branch\$" | \
        grep -v '^HEAD$' | \
        grep -v '^origin/HEAD$' | \
        sort -u)

    if test (count $branches) -eq 0
        echo "g_switch: No other branches found"
        return 0
    end

    # fzfで選択（プレビュー付き）
    set -l selected (printf '%s\n' $branches | fzf \
        --ansi \
        --prompt="Switch to> " \
        --header="Current: $current_branch | Enter: switch, Esc: cancel" \
        --header-first \
        --preview='git log --oneline --color=always -10 {}' \
        --preview-window=right:50%)

    if test -z "$selected"
        echo "Cancelled."
        return 0
    end

    # origin/プレフィックスを除去
    set -l branch_name (string replace -r '^origin/' '' $selected)

    # worktreeに紐づいているかチェック
    set -l worktree_path (_g_switch_find_worktree $branch_name)

    if test -n "$worktree_path"
        # worktreeが存在する場合はcdで移動
        echo "Switching to worktree: $worktree_path"
        cd $worktree_path
    else
        # worktreeがない場合は通常のgit switch
        git switch $branch_name
    end
end

function _g_switch_find_worktree -a branch_name
    # git worktree list --porcelainの出力を解析
    # 形式:
    #   worktree /path/to/worktree
    #   HEAD abc123
    #   branch refs/heads/branch-name
    set -l current_worktree ""
    for line in (git worktree list --porcelain 2>/dev/null)
        if string match -q "worktree *" $line
            set current_worktree (string replace "worktree " "" $line)
        else if string match -q "branch refs/heads/$branch_name" $line
            echo $current_worktree
            return 0
        end
    end
    return 1
end
