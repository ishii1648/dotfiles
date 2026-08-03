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

# herdr サーバから起動されるため、PATH はログインシェル（fish）のものと一致する保証がない。
# gh は aqua 管理なので明示的に前置する（ADR-077/079 の new-workspace.sh / agent-picker.sh と同型）。
export PATH="$HOME/.local/share/aquaproj-aqua/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
# aqua の bin は proxy なので、実体の解決には設定ファイルが要る。$cwd は呼び出し元ペインの
# cwd（statusline キャッシュが無い repo だと gh pr view フォールバックに落ちる）で、
# dotfiles 以外だと aqua がその repo の aqua.yaml を探し `command is not found` で落ちる。
# fish の conf.d と同じグローバル設定を明示して cwd 非依存にする（既に環境にあれば尊重）。
export AQUA_GLOBAL_CONFIG="${AQUA_GLOBAL_CONFIG:-$HOME/.config/aquaproj-aqua/aqua.yaml}"
# AQUA_GLOBAL_CONFIG だけでは cwd 非依存にならない: aqua は cwd から辿ったローカル aqua.yaml も
# 探索してマージするため、呼び出し元 repo が同名パッケージ（gh 等）を別バージョンで固定して
# いると、そちらが優先解決されてしまう（agent-picker.sh で sre-hub の fzf@v0.56.3 が優先され
# unknown option エラーになる実害を確認）。AQUA_CONFIG で dotfiles の aqua.yaml 1 本に固定し、
# cwd 方向の探索自体を無効化する。
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

md5_hex() {
    # statusline.js の crypto.createHash('md5').update(cwd) と一致させる。
    # 末尾改行が混ざるとハッシュがズレるので printf '%s' で渡すこと。
    if command -v md5 >/dev/null 2>&1; then
        printf '%s' "$1" | md5
    else
        printf '%s' "$1" | md5sum | cut -d' ' -f1
    fi
}

# --- 起動元ペインの cwd / session_id を特定 ---
# HERDR_ACTIVE_PANE_CWD は pane 登録時の cwd（workspace 作成時のベースディレクトリ）
# であり、pane 内でシェルが worktree 等へ cd した後の実際の作業先（foreground_cwd）を
# 反映しない。cwd と foreground_cwd が食い違うと、無関係なブランチ／PR を開いてしまう
# （例: workspace 作成時は sre-hub 本体、その後 worktree に cd して作業した場合）。
# そのため cwd 自体は API を叩いて foreground_cwd を優先し、HERDR_ACTIVE_PANE_CWD は API が
# 失敗した場合のみのフォールバックとする。
# ただし foreground_cwd も万能ではない: 実測で「pane 内の何らかの foreground 子プロセスの
# cwd」を返すだけと判明しており、Claude Code が spawn した MCP サーバー等の無関係な cwd
# （例: aws-api-mcp の一時 workdir）を拾うことがある。この場合 statusline 側のキャッシュ
# キー（実際の作業ディレクトリの md5）と一致せず PR が見つからない。そのため session_id
# （agent_session.value、Claude Code の session_id と一致する不変な相関キー）を優先して
# 使い、cwd ベースの照合は次点のフォールバックにする。
cwd=""
session_id=""
if pane_json=$(herdr pane current --current 2>/dev/null); then
    cwd=$(
        printf '%s' "$pane_json" | python3 -c '
import json, sys
try:
    pane = json.load(sys.stdin)["result"]["pane"]
except Exception:
    sys.exit(0)
print(pane.get("foreground_cwd") or pane.get("cwd") or "")
' 2>/dev/null || true
    )
    session_id=$(
        printf '%s' "$pane_json" | python3 -c '
import json, sys
try:
    pane = json.load(sys.stdin)["result"]["pane"]
except Exception:
    sys.exit(0)
print((pane.get("agent_session") or {}).get("value") or "")
' 2>/dev/null || true
    )
fi
fallback_cwd="${HERDR_ACTIVE_PANE_CWD:-}"
[[ -z "$cwd" ]] && cwd="$fallback_cwd"

if [[ -z "$cwd" && -z "$session_id" ]]; then
    notify 'herdr-open-pr' 'ペインの cwd / session を特定できませんでした'
    exit 1
fi

# --- PR URL を解決 ---
# 1) session_id ベースのキャッシュ（cwd 推定の誤りに影響されない一次情報）
# 2) statusline の cwd ベースのキャッシュ（表示中の PR と完全一致・ネットワーク不要）
# 3) worktree 等で statusline 側の cwd がズレている場合に備えたもう一方の cwd
# 4) 最後に gh へ直接問い合わせ
pr_url=""
if [[ -n "$session_id" ]]; then
    session_cache_file="/tmp/gh-pr-session-${session_id}"
    if [[ -f "$session_cache_file" ]]; then
        pr_url=$(cut -d' ' -f2 <"$session_cache_file")
    fi
fi

if [[ -z "$pr_url" ]]; then
    for candidate in "$cwd" "$fallback_cwd"; do
        [[ -z "$candidate" ]] && continue
        cache_file="/tmp/gh-pr-$(md5_hex "$candidate")"
        if [[ -f "$cache_file" ]]; then
            pr_url=$(cut -d' ' -f2 <"$cache_file")
            [[ -n "$pr_url" ]] && break
        fi
    done
fi

if [[ -z "$pr_url" && -n "$cwd" ]]; then
    pr_url=$(cd "$cwd" && gh pr view --json url -q .url 2>/dev/null || true)
fi

if [[ -z "$pr_url" ]]; then
    notify 'herdr-open-pr' "PR が見つかりません: cwd=$cwd session_id=${session_id:-<unset>}"
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

log "open: $pr_url (cwd=$cwd, session_id=${session_id:-<unset>}, HERDR_ACTIVE_PANE_CWD=${HERDR_ACTIVE_PANE_CWD:-<unset>})"
"$opener" "$pr_url"
