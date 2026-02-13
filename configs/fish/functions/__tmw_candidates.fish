function __tmw_candidates --description 'ghqリポジトリ候補を一覧表示（メインリポジトリのみ）'
    set -l ghq_root (ghq root)

    for repo in (ghq list -p)
        # worktreeディレクトリ（@を含むパス）を除外
        string match -q '*@*' $repo; and continue
        set -l repo_rel (string replace "$ghq_root/" '' $repo)
        printf '%s\t%s\n' $repo $repo_rel
    end
end
