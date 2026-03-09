#!/usr/bin/env bash
# 1-based インデックスで N 番目の Claude セッションに switch-client し @claude_cursor を更新する
# Usage: claude-session-switch.sh <1-based index>

TARGET_IDX="${1:-1}"
STATE_DIR=/tmp/claude-pane-state

# セッション一覧（main/monitor/prtrack を除外）
sessions=()
while IFS= read -r s; do
    sessions+=("$s")
done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -vE '^(main|monitor|prtrack)$')

# Claude セッション（状態ファイルを持つもの）のみ収集
claude_sessions=()
for session in "${sessions[@]}"; do
    has_claude=false
    while IFS= read -r pane_id; do
        pane_num="${pane_id#%}"
        if [ -f "$STATE_DIR/pane_$pane_num" ]; then
            has_claude=true
            break
        fi
    done < <(tmux list-panes -s -t "$session" -F '#{pane_id}' 2>/dev/null)
    $has_claude && claude_sessions+=("$session")
done

# 0-based インデックスに変換して対象セッションを取得
idx=$((TARGET_IDX - 1))
total="${#claude_sessions[@]}"
if [ "$idx" -ge 0 ] && [ "$idx" -lt "$total" ]; then
    tmux set -g @claude_cursor "$idx"
    tmux switch-client -t "${claude_sessions[$idx]}"
fi
