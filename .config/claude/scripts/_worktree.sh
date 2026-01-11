#!/bin/bash
# Worktree スクリプト共通関数ライブラリ
# 使用方法: source "${SCRIPT_DIR}/worktree-common.sh"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ログ関数
log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1" >&2; }

# エラーハンドラー設定
setup_error_handler() {
    trap 'worktree_cleanup_on_error $LINENO' ERR
}

worktree_cleanup_on_error() {
    local exit_code=$?
    local line_no=$1
    echo "[ERROR] Script failed at line $line_no with exit code $exit_code" >&2
    echo "{\"continue\": false, \"stopReason\": \"[ERROR] Worktree creation failed at line $line_no.\"}"
    exit 0
}

# デフォルトブランチ検出
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
        echo "{\"continue\": false, \"stopReason\": \"[ERROR] Could not detect default branch.\"}"
        exit 0
    fi
}

# ランダムポート生成 (range: 10000-60000)
generate_random_port() {
    echo $((RANDOM % 50000 + 10000))
}

# ファイルコピーヘルパー
copy_if_exists() {
    local src="$1"
    local dest="$2"
    if [ -f "${src}" ]; then
        cp "${src}" "${dest}"
        log_info "Copied: ${src}"
    fi
}

# worktree作成（共通ロジック）
create_worktree() {
    local branch_name="$1"
    local worktree_dir="$2"

    if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
        log_warn "Branch ${branch_name} already exists, using existing branch"
        git worktree add "${worktree_dir}" "${branch_name}"
    else
        local default_branch
        default_branch=$(get_default_branch)
        log_step "Creating new branch and worktree from ${default_branch}..."
        git worktree add -b "${branch_name}" "${worktree_dir}" "${default_branch}"
    fi
}

# 環境ファイルコピー
copy_env_files() {
    local worktree_dir="$1"

    log_step "Copying environment files..."

    # Root level .env（ポートランダム化）
    if [ -f ".env" ]; then
        local random_frontend_port random_backend_port random_agent_port
        random_frontend_port=$(generate_random_port)
        random_backend_port=$(generate_random_port)
        random_agent_port=$(generate_random_port)

        sed -e "s/^FRONTEND_PORT=.*/FRONTEND_PORT=${random_frontend_port}/" \
            -e "s/^BACKEND_PORT=.*/BACKEND_PORT=${random_backend_port}/" \
            -e "s/^AGENT_PORT=.*/AGENT_PORT=${random_agent_port}/" \
            ".env" > "${worktree_dir}/.env"

        log_info "Copied: .env (with randomized ports)"
        log_info "  FRONTEND_PORT=${random_frontend_port}"
        log_info "  BACKEND_PORT=${random_backend_port}"
        log_info "  AGENT_PORT=${random_agent_port}"
    fi

    # .envrc
    copy_if_exists ".envrc" "${worktree_dir}/.envrc"

    # Frontend environment files
    local frontend_files=(".env" ".env.local" ".env.dev" ".env.prd" ".env.test")
    for file in "${frontend_files[@]}"; do
        copy_if_exists "modules/frontend/${file}" "${worktree_dir}/modules/frontend/${file}"
    done

    # Backend environment files
    copy_if_exists "modules/backend/.env" "${worktree_dir}/modules/backend/.env"

    # Agent environment files
    copy_if_exists "modules/agent/.env" "${worktree_dir}/modules/agent/.env"

    log_info "Environment files copied"
}

# settings.local.json シンボリックリンク作成
symlink_settings() {
    local repo_root="$1"
    local worktree_dir="$2"

    if [ -f ".claude/settings.local.json" ]; then
        mkdir -p "${worktree_dir}/.claude"
        ln -sf "${repo_root}/.claude/settings.local.json" "${worktree_dir}/.claude/settings.local.json"
        log_info "Symlinked: .claude/settings.local.json"
    fi
}

# make setup 実行
run_make_setup() {
    local worktree_dir="$1"

    log_step "Running make setup in worktree..."

    if [ -f "${worktree_dir}/Makefile" ]; then
        (cd "${worktree_dir}" && make setup) || log_warn "make setup completed with warnings"
        log_info "Setup completed"
    else
        log_warn "No Makefile found, skipping setup"
    fi
}

# クリップボードコピー (macOS)
copy_to_clipboard() {
    local text="$1"
    if command -v pbcopy &> /dev/null; then
        echo -n "$text" | pbcopy
        log_info "Command copied to clipboard: ${text}"
    fi
}

# サマリー出力
print_summary() {
    local worktree_path="$1"
    local branch_name="$2"

    echo "" >&2
    echo -e "${GREEN}========================================${NC}" >&2
    echo -e "${GREEN} Worktree created successfully!${NC}" >&2
    echo -e "${GREEN}========================================${NC}" >&2
    echo "" >&2
    echo "Location: ${worktree_path}" >&2
    echo "Branch:   ${branch_name}" >&2
    echo "" >&2
}
