#!/usr/bin/env bash
# worktree-auto-cleanup: 作成から N 時間（既定 72h）超の git worktree を無条件で削除する（ADR-083）
#
# `gw_rm.fish`（手動実行・マージ済み/同一HEAD判定あり）とは独立したツール。
# こちらは launchd から 1日1回起動され、マージ状態を一切問わず経過時間だけで判定する。
# ユーザーの経験則（worktree を3日以上残すケースがない）に基づく明示的な割り切り。
#
# 経過時間の判定には worktree ディレクトリの birthtime（`stat -f %B`）を使う。
# git は worktree の作成日時を持たないため、ディレクトリのファイルシステム上の
# 作成時刻をプロキシとして使う（mtime は編集のたびに動くため使わない）。
#
# `git worktree remove -f` は dirty だけでなく locked も無視して強制削除できてしまう
# （`git worktree remove -h` で確認済み）。EnterWorktree でアクティブに使用中の worktree は
# `git worktree lock` が張られ `git worktree list --porcelain` に `locked <reason>` として
# 現れるため、経過時間を問わずこれを検出して常に skip する。
#
# `ghq list --full-path` は main worktree だけでなく linked worktree（`<repo>@<branch>` の
# sibling ディレクトリ）も個別の「repo」として列挙してくる。素朴にすべてのエントリで
# `git worktree list` を回すと同じ worktree 集合を repo 数 x worktree 数だけ重複処理して
# しまう（実測: 8 worktree を持つ repo で 8 重処理）。`git rev-parse --git-dir` と
# `--git-common-dir` が一致するエントリ（= main worktree そのもの）だけを処理対象にする
# ことで、重複処理と main worktree 誤削除の両方を同時に防ぐ。
set -euo pipefail

THRESHOLD_HOURS=72
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --hours)
            THRESHOLD_HOURS="$2"
            shift 2
            ;;
        *)
            echo "worktree-auto-cleanup: unknown option: $1" >&2
            exit 1
            ;;
    esac
done

THRESHOLD_SECONDS=$((THRESHOLD_HOURS * 3600))
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/worktree-cleanup/cleanup.log"

log() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || return 0
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" >>"$LOG_FILE" 2>/dev/null || true
}

announce() {
    echo "$1"
    log "$1"
}

if ! command -v ghq >/dev/null 2>&1; then
    announce "worktree-auto-cleanup: ghq not found, aborting"
    exit 1
fi

now_epoch=$(date +%s)
checked_count=0
removed_count=0
skipped_locked_count=0

# main worktree 内の 1 リンク worktree ブロックを処理する。
# グローバル変数 main_worktree / block_path / block_branch / block_locked を参照する。
#
# 注意: `return` は引数を省略すると直前コマンドの終了ステータスをそのまま返す。
# 「判定が偽だったのでこのブロックは対象外」という正常系の早期リターンで `cond || return`
# のように書くと、cond が偽（終了ステータス非0）のときに return も非0を返してしまい、
# `set -e` 環境で呼び出し元のベアな `process_block` 呼び出しがスクリプト全体を落とす
# （実機で worktree ディレクトリが既に存在しない prunable エントリに遭遇して発覚）。
# 早期リターンは必ず `return 0` を明示する。
process_block() {
    if [[ -z "$block_path" ]]; then
        return 0
    fi
    if [[ "$block_path" == "$main_worktree" ]]; then
        return 0
    fi

    if $block_locked; then
        skipped_locked_count=$((skipped_locked_count + 1))
        log "skip (locked): $block_path"
        return 0
    fi

    checked_count=$((checked_count + 1))

    if [[ ! -d "$block_path" ]]; then
        return 0
    fi

    local birthtime
    if ! birthtime=$(stat -f %B "$block_path" 2>/dev/null); then
        return 0
    fi
    if [[ -z "$birthtime" ]]; then
        return 0
    fi

    local age=$((now_epoch - birthtime))
    if [[ "$age" -le "$THRESHOLD_SECONDS" ]]; then
        return 0
    fi

    local age_hours=$((age / 3600))
    local branch_label="${block_branch:-detached}"

    if $DRY_RUN; then
        announce "[DRY-RUN] would remove: $block_path (age: ${age_hours}h, branch: $branch_label)"
        removed_count=$((removed_count + 1))
        return 0
    fi

    if git -C "$main_worktree" worktree remove --force "$block_path" >>"$LOG_FILE" 2>&1; then
        announce "removed: $block_path (age: ${age_hours}h, branch: $branch_label)"
        removed_count=$((removed_count + 1))
        if [[ -n "$block_branch" ]]; then
            git -C "$main_worktree" branch -D "$block_branch" >>"$LOG_FILE" 2>&1 || true
        fi
    else
        announce "FAILED to remove: $block_path"
    fi
    return 0
}

while IFS= read -r repo; do
    [[ -e "$repo/.git" ]] || continue

    git_dir=$(git -C "$repo" rev-parse --path-format=absolute --git-dir 2>/dev/null) || continue
    git_common_dir=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || continue
    # main worktree 以外（linked worktree 自身が ghq の別エントリとして出てきたもの）は
    # 対応する main worktree エントリの処理に任せて skip する（重複処理防止）
    [[ "$git_dir" == "$git_common_dir" ]] || continue

    main_worktree="$repo"
    porcelain=$(git -C "$repo" worktree list --porcelain 2>/dev/null) || continue

    block_path=""
    block_branch=""
    block_locked=false

    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            process_block
            block_path=""
            block_branch=""
            block_locked=false
            continue
        fi
        case "$line" in
            "worktree "*)
                block_path="${line#worktree }"
                ;;
            "branch refs/heads/"*)
                block_branch="${line#branch refs/heads/}"
                ;;
            "locked"*)
                block_locked=true
                ;;
        esac
    done <<<"$porcelain"
    # 末尾に空行が無い porcelain 出力向けの保険（通常は空行で終わる）
    [[ -n "$block_path" ]] && process_block
done < <(ghq list --full-path)

announce "worktree-auto-cleanup: done (checked=$checked_count, removed=$removed_count, skipped_locked=$skipped_locked_count, threshold=${THRESHOLD_HOURS}h, dry_run=$DRY_RUN)"
