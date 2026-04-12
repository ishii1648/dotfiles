#!/bin/bash
# dispatch-new-worker-window <session-name> <window-name> <worktree-path>
#
# tmux ウィンドウを作成し、ペイン role ファイルを書き込む。
# サイドバーは after-new-window グローバルフックが自動起動するため、
# このスクリプトでは split-window を実行しない。

set -e

SESSION="$1"
WINDOW="$2"
WORKTREE="$3"

if [ -z "$SESSION" ] || [ -z "$WINDOW" ] || [ -z "$WORKTREE" ]; then
  echo "Usage: dispatch-new-worker-window <session-name> <window-name> <worktree-path>" >&2
  exit 1
fi

tmux new-window -t "$SESSION" -n "$WINDOW" -c "$WORKTREE"

PANE_ID=$(tmux display-message -p -t "${SESSION}:${WINDOW}" "#{pane_id}")
PANE_NUM="${PANE_ID#%}"

mkdir -p /tmp/claude-pane-state
echo "$WINDOW" > "/tmp/claude-pane-state/pane_${PANE_NUM}_role"

echo "$PANE_ID"
