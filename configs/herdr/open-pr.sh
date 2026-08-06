#!/usr/bin/env bash
# herdr custom command (prefix+u): このセッションで読み込み・作成した GitHub の
# PR/Issue を一覧表示して選んで開く（tmux-sidebar 時代の tmux-fzf-pr-popup 後継）
#
# 拾うのは `https://github.com/<owner>/<repo>/(pull|issues)/<n>` だけ。用途が
# 「PR/Issue に飛ぶ」ことに尽きるため、ドキュメントや CI ログの URL まで並べると
# 目的の 1 件を探す手間が増える。マッチした部分だけを取り出すので `#issuecomment-...`
# や `/files` は落ち、同じ PR への別リンクは 1 行に畳まれる。
#
# 旧 tmux 版は capture-pane したスクロールバック全域を正規表現で URL スクレイプ
# していた。herdr でも同じ方式が使える: `gh pr create`/`gh pr view` は URL を
# プレーンテキストで出すため、OSC 8 ハイパーリンクの復元不可（ADR-076 spike で
# 既知）は無関係。`herdr pane read --format text` は ANSI 除去済みのプレーン
# テキストを返すため、旧版が capture-pane -e の CSI/OSC を perl で剥がしていた
# 手間も不要になった。
#
# 制約: `herdr pane read` はスクロールバックが実測で約 1000 行にクランプされる
# （--lines を増やしても伸びない）。しかも拾えるのは完全な URL 文字列だけで、
# Claude Code が PR を `#1071` の短縮表記で書くため URL 全文が出るのは
# `gh pr create` した瞬間の 1 回きり。その行が窓の外に出ると、直前まで作業していた
# PR でも一覧から消える。これを statusline の pane キャッシュを履歴化することで
# 緩和する（hook で gh pr コマンドの出力を追跡する方式は実装コストに見合わない
# として不採用のまま。docs/issues.md 参照）。
#
# type = "popup" はコマンドが終わるまで全入力（Esc 含む）を受け取るモーダル端末
# なので fzf をそのまま動かせる。構成は configs/herdr/agent-picker.sh と同型。
set -euo pipefail

# herdr サーバから起動されるため、PATH はログインシェル（fish）のものと一致する保証がない。
# fzf / gh は aqua 管理なので明示的に前置する（ADR-077/079 の new-workspace.sh / agent-picker.sh と同型）。
# herdr 本体は公式 install script が $HOME/.local/bin に置く（configs/herdr/setup.sh）。popup の
# PATH には含まれないため（実測: `herdr: command not found`）ここでも前置する。
export PATH="$HOME/.local/bin:$HOME/.local/share/aquaproj-aqua/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
# aqua の bin は proxy なので、実体の解決には設定ファイルが要る。gh pr view フォールバックは
# 呼び出し元ペインの cwd で走るため、dotfiles 以外の repo でも aqua が解決できるよう
# グローバル設定を明示して cwd 非依存にする（既に環境にあれば尊重）。
export AQUA_GLOBAL_CONFIG="${AQUA_GLOBAL_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"
# AQUA_GLOBAL_CONFIG だけでは cwd 非依存にならない: aqua は cwd から辿ったローカル
# aqua.yaml も探索してマージするため、呼び出し元 repo が同名パッケージ（gh / fzf 等）を
# 別バージョンで固定していると、そちらが優先解決されてしまう。AQUA_CONFIG で
# dotfiles の aqua.yaml 1 本に固定し、cwd 方向の探索自体を無効化する。
export AQUA_CONFIG="${AQUA_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"

# herdr は [[keys.command]] 実行時に自分自身の実体パスを HERDR_BIN_PATH で渡す。PATH 解決より
# こちらを優先する（agent-picker.sh / new-workspace.sh と同型）。素の `herdr` を直接呼んでいた
# 旧実装は PATH に $HOME/.local/bin が無いため command not found で全滅していた。
HERDR_BIN="${HERDR_BIN_PATH:-herdr}"

LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/open-pr.log"

log() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || return 0
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" >>"$LOG_FILE" 2>/dev/null || true
}

# popup はコマンド終了と同時に閉じるため、そのまま exit するとメッセージが一瞬で消える。
# キー入力があるまで表示を保持する（configs/herdr/agent-picker.sh と同型）。
notice() {
    log "notice: $1"
    printf '\n%s\n\n何かキーを押すと閉じます...' "$1"
    read -r -n1 -s || true
    exit 0
}

die() {
    log "error: $1"
    printf '\n\033[31merror:\033[0m %s\n\n何かキーを押すと閉じます...' "$1" >&2
    read -r -n1 -s || true
    exit 1
}

# set -e で落ちたときも popup はそのまま閉じるだけで手掛かりが残らない（実測: herdr が
# 見つからないまま候補ゼロで終わったケースを事後に追えなかった）。中断点を必ず記録する。
trap 'log "aborted rc=$? line=$LINENO cmd=$BASH_COMMAND"' ERR

# popup が「一瞬で消える」ときの手掛かりを残す（agent-picker.sh / new-workspace.sh と同型）。
log "invoked pid=$$ tty=$(tty 2>&1) term=${TERM:-unset} cwd=$PWD"

# herdr は必須。無いとスクロールバックのスクレイプが丸ごと空振りし、候補ゼロの
# 「PR/URL が見つかりません」に化けて原因が見えなくなる（旧実装の実障害）。
for cmd in fzf "$HERDR_BIN"; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd が見つかりません (PATH=$PATH)"
done

# --- 呼び出し元 pane を特定 ---
# popup 自身も一つの pane なので、`herdr pane current --current` は「ポップアップ
# 自身」を解決しようとして失敗する（実測: "no focused pane" 相当のエラー）。
# herdr は [[keys.command]] 実行時に呼び出し元 pane を HERDR_ACTIVE_PANE_ID 等の
# 環境変数で渡す仕組みを持つ（旧実装が HERDR_ACTIVE_PANE_CWD をフォールバックの
# 最終候補として使っていたのと同じ経路）ので、これを一次情報として使う。
pane_id="${HERDR_ACTIVE_PANE_ID:-}"
[[ -n "$pane_id" ]] || die "呼び出し元 pane を特定できませんでした（HERDR_ACTIVE_PANE_ID 未設定）"

# --- 候補 URL を集める（先着優先で重複除去。表示順が優先度） ---
# 1) statusline が書いた pane_id キャッシュ（表示中の PR + 履歴。ネットワーク不要・最優先）
# 2) スクロールバックのスクレイプ（ローカル完結。実測 25ms）
# 3) gh pr view フォールバック（1/2 が両方空振りしたときだけ。実測 578ms のネットワーク
#    往復で popup の表示ラグの主因なので最後に回す。Claude Code が動いていない pane 向け）
featured=() # ★ 現在のPR（先頭固定）
recent=()   # 同じ pane で過去に表示した PR（新しい順）
scraped=()  # スクロールバック由来

# キャッシュは 1 行目 = 現在の PR（無ければ空行）、2 行目以降 = 履歴（新しい順）。
# スクレイプは完全な URL 文字列しか拾えず、Claude Code が `#1071` の短縮表記で書いた
# PR は約 1000 行のクランプで URL 行が窓の外に出た時点で候補から消えるため、
# statusline が毎ターン解決している PR を履歴として先に並べる。
pane_cache="/tmp/gh-pr-pane-${pane_id//[!A-Za-z0-9_-]/_}"
if [[ -f "$pane_cache" ]]; then
    cache_lineno=0
    while IFS= read -r cache_line || [[ -n "$cache_line" ]]; do
        cache_lineno=$((cache_lineno + 1))
        cache_url=$(printf '%s' "$cache_line" | cut -d' ' -f2)
        [[ -n "$cache_url" ]] || continue
        if [[ $cache_lineno -eq 1 ]]; then
            featured+=("\033[32m★ 現在のPR\033[0m  $cache_url")
        else
            recent+=("  $cache_url")
        fi
    done <"$pane_cache"
fi

scrollback=$("$HERDR_BIN" pane read "$pane_id" --source recent-unwrapped --format text --lines 5000 2>>"$LOG_FILE" || true)
if [[ -n "$scrollback" ]]; then
    # GitHub の issue/PR URL だけを拾う。マッチした部分だけを取り出すので
    # `#issuecomment-...` や `/files` は自然に落ち、同じ PR への別リンクが 1 行に畳まれる。
    while IFS= read -r url; do
        [[ -n "$url" ]] && scraped+=("  $url")
    done < <(
        printf '%s' "$scrollback" \
            | grep -oE 'https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+/(pull|issues)/[0-9]+' \
            | sort -u || true
    )
fi

if [[ ${#featured[@]} -eq 0 && ${#recent[@]} -eq 0 && ${#scraped[@]} -eq 0 ]]; then
    # pane get（python3 の起動を伴う）も gh を叩くときだけに遅延させる。
    foreground_cwd=""
    pane_cwd=""
    if pane_json=$("$HERDR_BIN" pane get "$pane_id" 2>/dev/null); then
        pane_fields=$(
            printf '%s' "$pane_json" | python3 -c '
import json, sys
try:
    pane = json.load(sys.stdin)["result"]["pane"]
except Exception:
    sys.exit(0)
print(pane.get("foreground_cwd") or "")
print(pane.get("cwd") or "")
' 2>/dev/null || true
        )
        {
            read -r foreground_cwd || true
            read -r pane_cwd || true
        } <<<"$pane_fields"
    fi

    tried=""
    for candidate in "$foreground_cwd" "$pane_cwd" "${HERDR_ACTIVE_PANE_CWD:-}"; do
        [[ -z "$candidate" || ! -d "$candidate" ]] && continue
        # 3 候補が同一パスなのはよくある。1 回 ≒ 0.6s なので同じ cwd は 2 度叩かない。
        case ":$tried:" in *":$candidate:"*) continue ;; esac
        tried="$tried:$candidate"
        gh_url=$(cd "$candidate" && gh pr view --json url -q .url 2>/dev/null || true)
        if [[ -n "$gh_url" ]]; then
            featured+=("\033[32m★ 現在のPR\033[0m  $gh_url")
            break
        fi
    done
fi

# bash 3.2（macOS 標準）は set -u 下で空配列の展開を unbound variable にするため
# ${arr[@]+...} で守る。
candidates=(${featured[@]+"${featured[@]}"} ${recent[@]+"${recent[@]}"} ${scraped[@]+"${scraped[@]}"})

log "candidates=${#candidates[@]} (pane_id=$pane_id)"
[[ ${#candidates[@]} -gt 0 ]] || notice "GitHub の PR/Issue が見つかりません（pane_id=$pane_id）"

# 表示行の末尾フィールド（URL）で重複除去。先に追加したもの（pane キャッシュ由来）を優先する。
items=$(
    printf '%b\n' "${candidates[@]}" | awk '
        {
            stripped = $0
            gsub(/\033\[[0-9;]*[a-zA-Z]/, "", stripped)
            n = split(stripped, fields, /[ \t]+/)
            url = fields[n]
            if (url != "" && !seen[url]++) print
        }
    '
)

# --- 選択 ---
# fzf の終了コードは 1（候補なし）/ 130（Esc・Ctrl+C）だけをキャンセルとして扱う。
# `|| exit 0` で一括に握り潰すと起動失敗まで「キャンセル」になり、popup が無言で閉じる
# （configs/herdr/new-workspace.sh の教訓、ADR-077）。
# fzf のキャンセル（130）は正常系なので ERR trap の「aborted」を出さない。
trap - ERR
set +e
selected=$(printf '%s\n' "$items" | fzf \
    --ansi \
    --multi \
    --header='enter: open (複数選択可 tab)  esc/ctrl-c: cancel' \
    --reverse --height=100% --border=none 2>>"$LOG_FILE")
fzf_status=$?
set -e
trap 'log "aborted rc=$? line=$LINENO cmd=$BASH_COMMAND"' ERR
case "$fzf_status" in
    0) ;;
    1 | 130)
        log "fzf cancelled (exit=$fzf_status)"
        exit 0
        ;;
    *) die "fzf が異常終了しました (exit=$fzf_status)。詳細は $LOG_FILE" ;;
esac
if [[ -z "$selected" ]]; then
    log "fzf returned empty selection"
    exit 0
fi

# --- 開く ---
if command -v open >/dev/null 2>&1; then
    opener=open
elif command -v xdg-open >/dev/null 2>&1; then
    opener=xdg-open
else
    die 'opener (open / xdg-open) がありません'
fi

while IFS= read -r line; do
    url=$(printf '%s' "$line" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' | awk '{print $NF}')
    if [[ -n "$url" ]]; then
        log "open: $url (pane_id=$pane_id)"
        "$opener" "$url"
    fi
done <<<"$selected"
