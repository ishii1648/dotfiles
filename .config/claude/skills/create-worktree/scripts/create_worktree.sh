#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Detect default branch (main or master)
get_default_branch() {
    # Try to get from remote HEAD
    local default_branch
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')

    if [ -n "$default_branch" ]; then
        echo "$default_branch"
        return
    fi

    # Fallback: check if main or master exists
    if git show-ref --verify --quiet refs/heads/main; then
        echo "main"
    elif git show-ref --verify --quiet refs/heads/master; then
        echo "master"
    else
        log_error "Could not detect default branch (neither 'main' nor 'master' found)"
        exit 1
    fi
}

# Usage
usage() {
    echo "Usage: $0 <feature-name>"
    echo ""
    echo "Creates a git worktree for parallel feature development."
    echo ""
    echo "Arguments:"
    echo "  feature-name    Name of the feature (e.g., user-auth, dashboard-redesign)"
    echo ""
    echo "Example:"
    echo "  $0 user-auth"
    echo ""
    echo "This will create:"
    echo "  - Branch: feature/user-auth"
    echo "  - Worktree: .worktrees/user-auth/"
    exit 1
}

# Check arguments
if [ $# -lt 1 ]; then
    log_error "Feature name is required"
    usage
fi

FEATURE_NAME="$1"
BRANCH_NAME="feature/${FEATURE_NAME}"
WORKTREE_DIR=".worktrees/${FEATURE_NAME}"

# Get the root directory of the repository
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

log_info "Creating worktree for feature: ${FEATURE_NAME}"
log_info "Branch: ${BRANCH_NAME}"
log_info "Worktree directory: ${WORKTREE_DIR}"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    log_error "Not a git repository"
    exit 1
fi

# Check if worktree already exists
if [ -d "${WORKTREE_DIR}" ]; then
    log_error "Worktree already exists: ${WORKTREE_DIR}"
    log_info "To remove it, run: git worktree remove ${WORKTREE_DIR}"
    exit 1
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

# Root level environment files
if [ -f ".env" ]; then
    # Generate random ports for each service
    RANDOM_FRONTEND_PORT=$(generate_random_port)
    RANDOM_BACKEND_PORT=$(generate_random_port)
    RANDOM_AGENT_PORT=$(generate_random_port)

    # Copy and replace port numbers
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
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN} Worktree created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Location: ${REPO_ROOT}/${WORKTREE_DIR}"
echo "Branch:   ${BRANCH_NAME}"
echo ""
echo "To start working:"
echo "  cd ${WORKTREE_DIR}"
echo ""
echo "To remove worktree when done:"
echo "  git worktree remove ${WORKTREE_DIR}"
echo ""
