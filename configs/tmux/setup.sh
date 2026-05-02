#!/bin/bash
# tmux プラグインマネージャー (TPM) と plugin の bootstrap
# scripts/setup.sh から委譲される。手動実行も可。
#
# install_plugins は tmux サーバ上で TMUX_PLUGIN_MANAGER_PATH を要求するため、
# 単に bin/install_plugins を呼ぶだけでは "FATAL: Tmux Plugin Manager not configured" になる。
# tmux start-server + source-file で TPM 自身の `run` を一度発火させ、変数を設定してから呼ぶ。
set -euo pipefail

DRY_RUN="${DRY_RUN:-false}"
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

TPM_DIR="$HOME/.tmux/plugins/tpm"
TPM_REPO="https://github.com/tmux-plugins/tpm"
TMUX_CONF="$HOME/.tmux.conf"

if ! command -v tmux >/dev/null 2>&1; then
    echo "  tpm: SKIP (tmux not installed)"
    exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
    if [[ -d "$TPM_DIR/.git" ]]; then
        echo "  tpm: ✓ OK ($TPM_DIR)"
    else
        echo "  tpm: ✗ MISSING ($TPM_DIR)"
        exit 1
    fi
    exit 0
fi

if [[ -d "$TPM_DIR/.git" ]]; then
    echo "  tpm: ✓ already installed"
else
    git clone --depth 1 "$TPM_REPO" "$TPM_DIR"
    echo "  tpm: cloned → $TPM_DIR"
fi

if [[ ! -f "$TMUX_CONF" ]]; then
    echo "  tmux plugins: SKIP ($TMUX_CONF not found)"
    exit 1
fi

# TPM の `run` を発火させて TMUX_PLUGIN_MANAGER_PATH を tmux 環境にセット。
# 既存の attached client がいる server に対しても source-file は冪等。
tmux start-server
tmux source-file "$TMUX_CONF"

if ! tmux show-environment -g TMUX_PLUGIN_MANAGER_PATH >/dev/null 2>&1; then
    echo "  tmux plugins: ✗ TMUX_PLUGIN_MANAGER_PATH not set after source-file"
    exit 1
fi

if [[ -x "$TPM_DIR/bin/install_plugins" ]]; then
    "$TPM_DIR/bin/install_plugins" >/dev/null
    echo "  tmux plugins: install_plugins executed"
else
    echo "  tmux plugins: SKIP (install_plugins not found)"
    exit 1
fi
