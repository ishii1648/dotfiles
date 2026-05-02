#!/bin/bash
# hitl-metrics の binary install + doctor 検証
#
# 前提:
#   - claude / codex の hook 登録は configs/claude/setup.sh, configs/codex/setup.sh が
#     先に処理しているため、本スクリプトは binary 配置と doctor 実行のみを担当する
#   - 旧バージョン（setup サブコマンド未対応）が存在する場合は最新版で上書きする

set -euo pipefail

DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Error: Unknown option: $1" >&2; exit 1 ;;
    esac
done

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- platform detection ---
case "$(uname -s)-$(uname -m)" in
    Darwin-arm64)  ASSET="hitl-metrics_darwin_arm64.tar.gz" ;;
    Darwin-x86_64) ASSET="hitl-metrics_darwin_amd64.tar.gz" ;;
    Linux-x86_64)  ASSET="hitl-metrics_linux_amd64.tar.gz" ;;
    Linux-aarch64) ASSET="hitl-metrics_linux_arm64.tar.gz" ;;
    *)
        echo -e "  ${YELLOW}hitl-metrics${NC}\tunsupported platform: $(uname -s)-$(uname -m), skipping"
        exit 0
        ;;
esac

INSTALL_DIR="$HOME/.local/bin"
BIN_PATH="$INSTALL_DIR/hitl-metrics"
URL="https://github.com/ishii1648/hitl-metrics/releases/latest/download/$ASSET"

# --- install / update ---
needs_install=false
install_reason=""
if [[ ! -x "$BIN_PATH" ]]; then
    needs_install=true
    install_reason="not installed"
elif ! "$BIN_PATH" setup >/dev/null 2>&1; then
    # setup サブコマンドが無い旧バージョンは入れ替える
    needs_install=true
    install_reason="outdated (setup subcommand missing)"
fi

if $needs_install; then
    if $DRY_RUN; then
        echo -e "  ${YELLOW}hitl-metrics${NC}\t$install_reason (would install from $URL)"
    else
        echo "  Installing hitl-metrics ($install_reason) from $URL..."
        mkdir -p "$INSTALL_DIR"
        tmpdir=$(mktemp -d)
        trap 'rm -rf "$tmpdir"' EXIT
        if ! curl -fsSL -o "$tmpdir/$ASSET" "$URL"; then
            echo -e "  ${RED}hitl-metrics${NC}\tdownload failed: $URL"
            exit 1
        fi
        tar -xzf "$tmpdir/$ASSET" -C "$tmpdir"
        install -m 0755 "$tmpdir/hitl-metrics" "$BIN_PATH"
        echo -e "  ${GREEN}hitl-metrics${NC}\tinstalled → $BIN_PATH"
    fi
else
    echo -e "  ${GREEN}hitl-metrics${NC}\t✓ already installed ($BIN_PATH)"
fi

# --- doctor verification ---
if [[ ! -x "$BIN_PATH" ]]; then
    echo "  doctor: SKIP (binary not available)"
    exit 0
fi

# claude/codex のいずれの data dir も無い場合は doctor 実行をスキップ
if [[ ! -d "$HOME/.claude" && ! -d "$HOME/.codex" ]]; then
    echo "  doctor: SKIP (neither ~/.claude nor ~/.codex exists)"
    exit 0
fi

set +e
output=$("$BIN_PATH" doctor 2>&1)
rc=$?
set -e
echo "$output" | sed 's/^/    /'

if [[ $rc -ne 0 ]] || echo "$output" | grep -qE '✗|FAIL'; then
    echo -e "  ${RED}doctor${NC}\t✗ checks failed"
    exit 1
fi
echo -e "  ${GREEN}doctor${NC}\t✓ all checks passed"
