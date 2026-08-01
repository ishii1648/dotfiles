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
set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

if ! command -v herdr >/dev/null 2>&1; then
    echo "  herdr: SKIP (herdr not installed)"
    exit 0
fi

# 対象エージェント。手元で使うものだけに絞る（`herdr integration status` で全一覧）。
AGENTS=(claude codex)

if [[ "$DRY_RUN" == "true" ]]; then
    status_out="$(herdr integration status 2>/dev/null || true)"
    rc=0
    for agent in "${AGENTS[@]}"; do
        if grep -q "^${agent}: installed" <<<"$status_out"; then
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

# install は冪等（既に入っていれば上書き更新される）
for agent in "${AGENTS[@]}"; do
    if herdr integration install "$agent" >/dev/null 2>&1; then
        echo "  herdr integration ${agent}: installed"
    else
        echo "  herdr integration ${agent}: ✗ install failed"
        exit 1
    fi
done

herdr config check
