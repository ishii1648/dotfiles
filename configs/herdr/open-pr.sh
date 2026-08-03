#!/usr/bin/env bash
# herdr custom command (prefix+u): statusline に表示中の PR をブラウザで開く
#
# 照合は pane_id 一本。statusline.js が HERDR_PANE_ID（herdr が pane のシェルに
# 与え、Claude Code 経由で statusline まで継承される）をキーに表示中 PR を
# /tmp/gh-pr-pane-<pane_id> へ書き出すので、フォーカス中 pane の pane_id で
# 直読みする。pane_id は `herdr pane current` が常に返すフィールドであり、
# 旧実装が使っていた agent_session（SessionStart hook の配線が消えると報告されず
# 全滅する）や cwd 推測（foreground_cwd が MCP サーバー等の無関係な cwd を拾う）の
# ような追加配線・ヒューリスティクスを必要としない。
# キャッシュが無い pane（Claude Code が動いていない素のシェル等）だけ
# gh pr view へフォールバックする。
#
# type = "shell" でバックグラウンド実行されるため stdout は誰も見ない。
# フィードバック手段が二重になっているのは意図的:
#   - notification: 即時に気づける。ただし config.toml の [ui.toast] delivery = "off"
#     では何も出ないため、これ単独では成否を判別できない。
#   - ログ: delivery 設定に依存せず必ず残る。失敗時の切り分けはこちらを見る。
set -euo pipefail

# herdr サーバから起動されるため、PATH はログインシェル（fish）のものと一致する保証がない。
# gh は aqua 管理なので明示的に前置する（ADR-077/079 の new-workspace.sh / agent-picker.sh と同型）。
export PATH="$HOME/.local/share/aquaproj-aqua/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
# aqua の bin は proxy なので、実体の解決には設定ファイルが要る。フォールバックの
# gh pr view は呼び出し元ペインの cwd で走るため、dotfiles 以外の repo でも aqua が
# 解決できるようグローバル設定を明示して cwd 非依存にする（既に環境にあれば尊重）。
export AQUA_GLOBAL_CONFIG="${AQUA_GLOBAL_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"
# AQUA_GLOBAL_CONFIG だけでは cwd 非依存にならない: aqua は cwd から辿ったローカル
# aqua.yaml も探索してマージするため、呼び出し元 repo が同名パッケージ（gh 等）を
# 別バージョンで固定していると、そちらが優先解決されてしまう。AQUA_CONFIG で
# dotfiles の aqua.yaml 1 本に固定し、cwd 方向の探索自体を無効化する。
export AQUA_CONFIG="${AQUA_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"

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

# --- フォーカス中 pane を特定 ---
pane_id=""
foreground_cwd=""
pane_cwd=""
if pane_json=$(herdr pane current --current 2>/dev/null); then
    pane_fields=$(
        printf '%s' "$pane_json" | python3 -c '
import json, sys
try:
    pane = json.load(sys.stdin)["result"]["pane"]
except Exception:
    sys.exit(0)
print(pane.get("pane_id") or "")
print(pane.get("foreground_cwd") or "")
print(pane.get("cwd") or "")
' 2>/dev/null || true
    )
    {
        read -r pane_id || true
        read -r foreground_cwd || true
        read -r pane_cwd || true
    } <<<"$pane_fields"
fi

# --- PR URL を解決 ---
# 1) statusline が書いた pane_id キャッシュ（表示中の PR と完全一致・ネットワーク不要）
# 2) gh pr view（Claude Code が動いていない pane 向け。foreground_cwd → cwd →
#    HERDR_ACTIVE_PANE_CWD の順に試す）
pr_url=""
if [[ -n "$pane_id" ]]; then
    pane_cache="/tmp/gh-pr-pane-${pane_id//[!A-Za-z0-9_-]/_}"
    if [[ -f "$pane_cache" ]]; then
        pr_url=$(cut -d' ' -f2 <"$pane_cache")
    fi
fi

if [[ -z "$pr_url" ]]; then
    for candidate in "$foreground_cwd" "$pane_cwd" "${HERDR_ACTIVE_PANE_CWD:-}"; do
        [[ -z "$candidate" || ! -d "$candidate" ]] && continue
        pr_url=$(cd "$candidate" && gh pr view --json url -q .url 2>/dev/null || true)
        [[ -n "$pr_url" ]] && break
    done
fi

if [[ -z "$pr_url" ]]; then
    notify 'herdr-open-pr' "PR が見つかりません: pane_id=${pane_id:-<unset>} cwd=${foreground_cwd:-${pane_cwd:-${HERDR_ACTIVE_PANE_CWD:-<unset>}}}"
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

log "open: $pr_url (pane_id=${pane_id:-<unset>})"
"$opener" "$pr_url"
