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
if [[ "$HERDR_BIN" == "${HERDR_INSTALL_DIR}/herdr" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  herdr: ✓ install-script managed ($HERDR_BIN)"
    else
        echo "  herdr: updating (install-script managed)..."
        herdr update || echo "  herdr update: ✗ failed (continuing)"
    fi
else
    echo "  herdr: ⚠ managed outside install script ($HERDR_BIN) — 'herdr update' unavailable; update via its package manager"
fi

# 対象エージェント。手元で使うものだけに絞る（`herdr integration status` で全一覧）。
AGENTS=(claude codex)

# `herdr integration status` の行頭は "<agent>: current (vN) (<path>)" /
# "<agent>: not installed (<path>)" 形式。current 以外は install が必要。
is_current() {
    grep -qE "^${1}: current" <<<"$2"
}

if [[ "$DRY_RUN" == "true" ]]; then
    status_out="$(herdr integration status 2>/dev/null || true)"
    rc=0
    for agent in "${AGENTS[@]}"; do
        if is_current "$agent" "$status_out"; then
            echo "  herdr integration ${agent}: ✓ OK"
        else
            echo "  herdr integration ${agent}: ✗ MISSING"
            rc=1
        fi
    done
    if [[ -L "$HOME/.config/herdr/config.toml" ]]; then
        herdr config check >/dev/null 2>&1 \
            && echo "  herdr config: ✓ OK" \
            || { echo "  herdr config: ✗ INVALID"; rc=1; }
    fi
    exit "$rc"
fi

# current なら何もしない（install は毎回 JSON を書き直すため、symlink 経由で
# dotfiles の configs/codex/hooks.json に無用な差分が出る）
status_out="$(herdr integration status 2>/dev/null || true)"
for agent in "${AGENTS[@]}"; do
    if is_current "$agent" "$status_out"; then
        echo "  herdr integration ${agent}: ✓ already current"
        continue
    fi
    if herdr integration install "$agent" >/dev/null 2>&1; then
        echo "  herdr integration ${agent}: installed"
        # herdr は JSON を書き戻す際に末尾改行を落とすため補う（差分ノイズ抑制）
        for f in "$HOME/.codex/hooks.json" "$HOME/.claude/settings.json"; do
            [[ -f "$f" && -n "$(tail -c 1 "$f")" ]] && printf '\n' >>"$f"
        done
    else
        echo "  herdr integration ${agent}: ✗ install failed"
        exit 1
    fi
done

herdr config check
