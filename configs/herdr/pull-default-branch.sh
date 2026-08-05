#!/usr/bin/env bash
# 指定ディレクトリの default worktree を origin の default branch に追従させる（ADR-088）
#
# usage: herdr-pull-default-branch <dir>
#
# 新しい space / tab を default worktree で開いた直後（ADR-077 / ADR-086 / ADR-087）に
# 呼ばれ、`git pull --ff-only origin <default branch>` まで済ませる。手で毎回叩いていた
# 「作業を始める前に main を最新にする」ステップの自動化。
#
# 呼び出し側はバックグラウンドで起動する（popup のクローズや claude 起動を待たせない）。
# 失敗しても呼び出し側の成否には影響させない — 最新化できなくても space / tab 自体は
# 使えるため、ログに残すだけにする。
set -euo pipefail

dir="${1:-}"
if [ -z "$dir" ]; then
    printf 'usage: %s <dir>\n' "${0##*/}" >&2
    exit 2
fi

export PATH="$HOME/.local/bin:$HOME/.local/share/aquaproj-aqua/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/pull-default-branch.log"
# ログディレクトリはここで先に作る。log() の中だけで mkdir していると、happy path で最初に
# $LOG_FILE へ触れるのが `>>"$LOG_FILE"` リダイレクトになり、ディレクトリ未作成の初回実行で
# リダイレクトごと失敗して「pull を実行せずに失敗扱い」になる（2 回目以降は成功するため
# 気付きにくい。実際にテストで踏んだ）。
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || return 0
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" >>"$LOG_FILE" 2>/dev/null || true
}

skip() {
    log "skip: $1 (dir=$dir)"
    exit 0
}

command -v git >/dev/null 2>&1 || skip "git が見つかりません"
[ -d "$dir" ] || skip "ディレクトリが存在しません"

# --- git 管理下か、かつ default worktree か ---
# linked worktree で pull すると、その worktree の作業ブランチに origin の default branch を
# 取り込むことになり ADR-082 の「worktree と branch を 1:1 に固定する」運用を壊す。
# default worktree（git-dir と git-common-dir が一致）でのみ実行する。
git_dir=$(git -C "$dir" rev-parse --path-format=absolute --git-dir 2>/dev/null) || skip "git 管理下ではありません"
common_dir=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || skip "git-common-dir を解決できません"
[ "$git_dir" = "$common_dir" ] || skip "linked worktree なので pull しません"

git -C "$dir" remote get-url origin >/dev/null 2>&1 || skip "origin remote がありません"

# --- default branch を解決する ---
# gw_add.fish / block-worktree-branch-switch.py と同じ検出方法に揃える。
# ブランチ名に `/` を含む場合（release/v1 等）も壊れないよう prefix を剥がす。
ref=$(git -C "$dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null) || ref=""
default_branch="${ref#refs/remotes/origin/}"
if [ -z "$default_branch" ] || [ "$default_branch" = "$ref" ]; then
    default_branch=$(git -C "$dir" config init.defaultBranch 2>/dev/null) || default_branch=""
fi
[ -n "$default_branch" ] || skip "default branch を特定できません"

# --- 現在のブランチが default branch のときだけ pull する ---
# CLAUDE.md の不変条件では default worktree は常に default branch のままだが、
# 何らかの理由で別ブランチに居る場合に origin/<default> を取り込むのは意図と違う。
current_branch=$(git -C "$dir" branch --show-current 2>/dev/null) || current_branch=""
[ "$current_branch" = "$default_branch" ] || skip "現在のブランチが $default_branch ではありません (current=${current_branch:-detached})"

# --ff-only なので、merge commit を作ることも履歴を書き換えることも無い。
# fast-forward できない場合（ローカル先行・分岐・dirty で衝突）は失敗して何もしない。
# 同じ repo に対する pull が同時に走ると index.lock で片方が失敗するが、いずれも
# 副作用の無い失敗なのでロックは取らない。
if git -C "$dir" pull --ff-only origin "$default_branch" >>"$LOG_FILE" 2>&1; then
    log "pulled $default_branch (dir=$dir)"
else
    log "warn: pull --ff-only origin $default_branch failed (dir=$dir)"
    exit 1
fi
