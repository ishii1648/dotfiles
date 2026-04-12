function dispatch_launcher --description 'dispatch/orchestrate popup ランチャー（2段階フロー）'
    # ADR-056: dispatch/orchestrate popup ランチャー
    # Step 1: リポジトリ選択 + モード切替（ctrl-t）
    # Step 2: タスク記述入力
    # → dispatch.sh launch または orchestrate 起動

    set -l mode dispatch
    set -l ghq_root (ghq root)

    # Step 1: リポジトリ選択 + モード切替ループ
    while true
        set -l result (ghq list -p | while read -l repo
            string match -q '*@*' $repo; and continue
            string replace "$ghq_root/" '' $repo
        end | fzf \
            --prompt "$mode > " \
            --header 'ctrl-t: dispatch/orchestrate 切替' \
            --expect 'ctrl-t' \
            --layout=reverse --cycle)

        if test (count $result) -eq 0
            return 0
        end

        set -l key $result[1]
        set -l selected $result[2]

        if test "$key" = ctrl-t
            if test "$mode" = dispatch
                set mode orchestrate
            else
                set mode dispatch
            end
            continue
        end

        if test -z "$selected"
            return 0
        end

        # Step 2: タスク記述入力
        read -P "$mode > "(basename $selected)": " prompt_text

        if test -z "$prompt_text"
            return 0
        end

        # ブランチ名を prompt から生成
        set -l slug (echo $prompt_text | string replace -ar '[^a-zA-Z0-9]' '-' | string replace -ar '-+' '-' | string trim -c '-' | string sub -l 40 | string lower)
        set -l branch_name "feat/$slug"

        if test "$mode" = dispatch
            bash ~/.claude/skills/dispatch/dispatch.sh launch "$selected" "$prompt_text" --branch "$branch_name"
        else
            # orchestrate: tmux session を作成して claude に /orchestrate を投入
            set -l repo_path "$ghq_root/$selected"
            set -l session_name (basename $selected)

            set -l win_w (tmux display-message -p '#{window_width}')
            set -l win_h (tmux display-message -p '#{window_height}')

            if not tmux has-session -t "=$session_name" 2>/dev/null
                tmux new-session -d -s "$session_name" -c "$repo_path" -x $win_w -y $win_h
            end

            # claude を起動して /orchestrate コマンドを投入
            sleep 0.5
            tmux send-keys -t "=$session_name" "printf '/orchestrate feature \"$prompt_text\"' | claude" Enter
        end

        return 0
    end
end
