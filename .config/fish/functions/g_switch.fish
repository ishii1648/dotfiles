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

    # origin/プレフィックスを除去してswitch
    set -l branch_name (string replace -r '^origin/' '' $selected)
    git switch $branch_name
end
