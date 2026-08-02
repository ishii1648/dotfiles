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

# aqua の bin は proxy なので、実体の解決には設定ファイルが要る。popup の cwd は
# [terminal] new_cwd = "follow" で呼び出し元ペインを継承するため、dotfiles 以外の repo で
# 押すと aqua がその repo の aqua.yaml を探し、fzf が `command is not found` で落ちる。
# fish の conf.d と同じグローバル設定を明示して cwd 非依存にする（既に環境にあれば尊重）。
export AQUA_GLOBAL_CONFIG="${AQUA_GLOBAL_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"

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

# popup が「一瞬で消える」ときに何も手掛かりが残らないのを防ぐ。起動できたことと
# 実行環境（TTY の有無・TERM）をまず記録しておく。fzf は TTY と terminfo が要る。
log "invoked pid=$$ tty=$(tty 2>&1) term=${TERM:-unset} cwd=$PWD"

for cmd in ghq fzf jq "$HERDR_BIN"; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd が見つかりません (PATH=$PATH)"
done

# --- repo 選択 ---
# `ghq list -p` は `<repo>@<branch>` 形式の linked worktree も列挙する（実測 175 件中の大半）。
# ピッカーに出したいのは default worktree（メインのチェックアウト）だけなので絞り込む。
# 判定は `.git` の種類: default worktree ではディレクトリ、linked worktree では
# `gitdir: ...` を書いたファイルになる。全件に git を起動するより速い。
# `[ -d ] && printf` を末尾に置くと while の終了ステータスが最後の 1 件の判定結果になり、
# 最後が linked worktree だと関数が exit 1 → pipefail で選択結果まで捨てられる。if で包む。
list_default_worktrees() {
    ghq list -p | while IFS= read -r repo; do
        if [ -d "$repo/.git" ]; then
            printf '%s\n' "$repo"
        fi
    done
}

# fzf の終了コードを `|| exit 0` で一括に握り潰すと、起動失敗（TTY なし・terminfo 不在など）
# まで「キャンセル」と同じ扱いになり、popup が無言で一瞬で閉じるだけになる。
# 1（マッチなし）と 130（Esc / Ctrl+C）だけをキャンセルとして扱い、それ以外は原因を残す。
set +e
selected=$(list_default_worktrees | fzf --prompt='repo> ' --reverse --height=100% --border=none 2>>"$LOG_FILE")
fzf_status=$?
set -e
case "$fzf_status" in
    0) ;;
    1 | 130)
        log "fzf cancelled (exit=$fzf_status)"
        exit 0
        ;;
    *) die "fzf が異常終了しました (exit=$fzf_status)。詳細は $LOG_FILE" ;;
esac

[ -n "$selected" ] || exit 0

label=$(basename "$selected")

# --- 既存 workspace があれば focus する ---
# 判定は workspace の label（= 作成時に渡した basename）。以前はペインの cwd 一致で見ていたが、
# 別 repo の workspace 内でその repo を開いたペインが 1 つでもあると既存扱いになり、
# 「選んでも workspace が増えない」状態になった（実測: zeitreise の workspace に dotfiles の
# ペインが 1 つあり、dotfiles を選ぶと毎回そこへ focus していた）。workspace の snapshot は
# cwd を持たない（`herdr workspace get` も label / tab 情報のみ）ため label が唯一の手掛かり。
existing=$("$HERDR_BIN" api snapshot 2>/dev/null |
    jq -r --arg label "$label" '
        .result.snapshot.workspaces
        | map(select(.label == $label))
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
