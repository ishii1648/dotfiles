#!/bin/bash
# Ghostty 起動時の tmux セッション初期化スクリプト
# 新しいバックグラウンドセッションを追加する場合はここに記述する

TMUX=/opt/homebrew/bin/tmux

# --- バックグラウンドセッション ---
$TMUX new-session -d -s prtrack "prtrack" 2>/dev/null
$TMUX set-option -t prtrack detach-on-destroy on 2>/dev/null

# --- メインセッション（Ghostty のフォアグラウンド） ---
while true; do
    $TMUX new-session -A -s main
done
