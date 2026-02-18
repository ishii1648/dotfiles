function __tm_claude_state --description 'ウィンドウ内のClaudeペイン状態を取得'
    set -l session $argv[1]
    set -l win_idx $argv[2]
    set -l state_dir /tmp/claude-pane-state

    test -d $state_dir; or return

    set -l best_priority 0
    set -l best_state ''
    set -l best_elapsed ''
    set -l best_pane_num ''

    for pane_id in (tmux list-panes -t "$session:$win_idx" -F '#{pane_id}' 2>/dev/null)
        set -l pane_num (string replace '%' '' $pane_id)
        set -l state_file "$state_dir/pane_$pane_num"
        if test -f $state_file
            # ペインのフォアグラウンドがシェルなら Claude 終了済み → stale file を除去
            set -l pane_cmd (tmux display-message -p -t "$pane_id" '#{pane_current_command}' 2>/dev/null)
            if contains -- $pane_cmd fish bash zsh
                rm -f $state_file "$state_dir/pane_"$pane_num"_started"
                continue
            end
            set -l state (string trim < $state_file)
            # running だがペインに15秒以上出力がない → Stop未発火の stale running
            if test "$state" = running
                set -l pane_idle (tmux display-message -p -t "$pane_id" '#{pane_idle}' 2>/dev/null)
                if test -n "$pane_idle" -a "$pane_idle" -gt 15
                    set state idle
                    echo idle > $state_file
                    rm -f "$state_dir/pane_"$pane_num"_started"
                end
            end
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
                set best_pane_num $pane_num
            end
        end
    end

    if test -n "$best_state"
        set -l elapsed ''
        if test "$best_state" = running -a -n "$best_pane_num"
            set -l started_file "$state_dir/pane_"$best_pane_num"_started"
            if test -f $started_file
                set -l started_ts (string trim < $started_file)
                if test -n "$started_ts"
                    set -l now (date +%s)
                    set -l elapsed_sec (math $now - $started_ts)
                    set -l elapsed_min (math "floor($elapsed_sec / 60)")
                    if test $elapsed_min -ge 1
                        set elapsed $elapsed_min
                    end
                end
            end
        end
        if test -n "$elapsed"
            echo "$best_state $elapsed"
        else
            echo $best_state
        end
    end
end
