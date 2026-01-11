#!/bin/bash
set -euo pipefail

# 共通関数ライブラリを読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_worktree.sh"
setup_error_handler

# 引数チェック
if [ -z "${1:-}" ]; then
    echo '{"continue": false, "stopReason": "[ERROR] Usage: /worktree <feature-name>"}'
    exit 0
fi

FEATURE_NAME="$1"
BRANCH_NAME="feature/${FEATURE_NAME}"
WORKTREE_DIR=".worktrees/${FEATURE_NAME}"
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

log_info "Creating worktree for feature: ${FEATURE_NAME}"

# worktree既存チェック
if [ -d "${WORKTREE_DIR}" ]; then
    WORKTREE_FULL_PATH="${REPO_ROOT}/${WORKTREE_DIR}"
    NEXT_COMMAND="cd ${WORKTREE_FULL_PATH} && claude --resume ${FEATURE_NAME}"
    copy_to_clipboard "$NEXT_COMMAND"
    echo "{\"continue\": false, \"stopReason\": \"[WARN] Worktree already exists at ${WORKTREE_FULL_PATH}. Command copied: ${NEXT_COMMAND}\"}"
    exit 0
fi

# 1. 未コミット変更をstash（元ブランチに残しつつ新worktreeにもコピー）
HAS_CHANGES=false
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    HAS_CHANGES=true
    log_step "Stashing uncommitted changes..."
    git stash -u -m "worktree: ${FEATURE_NAME}"

    # 元ブランチに変更を復元（stashは残る）
    log_step "Restoring changes to original branch..."
    git stash apply
fi

# 2. worktree作成
create_worktree "$BRANCH_NAME" "$WORKTREE_DIR"

# 3. 新worktreeでstash適用（環境ファイルコピー・シンボリックリンク作成前）
if [ "$HAS_CHANGES" = true ]; then
    log_step "Copying changes to new worktree..."
    (cd "${WORKTREE_DIR}" && git stash apply)
    log_info "Changes copied to worktree"

    # stashを削除（両方に適用済み）
    git stash drop
fi

# 4. 環境ファイルコピー
copy_env_files "$WORKTREE_DIR"

# 5. settings.local.json シンボリックリンク
symlink_settings "$REPO_ROOT" "$WORKTREE_DIR"

# 6. make setup 実行
run_make_setup "$WORKTREE_DIR"

# 7. サマリー出力
WORKTREE_FULL_PATH="${REPO_ROOT}/${WORKTREE_DIR}"
print_summary "$WORKTREE_FULL_PATH" "$BRANCH_NAME"

# 8. JSON出力
NEXT_COMMAND="cd ${WORKTREE_FULL_PATH} && claude --resume ${FEATURE_NAME}"
copy_to_clipboard "$NEXT_COMMAND"

echo "{\"continue\": false, \"stopReason\": \"Worktree created at ${WORKTREE_FULL_PATH}. Resume session with: ${NEXT_COMMAND}\"}"
