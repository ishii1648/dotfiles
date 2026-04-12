function dispatch_launcher --description 'dispatch/orchestrate popup ランチャー（2段階フロー）'
    # ADR-056: dispatch/orchestrate popup ランチャー
    # Step 1: リポジトリ選択（fzf）
    # Step 2: タスク記述入力（read） + tab で dispatch/orchestrate 切替

    set -l ghq_root (ghq root)

    # Step 1: リポジトリ選択
    set -l selected (ghq list -p | while read -l repo
        string match -q '*@*' $repo; and continue
        string replace "$ghq_root/" '' $repo
    end | fzf \
        --prompt 'repo > ' \
        --layout=reverse --cycle)

    if test -z "$selected"
        return 0
    end

    # Step 2: タスク記述 + tab でモード切替
    set -g _dl_mode dispatch
    set -g _dl_repo (basename $selected)

    function _dl_prompt
        # ヘッダー行
        set_color brblack
        printf '  tab: モード切替  enter: 実行\n'
        set_color normal

        # モード + リポジトリ表示
        printf '  '
        if test "$_dl_mode" = dispatch
            set_color --bold brgreen
            printf 'dispatch'
            set_color normal brblack
            printf ' / orchestrate'
        else
            set_color normal brblack
            printf 'dispatch / '
            set_color --bold brmagenta
            printf 'orchestrate'
        end
        set_color normal
        printf '  %s\n' $_dl_repo

        # 入力プロンプト
        set_color brblack
        printf '  ─────────────────────────────\n'
        set_color normal
        printf '  > '
    end

    function _dl_toggle
        if test "$_dl_mode" = dispatch
            set -g _dl_mode orchestrate
        else
            set -g _dl_mode dispatch
        end
        commandline -f repaint
    end

    bind \t _dl_toggle
    read -p _dl_prompt prompt_text
    bind -e \t

    set -l mode $_dl_mode
    set -e _dl_mode _dl_repo
    functions -e _dl_prompt _dl_toggle

    if test -z "$prompt_text"
        return 0
    end

    set -l repo_name (basename $selected)
    set -l slug (echo $prompt_text | string replace -ar '[^a-zA-Z0-9]' '-' | string replace -ar -- '-+' '-' | string trim -c '-' | string sub -l 40 | string lower)
    set -l branch_name "feat/$slug"

    # 進行中通知（popup が閉じた後にステータスバーに表示）
    tmux display-message "$mode: $repo_name ... launching"

    if test "$mode" = dispatch
        bash ~/.claude/skills/dispatch/dispatch.sh launch "$selected" "$prompt_text" --branch "$branch_name" > /dev/null 2>&1

        set -l wt_name (string replace -a '/' '-' $branch_name)
        set -l target_session "$repo_name@$wt_name"
        tmux switch-client -t "=$target_session" 2>/dev/null
    else
        set -l repo_path "$ghq_root/$selected"
        set -l session_name $repo_name
        set -l win_w (tmux display-message -p '#{window_width}')
        set -l win_h (tmux display-message -p '#{window_height}')

        if not tmux has-session -t "=$session_name" 2>/dev/null
            tmux new-session -d -s "$session_name" -c "$repo_path" -x $win_w -y $win_h
        end

        sleep 1
        set -l target_pane (tmux list-panes -t "=$session_name" -F '#{pane_id} #{@pane_role}' | string match -v '*sidebar*' | head -1 | string split ' ')[1]
        if test -z "$target_pane"
            set target_pane (tmux list-panes -t "=$session_name" -F '#{pane_id}' | tail -1)
        end
        tmux send-keys -t "$target_pane" "printf '/orchestrate feature \"$prompt_text\"' | claude" Enter
        tmux switch-client -t "=$session_name"
    end
end
