#!/usr/bin/env bash
# herdr custom command (prefix+a = Cmd+A): エージェント一覧から j/k で選んでフォーカスする
#
# herdr の navigate mode（goto / OpenNavigator）は workspace とペインを 1 つのツリーで辿る
# 作りで、「エージェントだけの一覧」に絞る設定は無い（ADR-079）。spaces 側は組み込みの
# workspace_picker（Cmd+S）が既にあるため、足りていないエージェント側をこのスクリプトで補う。
#
# type = "popup" はコマンドが終わるまで全入力（Esc 含む）を受け取るモーダル端末なので、
# fzf をそのまま動かせる。コマンドが終了すると popup は閉じる。
# 構成は configs/herdr/new-workspace.sh（ADR-077）と同型。
set -euo pipefail

# herdr サーバから起動されるため、PATH はログインシェル（fish）のものと一致する保証がない。
# fzf / jq は aqua 管理なので明示的に前置する。
export PATH="$HOME/.local/share/aquaproj-aqua/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# aqua の bin は proxy なので、実体の解決には設定ファイルが要る。popup の cwd は
# [terminal] new_cwd = "follow" で呼び出し元ペインを継承するため、明示しないと dotfiles 以外の
# repo で押したときにその repo の aqua.yaml を探して `command is not found` で落ちる（ADR-077）。
export AQUA_GLOBAL_CONFIG="${AQUA_GLOBAL_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"
# AQUA_GLOBAL_CONFIG だけでは cwd 非依存にならない: aqua は cwd から辿ったローカル aqua.yaml も
# 探索してマージするため、呼び出し元 repo（例: sre-hub）が同名パッケージを別バージョンで固定して
# いると、そちらが優先解決される（sre-hub の fzf@v0.56.3 は --no-input 未対応で
# unknown option: --no-input → exit=2 で popup が落ちた）。AQUA_CONFIG で dotfiles の
# aqua.yaml 1 本に固定し、cwd 方向の探索自体を無効化する。
export AQUA_CONFIG="${AQUA_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"

HERDR_BIN="${HERDR_BIN_PATH:-herdr}"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/agent-picker.log"

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

# エラーではないが popup を一瞬で閉じたくないケース（エージェントが 1 つも無い等）。
notice() {
    log "notice: $1"
    printf '\n%s\n\n何かキーを押すと閉じます...' "$1"
    read -r -n1 -s || true
    exit 0
}

log "invoked pid=$$ tty=$(tty 2>&1) term=${TERM:-unset} cwd=$PWD"

for cmd in fzf jq "$HERDR_BIN"; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd が見つかりません (PATH=$PATH)"
done

# --- 一覧の生成 ---
# `herdr api snapshot` 1 回で agents / workspaces / tabs が揃う（`herdr agent list` は
# workspace_id しか返さず、表示用のラベルを別途引く必要がある）。
# 出力は `<pane_id>\t<表示行>`。pane_id は fzf の --with-nth=2.. で隠す。
build_rows() {
    "$HERDR_BIN" api snapshot 2>>"$LOG_FILE" | jq -r '
        def icon:
            # 状態の色分け。herdr サイドバーの state_icon 相当を自前で描く
            # （popup は herdr の描画層の外なので、トークンを再利用する手段が無い）。
            if   . == "working"  then "\u001b[33m●\u001b[0m"
            elif . == "idle"     then "\u001b[32m●\u001b[0m"
            elif . == "blocked"  then "\u001b[31m●\u001b[0m"
            elif . == "waiting"  then "\u001b[35m●\u001b[0m"
            elif . == "attention" then "\u001b[31m!\u001b[0m"
            elif . == "starting" then "\u001b[34m◐\u001b[0m"
            elif . == "exited"   then "\u001b[90m○\u001b[0m"
            else "\u001b[90m○\u001b[0m"
            end;
        .result.snapshot as $s
        | ($s.workspaces | map({key: .workspace_id, value: .}) | from_entries) as $ws
        | ($s.tabs       | map({key: .tab_id,       value: .}) | from_entries) as $tabs
        | $s.agents
        | map(. + {w: $ws[.workspace_id], t: $tabs[.tab_id]})
        # サイドバー（agent_panel_sort = "spaces"）と同じく workspace でまとめる
        | sort_by([.w.number // 0, .t.number // 0])
        | .[]
        | (.terminal_title_stripped // "" | if . == "" then (.cwd // "" | split("/") | last) else . end) as $title
        | (if .focused then "\u001b[36m▸\u001b[0m" else " " end) as $cursor
        | [
            .pane_id,
            "\($cursor)\(.agent_status | icon) \(.w.label // .workspace_id)/\(.t.label // .tab_id)  \u001b[90m\(.agent // "?")\u001b[0m  \($title)"
          ]
        | @tsv
    ' 2>>"$LOG_FILE"
}

rows=$(build_rows) || die "herdr api snapshot の取得に失敗しました。詳細は $LOG_FILE"
[ -n "$rows" ] || notice "フォーカスできるエージェントがありません。"

# --- 選択 ---
# --no-input で検索欄を隠し、j/k を移動に割り当てる（絞り込みより j/k を優先する選択。
# 検索欄を残したまま j:down を bind すると "j" が打てなくなり絞り込みが壊れるため、
# どちらか一方しか取れない）。
# fzf の終了コードは 1（候補なし）/ 130（Esc・Ctrl+C）だけをキャンセルとして扱う。
# `|| exit 0` で一括に握り潰すと起動失敗まで「キャンセル」になり、popup が無言で閉じる（ADR-077）。
set +e
selected=$(printf '%s\n' "$rows" | fzf \
    --ansi \
    --no-input \
    --delimiter='\t' \
    --with-nth=2.. \
    --bind='j:down,k:up,g:first,G:last,q:abort,ctrl-d:half-page-down,ctrl-u:half-page-up' \
    --header='j/k: move  enter: focus  q/esc: cancel' \
    --reverse --height=100% --border=none 2>>"$LOG_FILE")
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

pane_id=${selected%%$'\t'*}
[ -n "$pane_id" ] || exit 0

log "focus $pane_id"
"$HERDR_BIN" agent focus "$pane_id" >/dev/null || die "agent focus $pane_id に失敗しました"
