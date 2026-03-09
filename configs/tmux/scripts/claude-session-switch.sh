#!/usr/bin/env bash
# 1-based インデックスで N 番目の Claude ウィンドウに switch-client + select-window する
# @claude_cursor を更新する
# Usage: claude-session-switch.sh <1-based index>

TARGET_IDX="${1:-1}"
STATE_DIR=/tmp/claude-pane-state

# セッション一覧（main/monitor/prtrack を除外）
sessions=()
while IFS= read -r s; do
    sessions+=("$s")
done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -vE '^(main|monitor|prtrack)$')

# ウィンドウ単位で Claude ウィンドウを収集（status スクリプトと同順）
claude_sessions=()
claude_win_idxs=()

for session in "${sessions[@]}"; do
    while IFS=: read -r win_idx win_name; do
        has_claude=false
        while IFS= read -r pane_id; do
            pane_num="${pane_id#%}"
            if [ -f "$STATE_DIR/pane_$pane_num" ]; then
                has_claude=true
                break
            fi
        done < <(tmux list-panes -t "${session}:${win_idx}" -F '#{pane_id}' 2>/dev/null)

        if $has_claude; then
            claude_sessions+=("$session")
            claude_win_idxs+=("$win_idx")
        fi
    done < <(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null)
done

# 0-based インデックスに変換して対象ウィンドウを取得
idx=$((TARGET_IDX - 1))
total="${#claude_sessions[@]}"
if [ "$idx" -ge 0 ] && [ "$idx" -lt "$total" ]; then
    target_session="${claude_sessions[$idx]}"
    target_win="${claude_win_idxs[$idx]}"
    tmux set -g @claude_cursor "$idx"
    tmux switch-client -t "$target_session"
    tmux select-window -t "${target_session}:${target_win}"
fi
