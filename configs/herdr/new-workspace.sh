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
# herdr 本体は $HOME/.local/bin にあるが popup の PATH には含まれない。HERDR_BIN_PATH が
# 渡らない場合のフォールバックとして前置する（open-pr.sh の実障害を横展開）。
export PATH="$HOME/.local/bin:$HOME/.local/share/aquaproj-aqua/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# aqua の bin は proxy なので、実体の解決には設定ファイルが要る。popup の cwd は
# [terminal] new_cwd = "follow" で呼び出し元ペインを継承するため、dotfiles 以外の repo で
# 押すと aqua がその repo の aqua.yaml を探し、fzf が `command is not found` で落ちる。
# fish の conf.d と同じグローバル設定を明示して cwd 非依存にする（既に環境にあれば尊重）。
export AQUA_GLOBAL_CONFIG="${AQUA_GLOBAL_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"
# AQUA_GLOBAL_CONFIG だけでは cwd 非依存にならない: aqua は cwd から辿ったローカル aqua.yaml も
# 探索してマージするため、呼び出し元 repo が同名パッケージ（fzf 等）を別バージョンで固定して
# いると、そちらが優先解決されてしまう（agent-picker.sh で sre-hub の fzf@v0.56.3 が優先され
# unknown option エラーになる実害を確認）。AQUA_CONFIG で dotfiles の aqua.yaml 1 本に固定し、
# cwd 方向の探索自体を無効化する。
export AQUA_CONFIG="${AQUA_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"

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

# --- 新規 pane に claude を自動起動する（ADR-086） ---
# agent 名は live agent 間で一意である必要があり（複数 workspace で同時に claude を
# 起動する運用があるため固定文字列は使えない）、作成直後の時点で必ず一意な pane_id
# から組み立てる。claude の自動起動に失敗しても workspace 自体は既に使える状態なので
# die() は呼ばず、ログに warn を残すだけにする。
#
# 実機でこの popup（type = "popup"、モーダル端末）の中から作成直後に即 agent start
# すると "agent_pane_busy: ... is not an available shell" で毎回失敗することを確認
# した（CLI から手動で同じ順序を再現しても即成功するため、popup がまだ端末を専有して
# いる間は新規 pane 側のシェルが対話可能状態に達しない、popup 固有のタイミング問題と
# 見られる）。原因を herdr 側で確定づける情報がないため、対症療法として短い間隔での
# リトライで吸収する。
#
# このリトライ（最大10回・0.5秒間隔）をスクリプトの終了前に待つと、popup はスクリプト
# の exit と同時に閉じる仕様のため、repo 選択直後に閉じるはずの popup が最大5秒程度
# 遅延して体感が悪化する。呼び出し側で `&` によりバックグラウンド化し、popup を待たせ
# ない。SIGHUP（端末クローズに伴うもの）は trap で無視するが、herdr がプロセスグループ
# ごと終了させる実装だった場合は setsid 相当の完全分離ではないため巻き込まれる可能性
# が残る（未検証）。
launch_claude_retry() {
    trap '' HUP
    local pane_id="$1" agent_name="$2" attempt
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
        if "$HERDR_BIN" agent start "$agent_name" --kind claude --pane "$pane_id" >>"$LOG_FILE" 2>&1; then
            log "agent start claude ok (pane=$pane_id name=$agent_name, attempt=$attempt)"
            return 0
        fi
        sleep 0.5
    done
    log "warn: agent start claude failed after $attempt attempts (pane=$pane_id name=$agent_name)"
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
create_json=$("$HERDR_BIN" workspace create --cwd "$selected" --label "$label" --focus) ||
    die "workspace create --cwd $selected に失敗しました"

# workspace create のレスポンス JSON に新規 pane の pane_id がそのまま乗っている
# （実測確認済み、追加の api snapshot 問い合わせは不要）。claude 起動のリトライは
# launch_claude_retry（バックグラウンド実行、上部で定義）に任せ、popup を待たせない。
pane_id=$(printf '%s' "$create_json" | jq -r '.result.root_pane.pane_id // empty')
if [ -n "$pane_id" ]; then
    agent_name="claude-$(printf '%s' "$pane_id" | tr -d ':' | tr '[:upper:]' '[:lower:]')"
    launch_claude_retry "$pane_id" "$agent_name" </dev/null >>"$LOG_FILE" 2>&1 &
    disown
else
    log "warn: pane_id not found in workspace create response"
fi

# --- default branch に追従させる（ADR-088） ---
# ネットワーク往復を伴うので、popup のクローズを待たせないようバックグラウンドで走らせる
# （claude 起動のリトライと同じ理由・同じ形。ADR-086）。claude 起動とは順序を持たせず
# 独立に走らせる — pull を待ってから claude を起動すると起動が体感で遅くなるうえ、
# claude はファイルを遅延読みするため先に pull が終わっている必要は無い。
"$HOME/.local/bin/herdr-pull-default-branch" "$selected" </dev/null >/dev/null 2>&1 &
disown
