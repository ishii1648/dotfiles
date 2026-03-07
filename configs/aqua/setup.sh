#!/bin/bash
set -euo pipefail

# オプション解析
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# カラー出力
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# aqua 本体が未インストールならスキップ（Linux Docker 環境等）
if ! command -v aqua >/dev/null 2>&1; then
    echo -e "  ${YELLOW}aqua not found, skipping aqua install${NC}"
    exit 0
fi

if $DRY_RUN; then
    echo -e "  ${GREEN}aqua${NC}\t✓ installed"
else
    echo "  Running aqua install..."
    aqua install -l

    # docker buildx: aqua バイナリを Docker CLI プラグインとして配置
    BUILDX_BIN=$(aqua which docker-cli-plugin-docker-buildx 2>/dev/null || true)
    if [ -n "$BUILDX_BIN" ]; then
        mkdir -p "$HOME/.docker/cli-plugins"
        ln -sf "$BUILDX_BIN" "$HOME/.docker/cli-plugins/docker-buildx"
        echo -e "  ${GREEN}docker-buildx${NC}\tsymlinked to CLI plugins"
    fi
fi
