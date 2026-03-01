#!/bin/bash
# dotfiles 統合セットアップスクリプト
#
# 使い方:
#   bash scripts/setup.sh [--dry-run] [--profile <name>]
#
# オプション:
#   --dry-run              チェックのみ（変更しない）
#   --profile <name>       プロファイル指定（デフォルト: full）
#
# プロファイル:
#   full    - 全コンポーネント（デフォルト）
#   remote  - fish, nvim, tmux, claude, aqua のみ（リモートマシン用）
#
# 終了コード:
#   0 - 全てOK
#   1 - 問題あり（--dry-run時）または設定失敗

set -euo pipefail

# ========================================
# オプション解析
# ========================================
DRY_RUN=false
PROFILE="full"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --profile)
            PROFILE="${2:-}"
            if [[ -z "$PROFILE" ]]; then
                echo "Error: --profile requires a value" >&2
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ========================================
# パス設定
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$SCRIPT_DIR/setup-manifest.yml"

if [[ ! -f "$MANIFEST" ]]; then
    echo "Error: Manifest not found: $MANIFEST" >&2
    exit 1
fi

# ========================================
# カラー出力
# ========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ========================================
# カウンター
# ========================================
ok_count=0
fix_count=0
fail_count=0
warn_count=0
total_count=0

# ========================================
# Phase 0: 依存パッケージインストール
# ========================================

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

    BREW_PACKAGES=("fish:fish" "tmux:tmux" "nvim:neovim" "jq:jq" "aqua:aqua" "docker:docker" "colima:colima" "docker-compose:docker-compose")
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
        else
            echo "  Installing: ${missing_packages[*]}..."
            brew install "${missing_packages[@]}"
        fi
    else
        echo -e "  ${GREEN}All packages installed${NC}"
    fi

    # Colima: コンテナランタイムが動いていなければ起動
    if command -v colima >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            echo -e "  ${GREEN}colima${NC}\t✓ running"
        else
            if $DRY_RUN; then
                echo -e "  ${YELLOW}colima${NC}\t✗ NOT RUNNING"
                echo "  Fix: colima start"
            else
                echo "  Starting colima..."
                colima start
                echo -e "  ${GREEN}colima${NC}\t✓ started"
            fi
        fi
    fi
    echo ""
fi

# ========================================
# マニフェスト読み込み（YAML → JSON）
# ========================================
MANIFEST_LOCAL="$SCRIPT_DIR/setup-manifest.local.yml"
if [[ -f "$MANIFEST_LOCAL" ]]; then
    MANIFEST_JSON=$(python3 -c "
import yaml, json, sys
def deep_merge(base, overlay):
    for k, v in overlay.items():
        if k in base and isinstance(base[k], dict) and isinstance(v, dict):
            deep_merge(base[k], v)
        else:
            base[k] = v
    return base
base = yaml.safe_load(open(sys.argv[1]))
overlay = yaml.safe_load(open(sys.argv[2]))
print(json.dumps(deep_merge(base, overlay)))
" "$MANIFEST" "$MANIFEST_LOCAL")
else
    MANIFEST_JSON=$(python3 -c "import yaml,json,sys; print(json.dumps(yaml.safe_load(open(sys.argv[1]))))" "$MANIFEST")
fi

# プロファイル検証
COMPONENT_LIST=$(echo "$MANIFEST_JSON" | jq -r --arg p "$PROFILE" '.profiles[$p] // empty | .[]')
if [[ -z "$COMPONENT_LIST" ]]; then
    echo "Error: Unknown profile: $PROFILE" >&2
    echo "Available profiles: $(echo "$MANIFEST_JSON" | jq -r '.profiles | keys | join(", ")')" >&2
    exit 1
fi

# ========================================
# ユーティリティ関数
# ========================================

# ~ を $HOME に展開する
expand_path() {
    local path="$1"
    echo "${path/#\~/$HOME}"
}

# シンボリックリンクを作成する
create_symlink() {
    local link_path="$1"
    local target="$2"

    local parent_dir
    parent_dir="$(dirname "$link_path")"
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
    fi

    ln -s "$target" "$link_path"
}

# シンボリックリンクをチェック・設定する
ensure_symlink() {
    local name="$1"
    local link_path="$2"
    local expected_target="$3"

    total_count=$((total_count + 1))

    # シンボリックリンクが存在するかチェック
    if [[ ! -e "$link_path" && ! -L "$link_path" ]]; then
        if $DRY_RUN; then
            echo -e "  ${RED}$name${NC}\t✗ MISSING"
            echo "    Fix: ln -s $expected_target $link_path"
            fail_count=$((fail_count + 1))
        else
            create_symlink "$link_path" "$expected_target"
            echo -e "  ${GREEN}$name${NC}\t✓ CREATED"
            fix_count=$((fix_count + 1))
        fi
        return
    fi

    # シンボリックリンクであるかチェック
    if [[ ! -L "$link_path" ]]; then
        if $DRY_RUN; then
            echo -e "  ${YELLOW}$name${NC}\t✗ NOT A SYMLINK"
            echo "    Fix: rm -rf $link_path && ln -s $expected_target $link_path"
            fail_count=$((fail_count + 1))
        else
            echo -e "  ${YELLOW}$name${NC}\t✗ NOT A SYMLINK (skipped: remove manually)"
            echo "    Fix: rm -rf $link_path && ln -s $expected_target $link_path"
            fail_count=$((fail_count + 1))
        fi
        return
    fi

    # リンク先が正しいかチェック
    local actual_target
    actual_target=$(readlink "$link_path")
    local expected_normalized="${expected_target%/}"
    local actual_normalized="${actual_target%/}"
    if [[ "$actual_normalized" != "$expected_normalized" ]]; then
        if $DRY_RUN; then
            echo -e "  ${YELLOW}$name${NC}\t✗ WRONG TARGET"
            echo "    Current:  $actual_target"
            echo "    Expected: $expected_target"
            echo "    Fix: rm $link_path && ln -s $expected_target $link_path"
            fail_count=$((fail_count + 1))
        else
            rm "$link_path"
            create_symlink "$link_path" "$expected_target"
            echo -e "  ${GREEN}$name${NC}\t✓ FIXED (was: $actual_target)"
            fix_count=$((fix_count + 1))
        fi
        return
    fi

    # OK
    echo -e "  ${GREEN}$name${NC}\t✓ OK"
    ok_count=$((ok_count + 1))
}

# ファイルコピーを処理する
process_copy() {
    local src="$1"
    local dest="$2"
    local if_missing="$3"

    total_count=$((total_count + 1))
    local display_name
    display_name=$(basename "$dest")

    if [[ "$if_missing" == "true" && -e "$dest" ]]; then
        echo -e "  ${GREEN}$display_name${NC}\t✓ OK (already exists)"
        ok_count=$((ok_count + 1))
        return
    fi

    if [[ ! -e "$dest" ]]; then
        if $DRY_RUN; then
            echo -e "  ${RED}$display_name${NC}\t✗ MISSING"
            echo "    Fix: cp $src $dest"
            fail_count=$((fail_count + 1))
        else
            local parent_dir
            parent_dir="$(dirname "$dest")"
            if [[ ! -d "$parent_dir" ]]; then
                mkdir -p "$parent_dir"
            fi
            cp "$src" "$dest"
            echo -e "  ${GREEN}$display_name${NC}\t✓ COPIED"
            fix_count=$((fix_count + 1))
        fi
    else
        echo -e "  ${GREEN}$display_name${NC}\t✓ OK"
        ok_count=$((ok_count + 1))
    fi
}

# validate: gitconfig 型チェック
validate_gitconfig() {
    local src="$1"
    local dest="$2"
    local display_name
    display_name=$(basename "$dest")

    if [[ ! -e "$dest" ]]; then
        echo -e "  ${YELLOW}$display_name${NC}\tWARN: dest not found (validate skipped)"
        warn_count=$((warn_count + 1))
        return
    fi

    local keys
    keys=$(git config --file "$src" --list | cut -d= -f1)
    local missing=0
    for key in $keys; do
        if ! git config --file "$dest" --get "$key" >/dev/null 2>&1; then
            echo -e "  ${YELLOW}$display_name${NC}\tWARN: key missing: $key"
            missing=$((missing + 1))
        fi
    done

    if [[ $missing -eq 0 ]]; then
        echo -e "  ${GREEN}$display_name${NC}\t✓ validate OK"
    else
        warn_count=$((warn_count + missing))
    fi
}

# validate: json 型チェック
validate_json() {
    local src="$1"
    local dest="$2"
    local display_name
    display_name=$(basename "$dest")

    if [[ ! -e "$dest" ]]; then
        echo -e "  ${YELLOW}$display_name${NC}\tWARN: dest not found (validate skipped)"
        warn_count=$((warn_count + 1))
        return
    fi

    local keys
    keys=$(jq -r 'keys[]' "$src")
    local missing=0
    for key in $keys; do
        if ! jq -e --arg k "$key" 'has($k)' "$dest" >/dev/null 2>&1; then
            echo -e "  ${YELLOW}$display_name${NC}\tWARN: key missing: $key"
            missing=$((missing + 1))
        fi
    done

    if [[ $missing -eq 0 ]]; then
        echo -e "  ${GREEN}$display_name${NC}\t✓ validate OK"
    else
        warn_count=$((warn_count + missing))
    fi
}

# validate ディスパッチ
process_validate() {
    local type="$1"
    local src="$2"
    local dest="$3"

    case "$type" in
        gitconfig)
            validate_gitconfig "$src" "$dest"
            ;;
        json)
            validate_json "$src" "$dest"
            ;;
        *)
            echo -e "  ${YELLOW}Unknown validate type: $type${NC}"
            warn_count=$((warn_count + 1))
            ;;
    esac
}

# ========================================
# メイン実行
# ========================================

if $DRY_RUN; then
    echo "Checking dotfiles setup... (dry-run, profile: $PROFILE)"
else
    echo "Setting up dotfiles... (profile: $PROFILE)"
fi
echo "Dotfiles: $DOTFILES_DIR"
echo ""

# ========================================
# Phase 1: マニフェスト整合性検証（target 実在チェック）
# ========================================
echo -e "${CYAN}Manifest validation:${NC}"
manifest_errors=0

for component in $COMPONENT_LIST; do
    # symlinks の target チェック
    symlink_count=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].symlinks // [] | length')
    if [[ $symlink_count -gt 0 ]]; then
        for i in $(seq 0 $((symlink_count - 1))); do
            target_rel=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].symlinks[$i].target')
            target_abs="$DOTFILES_DIR/$target_rel"
            if [[ ! -e "$target_abs" ]]; then
                echo -e "  ${RED}ERROR${NC}: target not found: $target_rel (component: $component)"
                manifest_errors=$((manifest_errors + 1))
            fi
        done
    fi

    # copies の src チェック
    copies_count=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].copies // [] | length')
    if [[ $copies_count -gt 0 ]]; then
        for i in $(seq 0 $((copies_count - 1))); do
            src_rel=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].copies[$i].src')
            src_abs="$DOTFILES_DIR/$src_rel"
            if [[ ! -e "$src_abs" ]]; then
                echo -e "  ${RED}ERROR${NC}: src not found: $src_rel (component: $component)"
                manifest_errors=$((manifest_errors + 1))
            fi
        done
    fi

    # validate の src チェック
    validate_count=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].validate // [] | length')
    if [[ $validate_count -gt 0 ]]; then
        for i in $(seq 0 $((validate_count - 1))); do
            validate_src_rel=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].validate[$i].src')
            validate_src_abs="$DOTFILES_DIR/$validate_src_rel"
            if [[ ! -e "$validate_src_abs" ]]; then
                echo -e "  ${RED}ERROR${NC}: validate src not found: $validate_src_rel (component: $component)"
                manifest_errors=$((manifest_errors + 1))
            fi
        done
    fi

    # setup スクリプトの存在チェック
    setup_script=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].setup // empty')
    if [[ -n "$setup_script" ]]; then
        setup_abs="$DOTFILES_DIR/$setup_script"
        if [[ ! -f "$setup_abs" ]]; then
            echo -e "  ${RED}ERROR${NC}: setup script not found: $setup_script (component: $component)"
            manifest_errors=$((manifest_errors + 1))
        fi
    fi
done

if [[ $manifest_errors -eq 0 ]]; then
    echo -e "  ${GREEN}All targets exist${NC}"
else
    echo -e "  ${RED}$manifest_errors error(s) found${NC}"
    exit 1
fi
echo ""

# ========================================
# Phase 2: 各コンポーネント処理
# ========================================
for component in $COMPONENT_LIST; do
    echo -e "${CYAN}[$component]${NC}"

    # symlinks 処理
    symlink_count=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].symlinks // [] | length')
    if [[ $symlink_count -gt 0 ]]; then
        for i in $(seq 0 $((symlink_count - 1))); do
            link_rel=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].symlinks[$i].link')
            target_rel=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].symlinks[$i].target')
            link_path=$(expand_path "$link_rel")
            target_abs="$DOTFILES_DIR/$target_rel"
            display_name=$(basename "$link_rel")
            ensure_symlink "$display_name" "$link_path" "$target_abs"
        done
    fi

    # copies 処理（setup スクリプトより先に実行し、if_missing で配布するファイルを確保する）
    copies_count=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].copies // [] | length')
    if [[ $copies_count -gt 0 ]]; then
        for i in $(seq 0 $((copies_count - 1))); do
            src_rel=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].copies[$i].src')
            dest_rel=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].copies[$i].dest')
            copy_profile=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].copies[$i].profile // empty')
            if_missing=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].copies[$i].if_missing // false')

            # プロファイルフィルタ
            if [[ -n "$copy_profile" && "$copy_profile" != "$PROFILE" ]]; then
                continue
            fi

            src_abs="$DOTFILES_DIR/$src_rel"
            dest_path=$(expand_path "$dest_rel")
            process_copy "$src_abs" "$dest_path" "$if_missing"
        done
    fi

    # setup スクリプトがあれば委譲（copies の後に実行）
    setup_script=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].setup // empty')
    if [[ -n "$setup_script" ]]; then
        setup_abs="$DOTFILES_DIR/$setup_script"
        echo -e "  Delegating to $setup_script..."

        # setup_args → SETUP_ prefix 環境変数に変換
        setup_env=()
        setup_args_json=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].setup_args // empty')
        if [[ -n "$setup_args_json" && "$setup_args_json" != "null" ]]; then
            while IFS='=' read -r key value; do
                if [[ -n "$key" && -n "$value" && "$value" != "null" ]]; then
                    env_name="SETUP_$(echo "$key" | tr '[:lower:]' '[:upper:]')"
                    setup_env+=("$env_name=$value")
                fi
            done < <(echo "$setup_args_json" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
        fi

        if [[ ${#setup_env[@]} -gt 0 ]]; then
            if $DRY_RUN; then
                env "${setup_env[@]}" bash "$setup_abs" --dry-run || fail_count=$((fail_count + 1))
            else
                env "${setup_env[@]}" bash "$setup_abs" || fail_count=$((fail_count + 1))
            fi
        else
            if $DRY_RUN; then
                bash "$setup_abs" --dry-run || fail_count=$((fail_count + 1))
            else
                bash "$setup_abs" || fail_count=$((fail_count + 1))
            fi
        fi
    fi

    # validate 処理
    validate_count=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].validate // [] | length')
    if [[ $validate_count -gt 0 ]]; then
        for i in $(seq 0 $((validate_count - 1))); do
            validate_type=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].validate[$i].type')
            validate_src_rel=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].validate[$i].src')
            validate_dest_rel=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].validate[$i].dest')
            validate_src_abs="$DOTFILES_DIR/$validate_src_rel"
            validate_dest_path=$(expand_path "$validate_dest_rel")
            process_validate "$validate_type" "$validate_src_abs" "$validate_dest_path"
        done
    fi

    echo ""
done

# ========================================
# 結果サマリー
# ========================================
echo "========================================"
if $DRY_RUN; then
    if [[ $fail_count -eq 0 && $warn_count -eq 0 ]]; then
        echo -e "Result: ${GREEN}All OK${NC} ($ok_count checked)"
    elif [[ $fail_count -eq 0 ]]; then
        echo -e "Result: ${GREEN}All OK${NC} ($ok_count checked, ${YELLOW}$warn_count warning(s)${NC})"
    else
        echo -e "Result: ${RED}$fail_count issue(s) found${NC} ($ok_count OK, ${YELLOW}$warn_count warning(s)${NC})"
    fi
else
    if [[ $fail_count -eq 0 && $warn_count -eq 0 ]]; then
        echo -e "Result: ${GREEN}All OK${NC} (created/fixed: $fix_count, already OK: $ok_count)"
    elif [[ $fail_count -eq 0 ]]; then
        echo -e "Result: ${GREEN}All OK${NC} (created/fixed: $fix_count, already OK: $ok_count, ${YELLOW}$warn_count warning(s)${NC})"
    else
        echo -e "Result: ${YELLOW}$ok_count OK, $fix_count fixed, $fail_count failed, $warn_count warning(s)${NC}"
    fi
fi

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
exit 0
