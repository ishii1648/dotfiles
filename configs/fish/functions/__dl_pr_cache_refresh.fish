function __dl_pr_cache_refresh --description 'gh search prs + gh pr list で PR worktree キャッシュを更新'
    set -l cache_file /tmp/dl-pr-worktrees.cache
    set -l tmp_file (mktemp /tmp/dl-pr-worktrees.cache.XXXXXX)
    set -l ghq_root (ghq root)

    # Step 1: gh search prs で自分の open PR があるリポジトリを特定
    set -l search_json (gh search prs --author=@me --state=open --json repository --limit 200 2>/dev/null)
    if test $status -ne 0
        rm -f $tmp_file
        return 1
    end

    set -l repos (echo $search_json | jq -r '[.[].repository.nameWithOwner] | unique | .[]')

    # Step 2: 各リポジトリの gh pr list（全状態）で worktree とマッチング
    # cache format: wt_path\tpr_number\tpr_state\trepo_name\tbranch
    # pr_state: draft / open / merged / closed
    for repo_full in $repos
        set -l pr_json (gh pr list --repo $repo_full --author @me --state all --json headRefName,number,isDraft,state --limit 100 2>/dev/null)
        test $status -ne 0; and continue

        echo $pr_json | jq -r '.[] | [.headRefName, (.number | tostring), (if .isDraft then "draft" elif .state == "MERGED" then "merged" elif .state == "CLOSED" then "closed" else "open" end)] | @tsv' | while read -l branch pr_number pr_state
            set -l wt_dir_name (string replace -a '/' '-' $branch)
            set -l repo_name (string split '/' $repo_full)[-1]
            for host_dir in $ghq_root/*/
                set -l wt_path "$host_dir$repo_full@$wt_dir_name"
                if test -d "$wt_path"
                    printf '%s\t%s\t%s\t%s\t%s\n' $wt_path $pr_number $pr_state $repo_name $branch >> $tmp_file
                    break
                end
            end
        end
    end

    mv $tmp_file $cache_file
end
