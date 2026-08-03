#!/bin/bash
# herdr の agent integration bootstrap（ADR-076 Spike）
# scripts/setup.sh から委譲される。手動実行も可。
#
# `herdr integration install <agent>` は各エージェントのフックディレクトリに
# herdr-agent-state.sh を展開し、エージェントのライフサイクルを herdr に報告させる。
# これが入っていないと、サイドバーの状態表示はスクリーンパターンマッチのみに頼るため
# 精度が落ちる（誤検出・イベント不発火）。
#
# NOTE: 展開先（~/.claude/hooks/, ~/.codex/）は dotfiles の symlink 管理下ではなく
#       herdr 自身が所有する。バージョン更新時に再実行して追従させる。
#
# 重要: install は hook 定義をエージェントの設定ファイル（~/.claude/settings.json,
#       ~/.codex/hooks.json）にも書き込む。~/.codex/hooks.json は dotfiles への
#       symlink なので、herdr は symlink を追跡して **dotfiles の実体を書き換える**
#       （JSON のキー順ソートと末尾改行の削除という副作用も伴う）。そのため
#       `herdr integration status` が current を返す間は install を実行しない。
set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# herdr 本体の導入・更新は herdr.dev 公式 install script（$HOME/.local/bin/herdr に
# 配置、sudo 不要）で管理する。Homebrew/mise/Nix で入れた場合は `herdr update` が
# 使えない（各パッケージマネージャ側での更新が必要になる）ため、install script 経由
# であることを固定する。
HERDR_INSTALL_DIR="${HERDR_INSTALL_DIR:-$HOME/.local/bin}"
HERDR_INSTALL_SCRIPT_URL="https://herdr.dev/install.sh"

if ! command -v herdr >/dev/null 2>&1; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  herdr: ✗ NOT INSTALLED (would install via ${HERDR_INSTALL_SCRIPT_URL})"
        exit 1
    fi
    echo "  herdr: not found, installing via install script..."
    if ! curl -fsSL "$HERDR_INSTALL_SCRIPT_URL" | sh; then
        echo "  herdr: ✗ install script failed"
        exit 1
    fi
    hash -r
    if ! command -v herdr >/dev/null 2>&1; then
        echo "  herdr: ✗ install script ran but herdr still not on PATH (check ${HERDR_INSTALL_DIR})"
        exit 1
    fi
fi

HERDR_BIN="$(command -v herdr)"
if [[ "$HERDR_BIN" != "${HERDR_INSTALL_DIR}/herdr" ]]; then
    echo "  herdr: ⚠ managed outside install script ($HERDR_BIN) — 'herdr update' unavailable; update via its package manager"
elif [[ "$DRY_RUN" == "true" ]]; then
    echo "  herdr: ✓ install-script managed ($HERDR_BIN)"
elif [[ -n "${HERDR_ENV:-}" ]]; then
    # herdr は稼働中セッションの内側からの自己更新を拒否する（"run `herdr update`
    # outside herdr after detaching from the session"）。ghostty の command が herdr に
    # なった（ADR-076 Phase 3）ため setup.sh は通常 herdr 内で実行され、ここに来る。
    echo "  herdr update: SKIP (inside a herdr session; detach and run 'herdr update')"
else
    echo "  herdr: updating (install-script managed)..."
    herdr update || echo "  herdr update: ✗ failed (continuing)"
fi

# 対象エージェント。手元で使うものだけに絞る（`herdr integration status` で全一覧）。
# codex は linux profile（Docker e2e 等）では導入されないため、CLI が PATH にある場合
# だけ対象にする。full profile では manifest 上 codex コンポーネントが herdr より先に
# 実行されるので、この時点で codex は入っている。
AGENTS=(claude)
if command -v codex >/dev/null 2>&1; then
    AGENTS+=(codex)
fi

# `herdr integration status` の行頭は "<agent>: current (vN) (<path>)" /
# "<agent>: not installed (<path>)" 形式。current 以外は install が必要。
is_current() {
    grep -qE "^${1}: current" <<<"$2"
}

# status は hook スクリプト自体（herdr-agent-state.sh）のバージョンしか見ない。
# install がエージェント設定ファイルへ書き込む配線（hook エントリ）は、dotfiles の
# configs/claude/settings.json を ~/.claude/settings.json へ同期し直す等で消えることが
# あり、その場合も status は current を返し続ける。配線が無いと agent_session が herdr に
# 報告されず prefix+u（herdr-open-pr）の session_id 照合が壊れるため、独立に検証する。
wiring_file() {
    case "$1" in
        claude) printf '%s' "$HOME/.claude/settings.json" ;;
        codex)  printf '%s' "$HOME/.codex/hooks.json" ;;
        *)      printf '' ;;
    esac
}

has_wiring() {
    local f
    f="$(wiring_file "$1")"
    [[ -n "$f" && -f "$f" ]] && grep -q 'herdr-agent-state' "$f"
}

if [[ "$DRY_RUN" == "true" ]]; then
    status_out="$(herdr integration status 2>/dev/null || true)"
    rc=0
    for agent in "${AGENTS[@]}"; do
        if ! is_current "$agent" "$status_out"; then
            echo "  herdr integration ${agent}: ✗ MISSING"
            rc=1
        elif ! has_wiring "$agent"; then
            echo "  herdr integration ${agent}: ✗ WIRING MISSING ($(wiring_file "$agent"))"
            rc=1
        else
            echo "  herdr integration ${agent}: ✓ OK"
        fi
    done
    if [[ -L "$HOME/.config/herdr/config.toml" ]]; then
        herdr config check >/dev/null 2>&1 \
            && echo "  herdr config: ✓ OK" \
            || { echo "  herdr config: ✗ INVALID"; rc=1; }
    fi
    exit "$rc"
fi

# current かつ配線あり なら何もしない（install は毎回 JSON を書き直すため、symlink 経由で
# dotfiles の configs/codex/hooks.json に無用な差分が出る）
status_out="$(herdr integration status 2>/dev/null || true)"
for agent in "${AGENTS[@]}"; do
    if is_current "$agent" "$status_out" && has_wiring "$agent"; then
        echo "  herdr integration ${agent}: ✓ already current"
        continue
    fi
    if is_current "$agent" "$status_out"; then
        echo "  herdr integration ${agent}: wiring missing in $(wiring_file "$agent"), re-installing..."
    fi
    # 失敗時の原因が分かるよう stderr は握りつぶさず残す（CI で "install failed" だけが
    # 出て原因が追えない状態だったため）
    install_out=""
    if install_out="$(herdr integration install "$agent" 2>&1)"; then
        echo "  herdr integration ${agent}: installed"
        # herdr は JSON を書き戻す際に末尾改行を落とすため補う（差分ノイズ抑制）
        for f in "$HOME/.codex/hooks.json" "$HOME/.claude/settings.json"; do
            [[ -f "$f" && -n "$(tail -c 1 "$f")" ]] && printf '\n' >>"$f"
        done
    else
        echo "  herdr integration ${agent}: ✗ install failed"
        [[ -n "$install_out" ]] && echo "$install_out" | sed 's/^/    /'
        exit 1
    fi
done

herdr config check
