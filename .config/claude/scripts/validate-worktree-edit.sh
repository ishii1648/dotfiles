#!/bin/bash
# PreToolUse hook: worktree内で作業中にメインリポジトリへの編集をブロック
#
# 環境変数:
#   CLAUDE_TOOL_INPUT - ツールの入力パラメータ(JSON)
#
# 終了コード:
#   0 - 許可
#   2 - ブロック（メッセージを表示）

# worktree内で作業中かチェック（.gitがファイルならworktree）
if [[ ! -f "$PWD/.git" ]]; then
    exit 0  # worktreeではないので何もしない
fi

# ツール入力からfile_pathを取得
FILE_PATH=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
    exit 0  # file_pathがない場合は何もしない
fi

# .gitファイルからメインリポジトリのパスを取得
GITDIR=$(cat "$PWD/.git" | sed 's/gitdir: //')
MAIN_REPO=$(dirname "$(dirname "$GITDIR")" | sed 's/\/.git$//')

# メインリポジトリへの編集かチェック
# 条件: パスがメインリポジトリで始まり、かつ現在のworktree配下ではない
if [[ "$FILE_PATH" == "$MAIN_REPO"* ]] && [[ "$FILE_PATH" != "$PWD"* ]]; then
    echo "BLOCKED: worktree内でメインリポジトリのファイルを編集しようとしています"
    echo ""
    echo "  編集先: $FILE_PATH"
    echo "  現在のworktree: $PWD"
    echo "  メインリポジトリ: $MAIN_REPO"
    echo ""
    echo "worktree内のファイルを編集する場合は \$PWD 配下のパスを使用してください"
    exit 2
fi

exit 0
