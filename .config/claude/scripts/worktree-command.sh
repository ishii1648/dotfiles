#!/bin/bash
set -euo pipefail

# エラーハンドラー
cleanup_on_error() {
    local exit_code=$?
    local line_no=$1
    echo "[ERROR] Script failed at line $line_no with exit code $exit_code" >&2
    echo "{\"continue\": false, \"stopReason\": \"[ERROR] Worktree creation failed at line $line_no.\"}"
    exit 0
}
trap 'cleanup_on_error $LINENO' ERR

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1" >&2; }

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
        echo "[ERROR] Could not detect default branch (neither 'main' nor 'master' found)" >&2
        echo "{\"continue\": false, \"stopReason\": \"[ERROR] Could not detect default branch.\"}"
        exit 0
    fi
}

# 引数チェック
if [ -z "${1:-}" ]; then
    echo "{\"continue\": false, \"stopReason\": \"[ERROR] Usage: /worktree <feature-name>\"}"
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
    NEXT_COMMAND="cd ${WORKTREE_FULL_PATH} && claude"
    echo -n "$NEXT_COMMAND" | pbcopy 2>/dev/null || true
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
DEFAULT_BRANCH=$(get_default_branch)
if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    log_warn "Branch ${BRANCH_NAME} already exists, using existing branch"
    git worktree add "${WORKTREE_DIR}" "${BRANCH_NAME}"
else
    log_step "Creating new branch and worktree from ${DEFAULT_BRANCH}..."
    git worktree add -b "${BRANCH_NAME}" "${WORKTREE_DIR}" "${DEFAULT_BRANCH}"
fi

# 3. 新worktreeでstash適用（シンボリックリンク作成前）
if [ "$HAS_CHANGES" = true ]; then
    log_step "Copying changes to new worktree..."
    cd "${WORKTREE_DIR}"
    git stash apply
    log_info "Changes copied to worktree"

    # stashを削除（両方に適用済み）
    git stash drop
    cd "$REPO_ROOT"
fi

# 4. settings.local.json シンボリックリンク
if [ -f ".claude/settings.local.json" ]; then
    mkdir -p "${WORKTREE_DIR}/.claude"
    ln -sf "${REPO_ROOT}/.claude/settings.local.json" "${WORKTREE_DIR}/.claude/settings.local.json"
    log_info "Symlinked: .claude/settings.local.json"
fi

# 5. JSON出力
WORKTREE_FULL_PATH="${REPO_ROOT}/${WORKTREE_DIR}"
NEXT_COMMAND="cd ${WORKTREE_FULL_PATH} && claude --resume ${FEATURE_NAME}"
echo -n "$NEXT_COMMAND" | pbcopy 2>/dev/null || true
log_info "Command copied to clipboard"

echo "{\"continue\": false, \"stopReason\": \"Worktree created at ${WORKTREE_FULL_PATH}. Resume session with: ${NEXT_COMMAND}\"}"
