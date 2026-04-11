function claude-sidebar-create
    # Claude サイドバーを作成する（存在しない場合のみ）(ADR-050)
    # after-new-window フックから呼ばれる

    # 既にサイドバーが存在する場合は何もしない
    set -l sidebar_pane (tmux list-panes -F "#{pane_id}" -f "#{==:#{@pane_role},sidebar}" 2>/dev/null | head -1)
    test -n "$sidebar_pane"; and return 0

    # サイドバーなし → 作成
    set -l leftmost_info (tmux list-panes -F "#{pane_left}:#{pane_id}" | sort -n -t: | head -1)
    set -l leftmost (string split ":" -- $leftmost_info)[2]
    set -l new_pane (tmux split-window -hfb -l 22% -t $leftmost -P -F "#{pane_id}" "fish -l -c claude-sidebar")
    tmux set-option -p -t $new_pane @pane_role sidebar
end
