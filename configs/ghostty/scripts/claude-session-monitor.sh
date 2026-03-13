#!/bin/bash
# Claude セッション状態モニター
# Ghostty 左ペインで常時表示する。/tmp/claude-pane-state/ を 2 秒ごとに読み取り
# 全 tmux セッションの Claude ウィンドウ状態を表示する。

STATE_DIR=/tmp/claude-pane-state

badge() {
    case "$1" in
        permission) printf '\033[31m[perm]\033[0m' ;;
        ask)        printf '\033[31m[ask ]\033[0m' ;;
        running)    printf '\033[35m[run ]\033[0m' ;;
        idle)       printf '\033[2m[idle]\033[0m' ;;
        *)          printf '[----]' ;;
    esac
}

while true; do
    # 画面クリア
    printf '\033[2J\033[H'
    printf '\033[1mClaude\033[0m\n'
    printf '──────────────────────\n'

    found=0

    # 全セッション・全ウィンドウを走査
    while IFS= read -r line; do
        session="${line%%:*}"
        rest="${line#*:}"
        win_idx="${rest%% *}"
        win_name="${rest#* }"

        best_state=""
        best_priority=0

        # ウィンドウ内の全ペインを確認
        while IFS= read -r pane_id; do
            pane_num="${pane_id#%}"
            state_file="$STATE_DIR/pane_$pane_num"
            [ -f "$state_file" ] || continue

            state=$(tr -d '[:space:]' < "$state_file")
            priority=0
            case "$state" in
                permission) priority=4 ;;
                ask)        priority=3 ;;
                running)    priority=2 ;;
                idle)       priority=1 ;;
            esac
            if [ "$priority" -gt "$best_priority" ]; then
                best_priority=$priority
                best_state=$state
            fi
        done < <(tmux list-panes -t "${session}:${win_idx}" -F '#{pane_id}' 2>/dev/null)

        if [ -n "$best_state" ]; then
            badge "$best_state"
            # 幅が狭いため win_name を 14 文字に切り詰め
            printf ' %.14s\n' "$win_name"
            found=1
        fi
    done < <(tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}' 2>/dev/null)

    if [ "$found" -eq 0 ]; then
        printf '\033[2m(no sessions)\033[0m\n'
    fi

    sleep 2
done
