#!/bin/bash
# dispatch-new-worker-window <session-name> <window-name> <worktree-path> [<workflow-session-id> <repo-root>]
#
# tmux ウィンドウを作成し、ペイン role ファイルを書き込む。
# workflow-session-id と repo-root が指定された場合は SessionStart hook 用の
# ペンディングコンテキストファイルを ~/.workflow-sessions/pending/pane-<N>.json に書き込む。
# サイドバーは after-new-window グローバルフックが自動起動するため、
# このスクリプトでは split-window を実行しない。

set -e

SESSION="$1"
WINDOW="$2"
WORKTREE="$3"
WORKFLOW_SESSION_ID="${4:-}"
REPO_ROOT="${5:-}"

if [ -z "$SESSION" ] || [ -z "$WINDOW" ] || [ -z "$WORKTREE" ]; then
  echo "Usage: dispatch-new-worker-window <session-name> <window-name> <worktree-path> [<workflow-session-id> <repo-root>]" >&2
  exit 1
fi

# 呼び出し元のウィンドウを記録（popup 等からの呼び出しでフォーカスを戻すため）
CURRENT_WINDOW=$(tmux display-message -p "#{window_id}" 2>/dev/null || true)

PANE_ID=$(tmux new-window -t "$SESSION" -n "$WINDOW" -c "$WORKTREE" -d -P -F "#{pane_id}")
# after-new-window フックがサイドバーを作成しフォーカスを奪う場合があるため、
# メインペインを明示的にアクティブにする
tmux select-pane -t "$PANE_ID"
# フォーカスを呼び出し元ウィンドウに戻す（popup からの dispatch でフォーカスが移らないようにする）
if [ -n "$CURRENT_WINDOW" ]; then
  tmux select-window -t "$CURRENT_WINDOW" 2>/dev/null || true
fi
PANE_NUM="${PANE_ID#%}"

mkdir -p /tmp/agent-pane-state
echo "$WINDOW" > "/tmp/agent-pane-state/pane_${PANE_NUM}_role"

# Write pending context for SessionStart hook (Mode B)
if [[ -n "$WORKFLOW_SESSION_ID" && -n "$REPO_ROOT" ]]; then
    mkdir -p "$HOME/.workflow-sessions/pending"
    jq -n \
        --arg wsi "$WORKFLOW_SESSION_ID" \
        --arg role "$WINDOW" \
        --arg repo_root "$REPO_ROOT" \
        --arg log_dir "docs/dispatch-logs/$WORKFLOW_SESSION_ID" \
        '{"workflow_session_id": $wsi, "role": $role, "repo_root": $repo_root, "log_dir": $log_dir}' \
        > "$HOME/.workflow-sessions/pending/pane-${PANE_NUM}.json"
fi

echo "$PANE_ID"
