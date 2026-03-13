#!/bin/bash
# Ghostty 起動時の tmux セッション初期化スクリプト
# 新しいバックグラウンドセッションを追加する場合はここに記述する

# Ghostty は非ログインシェルで command を実行するため PATH を補完
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# tmux が TMUX 環境変数でセッション検出するためクリアする
unset TMUX

# --- Claude セッションサイドバー（左ペイン）を起動 ---
# Ghostty ウィンドウが描画されるまで待機してから AppleScript で左右分割する。
# window-save-state = always との二重生成を防ぐため、既にサイドバーが存在する場合はスキップ。
sleep 0.5
osascript <<'APPLESCRIPT'
tell application "Ghostty"
    set currentTab to selected tab of front window
    -- 既にサイドバーが存在する場合はスキップ（window-save-state = always との二重生成防止）
    if (count of terminals of currentTab) > 1 then return
    set currentTerm to focused terminal of currentTab
    set conf to new surface configuration
    set command of conf to (POSIX path of (path to home folder)) & ".local/bin/claude-session-monitor"
    set leftTerm to split currentTerm direction left with configuration conf
    focus currentTerm
end tell
APPLESCRIPT

# --- メインセッション（Ghostty のフォアグラウンド） ---
while true; do
    tmux new-session -A -s main
done
