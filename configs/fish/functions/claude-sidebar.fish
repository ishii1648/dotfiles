function claude-sidebar
    # Claude Code サイドバー表示スクリプト
    # tmux split-window -hfb で起動して常駐する (ADR-050)
    # /tmp/claude-pane-state/pane_N を 1 秒ポーリングして各 pane の状態を表示

    set -l state_dir /tmp/claude-pane-state

    while true
        # カーソルを左上に移動してから上書き（ちらつき防止）
        tput cup 0 0

        printf "\033[1;36m Claude Sessions\033[0m\n"
        printf " ─────────────────\n"

        set -l has_entry false

        for f in $state_dir/pane_*
            # _started サフィックスのファイルはスキップ
            string match -q "*_started" $f; and continue
            test -f $f; or continue

            set -l pane_num (basename $f | string replace "pane_" "")
            set -l pane_id "%$pane_num"
            set -l state (cat $f 2>/dev/null)
            test -z "$state"; and continue

            # pane が実際に存在するか確認し、session:window 情報を取得
            set -l pane_info (tmux list-panes -a -F "#{pane_id} #{session_name}:#{window_name}" 2>/dev/null | string match -r "^$pane_id .*")
            test -z "$pane_info"; and continue

            set -l location (string split " " -- $pane_info)[2]
            set has_entry true

            switch $state
                case running
                    printf " \033[32m▶\033[0m %-20s \033[32mrunning\033[0m\n" $location
                case permission
                    printf " \033[33m!\033[0m %-20s \033[33mpermission\033[0m\n" $location
                case ask
                    printf " \033[33m?\033[0m %-20s \033[33mask\033[0m\n" $location
                case idle
                    printf " \033[34m○\033[0m %-20s \033[34midle\033[0m\n" $location
                case '*'
                    printf " \033[90m·\033[0m %-20s \033[90m%s\033[0m\n" $location $state
            end
        end

        if test $has_entry = false
            printf " \033[90m(no active sessions)\033[0m\n"
        end

        # 前回の出力が長かった場合に残りの行をクリア
        tput ed
        sleep 1
    end
end
