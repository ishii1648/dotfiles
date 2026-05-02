#!/bin/bash
# macOS 依存パッケージインストール（Phase 0）

# 依存パッケージをインストールする
install_deps() {
    # PyYAML チェック（マニフェスト解析の前提条件）
    if ! python3 -c "import yaml" 2>/dev/null; then
        if [[ "$(uname)" == "Darwin" ]]; then
            if $DRY_RUN; then
                echo -e "${RED}PyYAML is not installed (required for manifest parsing)${NC}"
                echo "  Fix: pip3 install pyyaml"
                exit 1
            fi
            echo "Installing PyYAML..."
            pip3 install --break-system-packages pyyaml 2>/dev/null || pip3 install pyyaml
        else
            echo "Error: PyYAML is not installed. Install it with: pip3 install pyyaml" >&2
            exit 1
        fi
    fi

    # macOS: Homebrew パッケージインストール
    if [[ "$(uname)" == "Darwin" ]]; then
        echo -e "${CYAN}Package dependencies (macOS):${NC}"
        if ! command -v brew >/dev/null 2>&1; then
            echo -e "  ${RED}Homebrew is not installed${NC}"
            echo "  Install from https://brew.sh"
            exit 1
        fi

        BREW_PACKAGES=(
            "fish:fish"
            "tmux:tmux"
            "nvim:neovim"
            "jq:jq"
            "aqua:aqua"
            # GNU tools (BSD 版を上書きせず g- prefix で共存)
            "ggrep:grep"
            "gsed:gnu-sed"
            "gtar:gnu-tar"
            "gawk:gawk"
            "gfind:findutils"
            "gdate:coreutils"
        )
        if [[ "${PROFILE:-full}" != "linux" ]]; then
            BREW_PACKAGES+=("docker:docker" "colima:colima" "docker-compose:docker-compose")
        fi
        missing_packages=()

        for entry in "${BREW_PACKAGES[@]}"; do
            cmd="${entry%%:*}"
            formula="${entry##*:}"
            if command -v "$cmd" >/dev/null 2>&1; then
                echo -e "  ${GREEN}${formula}${NC}\t✓ installed"
            else
                echo -e "  ${RED}${formula}${NC}\t✗ MISSING"
                missing_packages+=("$formula")
            fi
        done

        if [[ ${#missing_packages[@]} -gt 0 ]]; then
            if $DRY_RUN; then
                echo "  Fix: brew install ${missing_packages[*]}"
            elif confirm "  Install missing packages: ${missing_packages[*]}?"; then
                echo "  Installing: ${missing_packages[*]}..."
                if [[ "$INTERACTIVE" == "false" ]]; then
                    HOMEBREW_NO_AUTO_UPDATE=1 brew install "${missing_packages[@]}"
                else
                    brew install "${missing_packages[@]}"
                fi
            else
                echo -e "  ${YELLOW}Skipped package installation${NC}"
            fi
        else
            echo -e "  ${GREEN}All packages installed${NC}"
        fi

        # docker compose plugin: brew formula は /opt/homebrew/lib/docker/cli-plugins/
        # に plugin バイナリを置くが Docker CLI の探索パス (~/.docker/cli-plugins/) には
        # 自動リンクしないので、ここで symlink を貼って `docker compose` を有効化する
        COMPOSE_PLUGIN_SRC="/opt/homebrew/lib/docker/cli-plugins/docker-compose"
        COMPOSE_PLUGIN_DEST="$HOME/.docker/cli-plugins/docker-compose"
        if [[ "${PROFILE:-full}" != "linux" ]] && [[ -f "$COMPOSE_PLUGIN_SRC" ]]; then
            if [[ -L "$COMPOSE_PLUGIN_DEST" && "$(readlink "$COMPOSE_PLUGIN_DEST")" == "$COMPOSE_PLUGIN_SRC" ]]; then
                echo -e "  ${GREEN}docker compose plugin${NC}\t✓ linked"
            elif $DRY_RUN; then
                echo -e "  ${YELLOW}docker compose plugin${NC}\t✗ NOT LINKED"
                echo "  Fix: mkdir -p ~/.docker/cli-plugins && ln -sf $COMPOSE_PLUGIN_SRC $COMPOSE_PLUGIN_DEST"
            else
                mkdir -p "$HOME/.docker/cli-plugins"
                ln -sf "$COMPOSE_PLUGIN_SRC" "$COMPOSE_PLUGIN_DEST"
                echo -e "  ${GREEN}docker compose plugin${NC}\t✓ linked"
            fi
        fi

        # Colima: コンテナランタイムが動いていなければ起動
        if [[ "${PROFILE:-full}" != "linux" ]] && command -v colima >/dev/null 2>&1; then
            if docker info >/dev/null 2>&1; then
                echo -e "  ${GREEN}colima${NC}\t✓ running"
            else
                if $DRY_RUN; then
                    echo -e "  ${YELLOW}colima${NC}\t✗ NOT RUNNING"
                    echo "  Fix: colima start --cpu 4 --memory 8"
                elif confirm "  Start colima? (4 CPU / 8 GiB)"; then
                    echo "  Starting colima..."
                    colima start --cpu 4 --memory 8
                    echo -e "  ${GREEN}colima${NC}\t✓ started"
                else
                    echo -e "  ${YELLOW}colima${NC}\tskipped"
                fi
            fi
        fi
        echo ""
    fi
}
