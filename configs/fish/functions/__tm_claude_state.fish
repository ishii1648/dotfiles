function __tm_claude_state --description 'ウィンドウ内のClaudeペイン状態を取得'
    set -l session $argv[1]
    set -l win_idx $argv[2]
    set -l state_dir /tmp/claude-pane-state

    test -d $state_dir; or return

    set -l best_priority 0
    set -l best_state ''

    for pane_id in (tmux list-panes -t "$session:$win_idx" -F '#{pane_id}' 2>/dev/null)
        set -l pane_num (string replace '%' '' $pane_id)
        set -l state_file "$state_dir/pane_$pane_num"
        if test -f $state_file
            set -l state (string trim < $state_file)
            set -l priority 0
            switch $state
                case permission; set priority 4
                case ask;        set priority 3
                case running;    set priority 2
                case idle;       set priority 1
            end
            if test $priority -gt $best_priority
                set best_priority $priority
                set best_state $state
            end
        end
    end

    test -n "$best_state"; and echo $best_state
end
