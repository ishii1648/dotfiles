#!/bin/bash

# Claude Code Hook: macOS デスクトップ通知（terminal-notifier 経由）
# Stop / Notification イベントで発火し、tmux セッション情報付きで通知する

read -r input
event_type=$(echo "$input" | /opt/homebrew/bin/jq -r '.hook_event_name // "unknown"')

# tmux 外では何もしない
[ -z "$TMUX" ] && exit 0

SESSION=$(/opt/homebrew/bin/tmux display-message -p '#{session_name}')
WINDOW=$(/opt/homebrew/bin/tmux display-message -p '#{window_index}')
PANE=$(/opt/homebrew/bin/tmux display-message -p '#{pane_index}')
WINDOW_NAME=$(/opt/homebrew/bin/tmux display-message -p '#{window_name}')

case "$event_type" in
  "Stop")         TITLE="Claude Code: done";         MESSAGE="Task completed ($SESSION:$WINDOW_NAME)" ;;
  "Notification") TITLE="Claude Code: input needed";  MESSAGE="Waiting for input ($SESSION:$WINDOW_NAME)" ;;
  *)              TITLE="Claude Code";                 MESSAGE="$SESSION:$WINDOW_NAME" ;;
esac

/opt/homebrew/bin/terminal-notifier \
  -title "$TITLE" \
  -message "$MESSAGE" \
  -sound default \
  -group "claude-$SESSION-$WINDOW-$PANE"
