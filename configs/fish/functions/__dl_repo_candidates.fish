function __dl_repo_candidates --description 'dispatch_launcher 用 ghq リポジトリ候補を出力'
    set -l ghq_root (ghq root)
    ghq list -p | while read -l repo
        string match -q '*@*' $repo; and continue
        set -l short (string replace "$ghq_root/" '' $repo)
        printf '\t%s\n' $short
    end
end
