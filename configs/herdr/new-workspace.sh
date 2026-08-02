#!/usr/bin/env bash
# herdr custom command (prefix+shift+s = Cmd+Shift+S): ghq リポジトリを選んで workspace を作る
#
# herdr 組み込みの new_workspace は cwd を [terminal] new_cwd = "follow" で継承するだけで
# リポジトリを選べない（ADR-077）。tmux 時代の `tmux-sidebar new`（ADR-069/075）が担っていた
# 「repo を選んでセッションを作る」ステップを、popup 型のカスタムコマンドとして復活させる。
#
# type = "popup" はコマンドが終わるまで全入力（Esc 含む）を受け取るモーダル端末なので、
# fzf をそのまま動かせる。コマンドが終了すると popup は閉じる。
set -euo pipefail

# herdr サーバから起動されるため、PATH はログインシェル（fish）のものと一致する保証がない。
# fzf は aqua、ghq は homebrew 管理なので明示的に前置する。
export PATH="$HOME/.local/share/aquaproj-aqua/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

HERDR_BIN="${HERDR_BIN_PATH:-herdr}"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/new-workspace.log"

log() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || return 0
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" >>"$LOG_FILE" 2>/dev/null || true
}

# popup はコマンド終了と同時に閉じるため、そのまま exit するとエラーが一瞬で消える。
# ログに残したうえで、キー入力があるまで表示を保持する。
die() {
    log "error: $1"
    printf '\n\033[31merror:\033[0m %s\n\n何かキーを押すと閉じます...' "$1" >&2
    read -r -n1 -s || true
    exit 1
}

for cmd in ghq fzf jq "$HERDR_BIN"; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd が見つかりません (PATH=$PATH)"
done

# --- repo 選択 ---
# `ghq list -p` は `<repo>@<branch>` 形式の linked worktree も列挙する（実測 175 件中の大半）。
# ピッカーに出したいのは default worktree（メインのチェックアウト）だけなので絞り込む。
# 判定は `.git` の種類: default worktree ではディレクトリ、linked worktree では
# `gitdir: ...` を書いたファイルになる。全件に git を起動するより速い。
list_default_worktrees() {
    ghq list -p | while IFS= read -r repo; do
        [ -d "$repo/.git" ] && printf '%s\n' "$repo"
    done
}

# fzf のキャンセル（Esc / Ctrl+C）は exit 130 等になるので、その場合は何もせず閉じる。
selected=$(list_default_worktrees | fzf --prompt='repo> ' --reverse --height=100% --border=none) || exit 0
[ -n "$selected" ] || exit 0

label=$(basename "$selected")

# --- 既存 workspace があれば focus する ---
# 判定は pane の cwd の完全一致。前方一致にすると worktree（.claude/worktrees/* 等）で
# 作業中のペインまで拾い、repo ルートの workspace を新規に作れなくなる（ADR-077）。
existing=$("$HERDR_BIN" api snapshot 2>/dev/null |
    jq -r --arg dir "$selected" '
        .result.snapshot.panes
        | map(select(.cwd == $dir))
        | .[0].workspace_id // empty
    ' 2>/dev/null) || existing=""

if [ -n "$existing" ]; then
    log "focus $existing ($selected)"
    "$HERDR_BIN" workspace focus "$existing" >/dev/null || die "workspace focus $existing に失敗しました"
    exit 0
fi

log "create $selected (label=$label)"
"$HERDR_BIN" workspace create --cwd "$selected" --label "$label" --focus >/dev/null ||
    die "workspace create --cwd $selected に失敗しました"
