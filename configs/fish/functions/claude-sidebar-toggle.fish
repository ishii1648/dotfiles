function claude-sidebar-toggle
    # Claude サイドバーの toggle (ADR-050)
    # prefix+e から呼ばれる: サイドバーが存在すれば kill、なければ作成

    # 現在のウィンドウ内のサイドバー pane を検索
    set -l sidebar_pane (tmux list-panes -F "#{pane_id}" -f "#{==:#{@pane_role},sidebar}" 2>/dev/null | head -1)

    if test -n "$sidebar_pane"
        # サイドバー存在 → 削除
        tmux kill-pane -t $sidebar_pane
    else
        # サイドバーなし → 作成
        set -l leftmost_info (tmux list-panes -F "#{pane_left}:#{pane_id}" | sort -n -t: | head -1)
        set -l leftmost (string split ":" -- $leftmost_info)[2]
        set -l new_pane (tmux split-window -hfb -l 22% -t $leftmost -P -F "#{pane_id}" "fish -l -c claude-sidebar")
        tmux set-option -p -t $new_pane @pane_role sidebar
    end
end
