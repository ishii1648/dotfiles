#!/bin/bash
# tmux-sidebar の binary install + doctor 検証
#
# 前提:
#   - tmux.conf 側の hook 設定は configs/tmux/tmux.conf に記述済み
#   - hidden_sessions の初回コピーは scripts/setup-manifest.yml の copies で処理する
#   - 本スクリプトは binary 配置と doctor による正当性チェックのみを担当

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
    Darwin-arm64)  ASSET="tmux-sidebar_darwin_arm64.tar.gz" ;;
    Darwin-x86_64) ASSET="tmux-sidebar_darwin_amd64.tar.gz" ;;
    Linux-x86_64)  ASSET="tmux-sidebar_linux_amd64.tar.gz" ;;
    Linux-aarch64) ASSET="tmux-sidebar_linux_arm64.tar.gz" ;;
    *)
        echo -e "  ${YELLOW}tmux-sidebar${NC}\tunsupported platform: $(uname -s)-$(uname -m), skipping"
        exit 0
        ;;
esac

INSTALL_DIR="$HOME/.local/bin"
BIN_PATH="$INSTALL_DIR/tmux-sidebar"
URL="https://github.com/ishii1648/tmux-sidebar/releases/latest/download/$ASSET"

# --- install if missing ---
# tmux-sidebar は自前の `upgrade` サブコマンドを持つので、初回のみ download する。
# 既存 binary の更新は `tmux-sidebar upgrade` をユーザーが任意で実行する想定。
if [[ ! -x "$BIN_PATH" ]]; then
    if $DRY_RUN; then
        echo -e "  ${YELLOW}tmux-sidebar${NC}\tnot installed (would install from $URL)"
    else
        echo "  Installing tmux-sidebar from $URL..."
        mkdir -p "$INSTALL_DIR"
        tmpdir=$(mktemp -d)
        trap 'rm -rf "$tmpdir"' EXIT
        if ! curl -fsSL -o "$tmpdir/$ASSET" "$URL"; then
            echo -e "  ${RED}tmux-sidebar${NC}\tdownload failed: $URL"
            exit 1
        fi
        tar -xzf "$tmpdir/$ASSET" -C "$tmpdir"
        install -m 0755 "$tmpdir/tmux-sidebar" "$BIN_PATH"
        echo -e "  ${GREEN}tmux-sidebar${NC}\tinstalled → $BIN_PATH"
    fi
else
    echo -e "  ${GREEN}tmux-sidebar${NC}\t✓ already installed ($BIN_PATH)"
fi

# --- doctor verification ---
# doctor は ~/.claude/settings.json と ~/.tmux.conf を参照するため、
# tmux / claude コンポーネント処理後にこのスクリプトが呼ばれることを前提とする。
DOCTOR_BIN=""
if command -v tmux-sidebar >/dev/null 2>&1; then
    DOCTOR_BIN=$(command -v tmux-sidebar)
elif [[ -x "$BIN_PATH" ]]; then
    DOCTOR_BIN="$BIN_PATH"
fi

# --- shadow detection ---
# `~/go/bin/tmux-sidebar` 等が PATH 上で `~/.local/bin/tmux-sidebar` を shadow すると、
# setup.sh が install した binary が使われず、`tmux-sidebar upgrade` の対象がブレる。
# 双方が存在し、PATH 解決結果が `~/.local/bin/tmux-sidebar` でない場合に warn。
# bash 3.2 (macOS default) に mapfile が無いため while read で配列化する。
ALL_BINS=()
while IFS= read -r line; do
    [[ -n "$line" ]] && ALL_BINS+=("$line")
done < <(which -a tmux-sidebar 2>/dev/null || true)
if [[ ${#ALL_BINS[@]} -gt 1 && -x "$BIN_PATH" && "$DOCTOR_BIN" != "$BIN_PATH" ]]; then
    echo -e "  ${YELLOW}tmux-sidebar${NC}\twarning: PATH resolves to $DOCTOR_BIN, shadowing $BIN_PATH"
    for b in "${ALL_BINS[@]}"; do echo "    - $b"; done
    echo "    Hint: rm \"${ALL_BINS[0]}\" to let setup.sh-managed binary take effect"
fi

if [[ -z "$DOCTOR_BIN" ]]; then
    echo "  doctor: SKIP (binary not available)"
    exit 0
fi

if [[ ! -f "$HOME/.tmux.conf" ]]; then
    echo "  doctor: SKIP (~/.tmux.conf not found)"
    exit 0
fi

set +e
output=$("$DOCTOR_BIN" doctor 2>&1)
rc=$?
set -e
echo "$output" | sed 's/^/    /'

if [[ $rc -ne 0 ]] || echo "$output" | grep -qE '\[FAIL\]|\[ERROR\]'; then
    echo -e "  ${RED}doctor${NC}\t✗ checks failed (run: tmux-sidebar doctor --yes to auto-apply fixes)"
    exit 1
fi
echo -e "  ${GREEN}doctor${NC}\t✓ all checks passed"
