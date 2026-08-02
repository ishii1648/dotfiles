#!/usr/bin/env bash
# herdr custom command (prefix+u): statusline に表示中の PR をブラウザで開く
#
# 旧 tmux 版（configs/tmux/fzf-pr-popup.sh）は capture-pane した画面から URL を
# 総なめして fzf で選ばせていたが、herdr の pane read は OSC 8 ハイパーリンクの
# URL を復元できない（cell グリッドから再構成するため、アンカーテキストしか残らない）。
# 一方 statusline.js は表示中の PR を /tmp/gh-pr-<md5(cwd)> に書き出している
# （statusline.js の "tmux-fzf-url フィルター用キャッシュ" ブロック、形式 "<number> <url>"）。
# 「statusline に出ている PR へ飛ぶ」という用途にはこれが一次情報そのものなので、
# 画面スクレイプをやめてキャッシュ直読みに切り替える。
#
# type = "shell" でバックグラウンド実行されるため stdout は誰も見ない。
# フィードバック手段が二重になっているのは意図的:
#   - notification: 即時に気づける。ただし config.toml の [ui.toast] delivery = "off"
#     では何も出ないため、これ単独では成否を判別できない。
#   - ログ: delivery 設定に依存せず必ず残る。失敗時の切り分けはこちらを見る。
set -euo pipefail

LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/herdr/open-pr.log"

log() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || return 0
    printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" >>"$LOG_FILE" 2>/dev/null || true
}

notify() {
    local title="$1"
    shift
    local body="${1:-}"
    log "${title}: ${body:-ok}"
    if [[ -n "$body" ]]; then
        herdr notification show "$title" --body "$body" --sound none >/dev/null 2>&1 || true
    else
        herdr notification show "$title" --sound none >/dev/null 2>&1 || true
    fi
}

md5_hex() {
    # statusline.js の crypto.createHash('md5').update(cwd) と一致させる。
    # 末尾改行が混ざるとハッシュがズレるので printf '%s' で渡すこと。
    if command -v md5 >/dev/null 2>&1; then
        printf '%s' "$1" | md5
    else
        printf '%s' "$1" | md5sum | cut -d' ' -f1
    fi
}

# --- 起動元ペインの cwd を特定 ---
# herdr は custom command に HERDR_ACTIVE_PANE_CWD を渡す。取れない場合のみ API を叩く。
cwd="${HERDR_ACTIVE_PANE_CWD:-}"
fallback_cwd=""
if pane_json=$(herdr pane current --current 2>/dev/null); then
    fallback_cwd=$(
        printf '%s' "$pane_json" | python3 -c '
import json, sys
try:
    pane = json.load(sys.stdin)["result"]["pane"]
except Exception:
    sys.exit(0)
print(pane.get("foreground_cwd") or pane.get("cwd") or "")
' 2>/dev/null || true
    )
fi
[[ -z "$cwd" ]] && cwd="$fallback_cwd"

if [[ -z "$cwd" ]]; then
    notify 'herdr-open-pr' 'ペインの cwd を特定できませんでした'
    exit 1
fi

# --- PR URL を解決 ---
# 1) statusline のキャッシュ（表示中の PR と完全一致・ネットワーク不要）
# 2) worktree 等で statusline 側の cwd がズレている場合に備えたもう一方の cwd
# 3) 最後に gh へ直接問い合わせ
pr_url=""
for candidate in "$cwd" "$fallback_cwd"; do
    [[ -z "$candidate" ]] && continue
    cache_file="/tmp/gh-pr-$(md5_hex "$candidate")"
    if [[ -f "$cache_file" ]]; then
        pr_url=$(cut -d' ' -f2 <"$cache_file")
        [[ -n "$pr_url" ]] && break
    fi
done

if [[ -z "$pr_url" ]]; then
    pr_url=$(cd "$cwd" && gh pr view --json url -q .url 2>/dev/null || true)
fi

if [[ -z "$pr_url" ]]; then
    notify 'herdr-open-pr' "PR が見つかりません: $cwd"
    exit 0
fi

# --- 開く ---
if command -v open >/dev/null 2>&1; then
    opener=open
elif command -v xdg-open >/dev/null 2>&1; then
    opener=xdg-open
else
    notify 'herdr-open-pr' 'opener (open / xdg-open) がありません'
    exit 1
fi

log "open: $pr_url (cwd=$cwd, HERDR_ACTIVE_PANE_CWD=${HERDR_ACTIVE_PANE_CWD:-<unset>})"
"$opener" "$pr_url"
