#!/bin/bash
# Ghostty 起動時の tmux セッション初期化スクリプト
# 新しいバックグラウンドセッションを追加する場合はここに記述する

# Ghostty は非ログインシェルで command を実行するため PATH を補完
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# tmux が TMUX 環境変数でセッション検出するためクリアする
unset TMUX

# --- メインセッション（Ghostty のフォアグラウンド） ---
while true; do
    tmux new-session -A -s main
done
