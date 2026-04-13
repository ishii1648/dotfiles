function __dl_pr_cache_refresh --description 'gh search prs で PR worktree キャッシュを更新'
    set -l cache_file /tmp/dl-pr-worktrees.cache
    set -l tmp_file (mktemp /tmp/dl-pr-worktrees.cache.XXXXXX)
    set -l ghq_root (ghq root)

    # gh search prs で自分の open PR を一括取得
    set -l json_output (gh search prs --author=@me --state=open --json repository,headRefName,number,isDraft --limit 100 2>/dev/null)
    if test $status -ne 0
        rm -f $tmp_file
        return 1
    end

    # JSON をパースしてローカル worktree とマッチング
    echo $json_output | jq -r '.[] | [.repository.nameWithOwner, .headRefName, (.number | tostring), (.isDraft | tostring)] | @tsv' | while read -l repo_full branch pr_number is_draft
        # headRefName の / を - に変換して worktree ディレクトリ名を導出
        set -l wt_dir_name (string replace -a '/' '-' $branch)
        # ghq 配下の全ホスト候補を探索（github.com が大半だが一応）
        set -l repo_name (string split '/' $repo_full)[-1]
        for host_dir in $ghq_root/*/
            set -l wt_path "$host_dir$repo_full@$wt_dir_name"
            if test -d "$wt_path"
                set -l repo_short (basename (dirname $wt_path))"/"$repo_name"@"$wt_dir_name
                printf '%s\t%s\t%s\t%s\n' $wt_path $pr_number $is_draft $repo_short >> $tmp_file
                break
            end
        end
    end

    # アトミック書き込み
    mv $tmp_file $cache_file
end
