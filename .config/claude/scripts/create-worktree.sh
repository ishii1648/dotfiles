#!/bin/bash
set -euo pipefail

# エラーハンドラー - エラー時もJSON出力を返す
cleanup_on_error() {
    local exit_code=$?
    local line_no=$1
    echo "[ERROR] Script failed at line $line_no with exit code $exit_code" >&2
    echo "{\"continue\": false, \"stopReason\": \"[ERROR] Worktree creation failed at line $line_no. Check /tmp/create-worktree-debug.log for details.\"}"
    exit 0
}

trap 'cleanup_on_error $LINENO' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" >&2
}

# Detect default branch (main or master)
get_default_branch() {
    local default_branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

    if [ -n "$default_branch" ]; then
        echo "$default_branch"
        return
    fi

    if git show-ref --verify --quiet refs/heads/main; then
        echo "main"
    elif git show-ref --verify --quiet refs/heads/master; then
        echo "master"
    else
        log_error "Could not detect default branch (neither 'main' nor 'master' found)"
        exit 1
    fi
}

# Function to copy file if it exists
copy_if_exists() {
    local src="$1"
    local dest="$2"
    if [ -f "${src}" ]; then
        cp "${src}" "${dest}"
        log_info "Copied: ${src}"
    fi
}

# Function to generate random port (range: 10000-60000)
generate_random_port() {
    echo $((RANDOM % 50000 + 10000))
}

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

    # Copy command to clipboard (macOS)
    if command -v pbcopy &> /dev/null; then
        echo -n "$NEXT_COMMAND" | pbcopy
        log_info "Command copied to clipboard: ${NEXT_COMMAND}"
    fi

    echo "{\"continue\": false, \"stopReason\": \"[WARN] Worktree already exists at ${WORKTREE_FULL_PATH}. Please start a new session: ${NEXT_COMMAND}\"}"
    exit 0
fi

# Check if branch already exists
if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    log_warn "Branch ${BRANCH_NAME} already exists"
    log_info "Creating worktree from existing branch..."
    git worktree add "${WORKTREE_DIR}" "${BRANCH_NAME}"
else
    DEFAULT_BRANCH=$(get_default_branch)
    log_step "Creating new branch and worktree from ${DEFAULT_BRANCH}..."
    git worktree add -b "${BRANCH_NAME}" "${WORKTREE_DIR}" "${DEFAULT_BRANCH}"
fi

log_info "Worktree created successfully"

# Copy environment files
log_step "Copying environment files..."

# Root level environment files
if [ -f ".env" ]; then
    RANDOM_FRONTEND_PORT=$(generate_random_port)
    RANDOM_BACKEND_PORT=$(generate_random_port)
    RANDOM_AGENT_PORT=$(generate_random_port)

    sed -e "s/^FRONTEND_PORT=.*/FRONTEND_PORT=${RANDOM_FRONTEND_PORT}/" \
        -e "s/^BACKEND_PORT=.*/BACKEND_PORT=${RANDOM_BACKEND_PORT}/" \
        -e "s/^AGENT_PORT=.*/AGENT_PORT=${RANDOM_AGENT_PORT}/" \
        ".env" > "${WORKTREE_DIR}/.env"

    log_info "Copied: .env (with randomized ports)"
    log_info "  FRONTEND_PORT=${RANDOM_FRONTEND_PORT}"
    log_info "  BACKEND_PORT=${RANDOM_BACKEND_PORT}"
    log_info "  AGENT_PORT=${RANDOM_AGENT_PORT}"
fi
copy_if_exists ".envrc" "${WORKTREE_DIR}/.envrc"

# Frontend environment files
FRONTEND_FILES=(".env" ".env.local" ".env.dev" ".env.prd" ".env.test")
for file in "${FRONTEND_FILES[@]}"; do
    copy_if_exists "modules/frontend/${file}" "${WORKTREE_DIR}/modules/frontend/${file}"
done

# Backend environment files
copy_if_exists "modules/backend/.env" "${WORKTREE_DIR}/modules/backend/.env"

# Agent environment files
copy_if_exists "modules/agent/.env" "${WORKTREE_DIR}/modules/agent/.env"

# .claude/settings.local.json をシンボリックリンクで作成
if [ -f ".claude/settings.local.json" ]; then
    mkdir -p "${WORKTREE_DIR}/.claude"
    ln -sf "${REPO_ROOT}/.claude/settings.local.json" "${WORKTREE_DIR}/.claude/settings.local.json"
    log_info "Symlinked: .claude/settings.local.json"
fi

log_info "Environment files copied"

# Run make setup in worktree
log_step "Running make setup in worktree..."
cd "${WORKTREE_DIR}"

if [ -f "Makefile" ]; then
    make setup || log_warn "make setup completed with warnings"
    log_info "Setup completed"
else
    log_warn "No Makefile found, skipping setup"
fi

# Print summary
echo "" >&2
echo -e "${GREEN}========================================${NC}" >&2
echo -e "${GREEN} Worktree created successfully!${NC}" >&2
echo -e "${GREEN}========================================${NC}" >&2
echo "" >&2
echo "Location: ${REPO_ROOT}/${WORKTREE_DIR}" >&2
echo "Branch:   ${BRANCH_NAME}" >&2
echo "" >&2

# Output systemMessage for Claude to move to worktree
WORKTREE_FULL_PATH="${REPO_ROOT}/${WORKTREE_DIR}"
NEXT_COMMAND="cd ${WORKTREE_FULL_PATH} && claude"

# Copy command to clipboard (macOS)
if command -v pbcopy &> /dev/null; then
    echo -n "$NEXT_COMMAND" | pbcopy
    log_info "Command copied to clipboard: ${NEXT_COMMAND}"
fi

echo "{\"continue\": false, \"stopReason\": \"Worktree created at ${WORKTREE_FULL_PATH}. Please start a new session: ${NEXT_COMMAND}\"}"
