#!/bin/bash
# オーケストレーションワーカーの状態を表示する
# 使い方: claude-sessions-status.sh [session-name]
#   session-name: 特定セッションのみ表示（省略時は全 orch-* セッション）

STATE_DIR="/tmp/claude-pane-state"
target_session="${1:-}"

purple=$(printf '\e[35m')
red=$(printf '\e[31m')
dim=$(printf '\e[2m')
yellow=$(printf '\e[33m')
reset=$(printf '\e[0m')

# orch-* セッション一覧を取得
if [[ -n "$target_session" ]]; then
    sessions=("$target_session")
else
    mapfile -t sessions < <(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep '^orch-')
fi

if [[ ${#sessions[@]} -eq 0 ]]; then
    echo "  (オーケストレーション実行中なし)"
    exit 0
fi

for session in "${sessions[@]}"; do
    echo "${yellow}${session}${reset}"

    while IFS=: read -r win_idx win_name; do
        [[ -z "$win_idx" ]] && continue

        # ウィンドウのペインIDを取得
        pane_id=$(tmux list-panes -t "${session}:${win_idx}" -F '#{pane_id}' 2>/dev/null | head -1)
        pane_num="${pane_id#%}"

        # 状態ファイルを読む
        state_file="$STATE_DIR/pane_${pane_num}"
        role_file="$STATE_DIR/pane_${pane_num}_role"
        started_file="$STATE_DIR/pane_${pane_num}_started"

        state=""
        role="$win_name"

        if [[ -f "$role_file" ]]; then
            role=$(cat "$role_file")
        fi

        if [[ -f "$state_file" ]]; then
            state=$(cat "$state_file")
        fi

        # 経過時間計算
        elapsed=""
        if [[ "$state" == "running" && -f "$started_file" ]]; then
            started_ts=$(cat "$started_file")
            now=$(date +%s)
            elapsed_sec=$(( now - started_ts ))
            elapsed_min=$(( elapsed_sec / 60 ))
            if [[ $elapsed_min -ge 1 ]]; then
                elapsed=" ${elapsed_min}m"
            fi
        fi

        # 状態バッジ
        badge=""
        case "$state" in
            running)    badge="${purple}[running${elapsed}]${reset}" ;;
            permission) badge="${red}[perm]${reset}" ;;
            ask)        badge="${red}[ask]${reset}" ;;
            idle)       badge="${dim}[idle]${reset}" ;;
            *)          badge="${dim}[--]${reset}" ;;
        esac

        printf "  %s  %-20s %s(pane %s)\n" \
            "$badge" "$role" "${dim}" "${pane_num}${reset}"
    done < <(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null)

    echo ""
done
