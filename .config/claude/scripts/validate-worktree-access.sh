#!/bin/bash
# PreToolUse hook: worktree内で作業中にメインリポジトリへのアクセスをブロック
#
# 対応ツール: Edit, Write, Read, Glob, Grep
#
# 環境変数:
#   CLAUDE_TOOL_INPUT - ツールの入力パラメータ(JSON)
#   CLAUDE_TOOL_NAME  - ツール名
#
# 終了コード:
#   0 - 許可
#   2 - ブロック（メッセージを表示）

# worktree内で作業中かチェック（.gitがファイルならworktree）
if [[ ! -f "$PWD/.git" ]]; then
    exit 0  # worktreeではないので何もしない
fi

# .gitファイルからメインリポジトリのパスを取得
GITDIR=$(cat "$PWD/.git" | sed 's/gitdir: //')
MAIN_REPO=$(dirname "$(dirname "$GITDIR")" | sed 's/\/.git$//')

# ツール名に応じてパスパラメータを取得
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
TARGET_PATH=""

case "$TOOL_NAME" in
    "Read"|"Edit"|"Write")
        TARGET_PATH=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // empty')
        ;;
    "Glob"|"Grep")
        TARGET_PATH=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.path // empty')
        # path省略時はCWD（worktree）が対象になるためチェック不要
        if [[ -z "$TARGET_PATH" ]]; then
            exit 0
        fi
        ;;
    *)
        exit 0  # 未知のツールは許可
        ;;
esac

if [[ -z "$TARGET_PATH" ]]; then
    exit 0  # パスがない場合は何もしない
fi

# メインリポジトリへのアクセスかチェック
# 条件: パスがメインリポジトリで始まり、かつ現在のworktree配下ではない
if [[ "$TARGET_PATH" == "$MAIN_REPO"* ]] && [[ "$TARGET_PATH" != "$PWD"* ]]; then
    echo "BLOCKED: worktree内でメインリポジトリにアクセスしようとしています"
    echo ""
    echo "  ツール: $TOOL_NAME"
    echo "  対象パス: $TARGET_PATH"
    echo "  現在のworktree: $PWD"
    echo "  メインリポジトリ: $MAIN_REPO"
    echo ""
    echo "worktree内のファイルを操作する場合は \$PWD 配下のパスを使用してください"
    exit 2
fi

exit 0
