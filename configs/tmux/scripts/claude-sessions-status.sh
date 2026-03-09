#!/usr/bin/env bash
# Claude ウィンドウ状態をステータスバー用にフォーマットして出力する（ウィンドウ単位）
# /tmp/claude-pane-state/ の状態ファイルと tmux グローバル変数を読み取る

STATE_DIR=/tmp/claude-pane-state

cursor=$(tmux show -gv @claude_cursor 2>/dev/null)
cursor=${cursor:-0}
cursor_mode=$(tmux show -gv @claude_cursor_mode 2>/dev/null)
cursor_mode=${cursor_mode:-off}

# 現在アクティブなセッション:ウィンドウ
current=$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null)

# セッション一覧（main/monitor/prtrack を除外）
sessions=()
while IFS= read -r s; do
    sessions+=("$s")
done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -vE '^(main|monitor|prtrack)$')

# ウィンドウ単位で Claude 状態を収集
claude_sessions=()
claude_windows=()
claude_states=()
claude_elapseds=()

for session in "${sessions[@]}"; do
    while IFS=: read -r win_idx win_name; do
        best_priority=0
        best_state=""
        best_elapsed=""

        while IFS= read -r pane_id; do
            pane_num="${pane_id#%}"
            state_file="$STATE_DIR/pane_$pane_num"
            [ -f "$state_file" ] || continue

            state=$(tr -d '[:space:]' < "$state_file")
            case "$state" in
                permission) priority=4 ;;
                ask)        priority=3 ;;
                running)    priority=2 ;;
                idle)       priority=1 ;;
                *)          continue ;;
            esac

            if [ "$priority" -gt "$best_priority" ]; then
                best_priority=$priority
                best_state="$state"
                best_elapsed=""
                if [ "$state" = "running" ]; then
                    started_file="$STATE_DIR/pane_${pane_num}_started"
                    if [ -f "$started_file" ]; then
                        started_ts=$(tr -d '[:space:]' < "$started_file")
                        if [ -n "$started_ts" ]; then
                            now=$(date +%s)
                            elapsed_min=$(( (now - started_ts) / 60 ))
                            [ "$elapsed_min" -ge 1 ] && best_elapsed="${elapsed_min}m"
                        fi
                    fi
                fi
            fi
        done < <(tmux list-panes -t "${session}:${win_idx}" -F '#{pane_id}' 2>/dev/null)

        [ -z "$best_state" ] && continue

        claude_sessions+=("$session")
        claude_windows+=("${win_idx}:${win_name}")
        claude_states+=("$best_state")
        claude_elapseds+=("$best_elapsed")
    done < <(tmux list-windows -t "$session" -F '#{window_index}:#{window_name}' 2>/dev/null)
done

# Claude ウィンドウが存在しない場合は空文字で終了
[ "${#claude_sessions[@]}" -eq 0 ] && echo "" && exit 0

# カーソルをクランプ（ウィンドウ数の増減で範囲外になった場合）
total="${#claude_sessions[@]}"
if [ "$cursor" -ge "$total" ]; then
    cursor=$((total - 1))
    tmux set -g @claude_cursor "$cursor" 2>/dev/null
fi

# 出力を組み立て
output=""
for i in "${!claude_sessions[@]}"; do
    session="${claude_sessions[$i]}"
    win="${claude_windows[$i]}"
    win_idx="${win%%:*}"
    state="${claude_states[$i]}"
    elapsed="${claude_elapseds[$i]}"

    # popup と同形式のバッジ
    case "$state" in
        running)    [ -n "$elapsed" ] && badge="[running(${elapsed})]" || badge="[running]" ;;
        permission) badge="[perm]" ;;
        ask)        badge="[ask]" ;;
        idle)       badge="[idle]" ;;
        *)          badge="" ;;
    esac

    # アクティブウィンドウ判定
    is_active=false
    [ "${session}:${win_idx}" = "$current" ] && is_active=true

    # カーソルモード中はカーソル位置を ( ) でハイライト
    cursor_open=""; cursor_close=""
    [ "$cursor_mode" = "on" ] && [ "$i" = "$cursor" ] && cursor_open="(" && cursor_close=")"

    # セッション名（常に緑）・バッジ（状態別色）を分けて色付け
    case "$state" in
        running)        badge_color="#bd93f9" ;;  # purple（popup と同じ）
        permission|ask) badge_color="#ff5555" ;;  # red（popup と同じ）
        idle)           badge_color="#6272a4" ;;  # dim
        *)              badge_color="#f8f8f2" ;;
    esac

    if $is_active; then
        # アクティブ: セッション名を緑 bold
        colored="${cursor_open}#[fg=#50fa7b,bold]${session}:${win_idx}#[default] #[fg=${badge_color}]${badge}#[default]${cursor_close}"
    else
        colored="${cursor_open}#[fg=#50fa7b]${session}:${win_idx}#[default] #[fg=${badge_color}]${badge}#[default]${cursor_close}"
    fi

    [ -z "$output" ] && output="$colored" || output="${output}#[fg=#44475a] | #[default]${colored}"
done

echo "$output"
