#!/bin/bash
set -euo pipefail

# 共通関数ライブラリを読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/worktree-common.sh"
setup_error_handler

# デバッグログ
LOG_FILE="/tmp/create-worktree-debug.log"

# stdin から JSON を読み込む
hook_input=$(cat)

echo "========== $(date) ==========" >> "$LOG_FILE"
echo "hook_input: $hook_input" >> "$LOG_FILE"

# tool_response.filePath から plan ファイルパスを抽出
plan_path=$(echo "$hook_input" | jq -r '.tool_response.filePath // empty')
echo "plan_path: $plan_path" >> "$LOG_FILE"

if [ -z "$plan_path" ]; then
    echo '{"result": "error", "message": "No plan file path found"}'
    exit 0
fi

# ファイル名から feature 名を抽出 (例: binary-leaping-pearl.md -> binary-leaping-pearl)
FEATURE_NAME=$(basename "$plan_path" .md)
BRANCH_NAME="feature/${FEATURE_NAME}"
WORKTREE_DIR=".worktrees/${FEATURE_NAME}"

echo "FEATURE_NAME: $FEATURE_NAME" >> "$LOG_FILE"
echo "WORKTREE_DIR: $WORKTREE_DIR" >> "$LOG_FILE"

# Get the root directory of the repository
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

log_info "Creating worktree for feature: ${FEATURE_NAME}"
log_info "Branch: ${BRANCH_NAME}"
log_info "Worktree directory: ${WORKTREE_DIR}"

# worktree内で実行された場合は早期終了
if [ -f ".git" ]; then
    log_warn "Already in a worktree. Skipping worktree creation."
    echo '{"continue": true}'
    exit 0
fi

# gitリポジトリかどうかをチェック
if [ ! -d ".git" ]; then
    echo '{"result": "error", "message": "Not a git repository"}'
    exit 0
fi

# Check if worktree already exists
echo "Checking if worktree exists: ${WORKTREE_DIR}" >> "$LOG_FILE"
echo "Worktree exists: $([ -d "${WORKTREE_DIR}" ] && echo 'yes' || echo 'no')" >> "$LOG_FILE"

if [ -d "${WORKTREE_DIR}" ]; then
    echo "Entering worktree-exists branch" >> "$LOG_FILE"
    log_warn "Worktree already exists: ${WORKTREE_DIR}"
    WORKTREE_FULL_PATH="${REPO_ROOT}/${WORKTREE_DIR}"
    NEXT_COMMAND="cd ${WORKTREE_FULL_PATH} && claude"

    copy_to_clipboard "$NEXT_COMMAND"

    echo "{\"continue\": false, \"stopReason\": \"[WARN] Worktree already exists at ${WORKTREE_FULL_PATH}. Please start a new session: ${NEXT_COMMAND}\"}"
    exit 0
fi

# Create worktree
create_worktree "$BRANCH_NAME" "$WORKTREE_DIR"
log_info "Worktree created successfully"

# Copy environment files
copy_env_files "$WORKTREE_DIR"

# Create symlink for settings.local.json
symlink_settings "$REPO_ROOT" "$WORKTREE_DIR"

# Run make setup in worktree
run_make_setup "$WORKTREE_DIR"

# Print summary
WORKTREE_FULL_PATH="${REPO_ROOT}/${WORKTREE_DIR}"
print_summary "$WORKTREE_FULL_PATH" "$BRANCH_NAME"

# Output JSON for Claude to move to worktree
NEXT_COMMAND="cd ${WORKTREE_FULL_PATH} && claude"
copy_to_clipboard "$NEXT_COMMAND"

echo "{\"continue\": false, \"stopReason\": \"Worktree created at ${WORKTREE_FULL_PATH}. Please start a new session: ${NEXT_COMMAND}\"}"
