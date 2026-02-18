function __tm_worktree_candidates --description 'worktree候補一覧を生成（TAB区切り: key\t表示テキスト）'
    set -l ghq_root (ghq root)
    set -l existing_sessions (tmux list-sessions -F '#{session_name}' 2>/dev/null)
    set -l current_session (tmux display-message -p '#{session_name}' 2>/dev/null)
    set -l green (printf '\e[32m')
    set -l yellow (printf '\e[33m')
    set -l dim (printf '\e[2m')
    set -l reset (printf '\e[0m')

    for repo in (ghq list -p)
        # worktreeディレクトリ（@を含むパス）を除外 → メインリポのみ
        string match -q '*@*' $repo; and continue

        set -l repo_rel (string replace "$ghq_root/" '' $repo)

        # git worktree list: 最初の行はメインworktreeなのでスキップ
        set -l wt_lines (git -C $repo worktree list 2>/dev/null)
        if test (count $wt_lines) -le 1
            continue
        end

        for i in (seq 2 (count $wt_lines))
            set -l line $wt_lines[$i]
            # パース: /path/to/worktree  abc1234 [branch-name]
            set -l wt_path (string match -r '^(\S+)' $line)[2]
            set -l wt_branch (string match -r '\[(.+)\]' $line)[2]

            if test -z "$wt_path"
                continue
            end

            set -l session_name (basename $wt_path)
            set -l display_branch ""
            if test -n "$wt_branch"
                set display_branch " [$wt_branch]"
            end

            if test "$session_name" = "$current_session"
                printf '%s\t%s\n' $wt_path "$green$session_name  $repo_rel$display_branch$reset"
            else if contains $session_name $existing_sessions
                printf '%s\t%s\n' $wt_path "$yellow$session_name  $repo_rel$display_branch$reset"
            else
                printf '%s\t%s\n' $wt_path "$session_name  $dim$repo_rel$display_branch$reset"
            end
        end
    end
end
