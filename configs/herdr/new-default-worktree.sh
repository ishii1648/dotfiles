#!/usr/bin/env bash
# herdr custom command: 新しい tab / workspace を repo の default worktree で開く（ADR-087）
#
# herdr 組み込みの new_tab / new_workspace は cwd を [terminal] new_cwd = "follow" で
# 呼び出し元ペインから継承する。CLAUDE.md の worktree 運用（worktree と branch を 1:1 に
# 保ち、作業ごとに linked worktree を作る）により linked worktree に居る時間が長いため、
# そのまま継承すると新しい tab まで linked worktree で開いてしまう。新しい tab / workspace を
# 開く動機は「repo 本体で別の作業を始める」ことが主なので、default worktree に解決し直す。
#
# type = "shell" はバックグラウンドで detach 実行され TTY を持たない。エラーは表示できない
# ため、原因追跡はログに委ねる（new-workspace.sh の die() 相当は使えない）。
set -euo pipefail

mode="${1:-}"
case "$mode" in
    tab | workspace) ;;
    *)
        printf 'usage: %s <tab|workspace>\n' "${0##*/}" >&2
        exit 2
        ;;
esac

# herdr サーバから起動されるため、PATH はログインシェル（fish）のものと一致する保証がない。
# jq は aqua、git は homebrew / system 管理。herdr 本体は $HOME/.local/bin にある
# （ADR-077/079 と同型の PATH 補強）。
export PATH="$HOME/.local/bin:$HOME/.local/share/aquaproj-aqua/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
# aqua の bin は proxy なので実体の解決に設定ファイルが要る。cwd 方向の探索で呼び出し元 repo の
# aqua.yaml が優先されるのを防ぐため AQUA_CONFIG で 1 本に固定する（ADR-077 の知見）。
export AQUA_GLOBAL_CONFIG="${AQUA_GLOBAL_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"
export AQUA_CONFIG="${AQUA_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"

HERDR_BIN="${HERDR_BIN_PATH:-herdr}"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/new-default-worktree.log"

log() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || return 0
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" >>"$LOG_FILE" 2>/dev/null || true
}

for cmd in git jq "$HERDR_BIN"; do
    command -v "$cmd" >/dev/null 2>&1 || {
        log "error: $cmd が見つかりません (PATH=$PATH)"
        exit 1
    }
done

# --- 呼び出し元ペインの cwd を解決する ---
# pane の cwd（シェルの cwd）を使う。foreground_cwd は「pane 内の何らかの foreground 子
# プロセスの cwd」に過ぎず、Claude Code が spawn した MCP サーバーの一時ディレクトリや
# linked worktree を拾うことが実測で分かっている（ADR-076）。
# HERDR_ACTIVE_PANE_CWD もカスタムコマンドに渡るが、それが cwd / foreground_cwd の
# どちらに対応するかは未確認なので、明示的に pane get の cwd を一次情報にする。
src_cwd=""
if [ -n "${HERDR_ACTIVE_PANE_ID:-}" ]; then
    src_cwd=$("$HERDR_BIN" pane get "$HERDR_ACTIVE_PANE_ID" 2>/dev/null |
        jq -r '.result.pane.cwd // empty' 2>/dev/null) || src_cwd=""
fi
[ -n "$src_cwd" ] || src_cwd="${HERDR_ACTIVE_PANE_CWD:-}"
[ -n "$src_cwd" ] || src_cwd="$PWD"

# --- default worktree に解決する ---
# `--git-common-dir` は linked worktree からでも共有 .git（= default worktree の .git）を
# 返すため、その親が default worktree になる。default worktree 自身から呼んだ場合は同じ
# パスに解決されるので冪等。
# bare repo（common dir が .git で終わらない）や submodule（.git/modules/<name> を返す）は
# この前提が崩れるため、その場合は解決せず呼び出し元の cwd をそのまま使う。
target="$src_cwd"
common_dir=$(git -C "$src_cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || common_dir=""
case "$common_dir" in
    */.git) target="${common_dir%/.git}" ;;
esac

case "$mode" in
    tab)
        # workspace を明示しないと「フォーカス中の workspace」の解釈が herdr 側に委ねられる。
        # カスタムコマンドには呼び出し元の workspace が環境変数で渡るので、それを使う。
        args=(tab create --cwd "$target" --focus)
        if [ -n "${HERDR_ACTIVE_WORKSPACE_ID:-}" ]; then
            args+=(--workspace "$HERDR_ACTIVE_WORKSPACE_ID")
        fi
        ;;
    workspace)
        # 組み込みの new_workspace と同じく、同名の workspace が既にあっても常に新規作成する
        # （既存があれば focus する new-workspace.sh のピッカーとは意図的に挙動が異なる）。
        args=(workspace create --cwd "$target" --label "$(basename "$target")" --focus)
        ;;
esac

if "$HERDR_BIN" "${args[@]}" >>"$LOG_FILE" 2>&1; then
    log "$mode created (src=$src_cwd target=$target)"
else
    log "warn: $mode create failed (src=$src_cwd target=$target)"
    exit 1
fi
