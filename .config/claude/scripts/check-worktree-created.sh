#!/bin/bash
set -euo pipefail

# Stop hook: worktree作成後に会話を停止するためのスクリプト
# PostToolUse (create-worktree.sh) でworktreeが作成された場合、
# フラグファイルが存在するので、それを確認して continue: false を返す

# stdin から JSON を読み込む（必須）
hook_input=$(cat)

FLAG_FILE="/tmp/worktree-created-flag"

if [ -f "$FLAG_FILE" ]; then
    WORKTREE_INFO=$(cat "$FLAG_FILE")
    rm -f "$FLAG_FILE"

    # フラグファイルの内容をパース（PATH|COMMAND形式）
    WORKTREE_PATH=$(echo "$WORKTREE_INFO" | cut -d'|' -f1)
    NEXT_COMMAND=$(echo "$WORKTREE_INFO" | cut -d'|' -f2)

    echo "{\"continue\": false, \"stopReason\": \"Worktree created at ${WORKTREE_PATH}. Please start a new session: ${NEXT_COMMAND}\"}"
else
    # フラグファイルがなければ何もしない（会話を続行）
    echo "{}"
fi
