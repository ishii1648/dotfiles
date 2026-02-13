function gh_rate_limit --description "Display GitHub API rate limit usage"
    set -l json (gh api rate_limit 2>&1)
    if test $status -ne 0
        echo "Error: failed to fetch rate limit" >&2
        echo $json >&2
        return 1
    end

    set -l resources core search graphql code_search
    set -l labels "REST API" "Search API" "GraphQL API" "Code Search API"

    printf "%-25s %7s %7s %7s  %s\n" "Resource" "Limit" "Used" "Remain" "Reset"
    printf "%-25s %7s %7s %7s  %s\n" "-------------------------" "-------" "-------" "-------" "-------------------"

    set -l i 0
    for resource in $resources
        set i (math $i + 1)
        set -l label $labels[$i]

        set -l limit (echo $json | jq -r ".resources.$resource.limit // empty")
        test -z "$limit"; and continue

        set -l used (echo $json | jq -r ".resources.$resource.used")
        set -l remaining (echo $json | jq -r ".resources.$resource.remaining")
        set -l reset_epoch (echo $json | jq -r ".resources.$resource.reset")
        set -l reset_time (date -r $reset_epoch "+%Y-%m-%d %H:%M:%S")

        if test $remaining -eq 0
            printf "%-25s %7s %7s \033[31m%7s\033[0m  %s\n" $label $limit $used $remaining $reset_time
        else if test $remaining -le (math "$limit / 5")
            printf "%-25s %7s %7s \033[33m%7s\033[0m  %s\n" $label $limit $used $remaining $reset_time
        else
            printf "%-25s %7s %7s \033[32m%7s\033[0m  %s\n" $label $limit $used $remaining $reset_time
        end
    end

    echo ""
    printf "\033[2m"
    echo "API Reference:"
    echo "  REST API        - RESTエンドポイント全般  e.g. gh api repos/{owner}/{repo}"
    echo "  Search API      - 検索エンドポイント      e.g. gh search repos, gh search issues"
    echo "  GraphQL API     - GraphQLクエリ           e.g. gh api graphql -f query='...'"
    echo "  Code Search API - コード検索              e.g. gh search code 'fmt.Println'"
    printf "\033[0m"
end
