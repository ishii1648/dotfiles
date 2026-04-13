#!/bin/bash
# prtrack セッション管理スクリプト
# $TMUX 環境変数からソケットパスを取得して prtrack セッションを管理し、切り替える

SOCK="${TMUX%%,*}"

if ! TMUX= tmux -S "$SOCK" has-session -t prtrack 2>/dev/null; then
  TMUX= tmux -S "$SOCK" new-session -d -s prtrack 'fish -i -l'
  TMUX= tmux -S "$SOCK" set-option -t prtrack detach-on-destroy off
fi

# prtrack プロセスが動いていなければ起動
if ! TMUX= tmux -S "$SOCK" list-panes -t prtrack -F '#{pane_current_command}' 2>/dev/null | grep -q '^prtrack$'; then
  TMUX= tmux -S "$SOCK" send-keys -t prtrack 'prtrack' Enter
fi

TMUX= tmux -S "$SOCK" switch-client -t prtrack
