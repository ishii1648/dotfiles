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

# Default values
PR_ONLY=false
CLEANUP_ONLY=false
FORCE=false
TITLE=""
BODY=""
BASE_BRANCH="main"
DRAFT_FLAG=""
PR_URL=""

# Usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Creates a PR and automatically cleans up the worktree."
    echo ""
    echo "Options:"
    echo "  --pr-only              Create PR only (don't remove worktree)"
    echo "  --cleanup-only         Remove worktree only (PR already created)"
    echo "  --title <title>        PR title (interactive if not specified)"
    echo "  --body <body>          PR body (interactive if not specified)"
    echo "  --base <branch>        Base branch (default: main)"
    echo "  --draft                Create as draft PR"
    echo "  --force                Continue even with uncommitted changes (not recommended)"
    echo "  --help                 Show this help message"
    echo ""
    echo "Example:"
    echo "  $0"
    echo "  $0 --title \"feat: Add new feature\" --body \"Description\""
    echo "  $0 --pr-only"
    echo "  $0 --cleanup-only"
    exit 1
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --pr-only)
                PR_ONLY=true
                shift
                ;;
            --cleanup-only)
                CLEANUP_ONLY=true
                shift
                ;;
            --title)
                TITLE="$2"
                shift 2
                ;;
            --body)
                BODY="$2"
                shift 2
                ;;
            --base)
                BASE_BRANCH="$2"
                shift 2
                ;;
            --draft)
                DRAFT_FLAG="--draft"
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Validate conflicting options
    if [ "$PR_ONLY" = true ] && [ "$CLEANUP_ONLY" = true ]; then
        log_error "Cannot specify both --pr-only and --cleanup-only"
        exit 1
    fi
}

# Validate environment
validate_environment() {
    log_step "Validating environment..."

    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository"
        exit 1
    fi

    # Check if gh CLI is installed
    if ! command -v gh &> /dev/null; then
        log_error "gh CLI is not installed"
        log_info "Install from: https://cli.github.com/"
        exit 1
    fi

    # Check if we're in a worktree directory
    GIT_DIR=$(git rev-parse --git-dir)
    if [[ ! "$GIT_DIR" =~ \.git/worktrees/ ]]; then
        log_error "Not in a worktree directory"
        log_info "This script must be run from within .worktrees/<feature-name>/"
        exit 1
    fi

    # Get current branch
    CURRENT_BRANCH=$(git branch --show-current)
    if [ -z "$CURRENT_BRANCH" ]; then
        log_error "Cannot determine current branch"
        exit 1
    fi

    # Get repository root
    REPO_ROOT=$(git rev-parse --show-toplevel)

    # Get worktree path
    WORKTREE_PATH=$(pwd)
    WORKTREE_NAME=$(basename "$WORKTREE_PATH")

    log_info "Current branch: $CURRENT_BRANCH"
    log_info "Worktree path: $WORKTREE_PATH"
    log_info "Repository root: $REPO_ROOT"
}

# Check for uncommitted changes
check_uncommitted_changes() {
    log_step "Checking for uncommitted changes..."

    if [ "$(git status --porcelain)" != "" ]; then
        if [ "$FORCE" = false ]; then
            log_error "You have uncommitted changes"
            echo ""
            git status --short
            echo ""
            log_info "Please commit or stash your changes before creating PR"
            log_info "Or use --force to skip this check (not recommended)"
            exit 1
        else
            log_warn "Uncommitted changes detected (--force specified, continuing anyway)"
        fi
    else
        log_info "No uncommitted changes detected"
    fi
}

# Check unpushed commits
check_unpushed_commits() {
    log_step "Checking push status..."

    # Check if remote branch exists
    if ! git rev-parse --verify --quiet "origin/$CURRENT_BRANCH" > /dev/null 2>&1; then
        log_warn "Remote branch does not exist"
        log_info "Branch will be pushed during PR creation"
        return
    fi

    # Check for unpushed commits
    UNPUSHED=$(git rev-list "origin/$CURRENT_BRANCH..HEAD" --count 2>/dev/null || echo "0")
    if [ "$UNPUSHED" -gt 0 ]; then
        log_warn "$UNPUSHED unpushed commit(s) detected"
        log_info "gh pr create will push them automatically"
    fi
}

# Create pull request
create_pull_request() {
    if [ "$CLEANUP_ONLY" = true ]; then
        log_info "Skipping PR creation (--cleanup-only specified)"
        return 0
    fi

    log_step "Creating pull request..."

    # Build gh pr create command
    GH_CMD="gh pr create --base $BASE_BRANCH"

    if [ -n "$DRAFT_FLAG" ]; then
        GH_CMD="$GH_CMD $DRAFT_FLAG"
    fi

    if [ -n "$TITLE" ]; then
        GH_CMD="$GH_CMD --title \"$TITLE\""
    fi

    if [ -n "$BODY" ]; then
        GH_CMD="$GH_CMD --body \"$BODY\""
    fi

    # Execute PR creation
    if eval "$GH_CMD"; then
        # Get PR URL
        PR_URL=$(gh pr view --json url -q .url 2>/dev/null || echo "")

        log_info "Pull request created successfully"
        if [ -n "$PR_URL" ]; then
            log_info "PR URL: $PR_URL"
        fi
        return 0
    else
        log_error "Failed to create pull request"
        log_info "Worktree will not be removed"
        exit 1
    fi
}

# Cleanup worktree
cleanup_worktree() {
    if [ "$PR_ONLY" = true ]; then
        log_info "Skipping worktree cleanup (--pr-only specified)"
        return 0
    fi

    log_step "Removing worktree..."

    # Move to repository root
    cd "$REPO_ROOT"

    # Remove worktree
    if git worktree remove "$WORKTREE_PATH"; then
        log_info "Worktree removed successfully: $WORKTREE_PATH"
    else
        log_error "Failed to remove worktree"
        log_info ""
        log_info "You can manually remove it with:"
        log_info "  git worktree remove $WORKTREE_PATH"
        log_info ""
        log_info "Or force remove:"
        log_info "  git worktree remove --force $WORKTREE_PATH"
        exit 1
    fi
}

# Return to main branch
return_to_main() {
    if [ "$PR_ONLY" = true ]; then
        log_info "Staying in worktree (--pr-only specified)"
        return 0
    fi

    log_step "Returning to main branch..."

    cd "$REPO_ROOT"

    if git checkout "$BASE_BRANCH"; then
        log_info "Now on branch: $BASE_BRANCH"
    else
        log_warn "Failed to checkout $BASE_BRANCH"
        log_info "Current directory: $(pwd)"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} PR And Cleanup Completed!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    if [ "$CLEANUP_ONLY" = false ]; then
        if [ -n "$PR_URL" ]; then
            echo "PR URL: $PR_URL"
        fi
    fi

    if [ "$PR_ONLY" = false ]; then
        echo "Removed worktree: $WORKTREE_NAME"
        echo "Current branch: $BASE_BRANCH"
        echo ""
        echo "Note:"
        echo "  - Local branch ($CURRENT_BRANCH) is preserved"
        echo "  - Remote branch is preserved"
        echo ""
        echo "To delete local branch after PR merge:"
        echo "  git branch -d $CURRENT_BRANCH"
    fi
    echo ""
}

# Main
main() {
    parse_arguments "$@"
    validate_environment
    check_uncommitted_changes
    check_unpushed_commits
    create_pull_request
    cleanup_worktree
    return_to_main
    print_summary
}

main "$@"
