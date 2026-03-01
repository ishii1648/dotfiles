#!/bin/bash
# dotfiles 統合セットアップスクリプト
#
# 使い方:
#   bash scripts/setup.sh [--dry-run] [--profile <name>] [--interactive|--non-interactive]
#
# オプション:
#   --dry-run              チェックのみ（変更しない）
#   --profile <name>       プロファイル指定（デフォルト: full）
#   --interactive          確認プロンプトを表示する
#   --non-interactive      確認なしで自動続行する
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
INTERACTIVE="auto"

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
        --interactive)
            INTERACTIVE="true"
            shift
            ;;
        --non-interactive)
            INTERACTIVE="false"
            shift
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# TTY 自動判定
if [[ "$INTERACTIVE" == "auto" ]]; then
    if [[ -t 0 ]]; then INTERACTIVE=true; else INTERACTIVE=false; fi
fi

# --dry-run 時は強制 non-interactive
if $DRY_RUN; then INTERACTIVE=false; fi

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
# ライブラリ読み込み
# ========================================
for lib in "$SCRIPT_DIR"/lib/*.sh; do
    source "$lib"
done

# 確認プロンプト（non-interactive 時は自動 yes）
confirm() {
    local msg="$1"
    if [[ "$INTERACTIVE" == "false" ]]; then return 0; fi
    read -r -p "$msg [Y/n] " answer
    [[ -z "$answer" || "$answer" =~ ^[Yy] ]]
}

# ========================================
# Phase 0: 依存パッケージインストール
# ========================================
install_deps

# ========================================
# マニフェスト読み込み
# ========================================
load_manifest "$MANIFEST"
validate_profile "$PROFILE"

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

    copies_count=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].copies // [] | length')
    if [[ $copies_count -gt 0 ]]; then
        for i in $(seq 0 $((copies_count - 1))); do
            src_rel=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].copies[$i].src')
            dest_rel=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].copies[$i].dest')
            copy_profile=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].copies[$i].profile // empty')
            if_missing=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" --argjson i "$i" '.components[$c].copies[$i].if_missing // false')

            if [[ -n "$copy_profile" && "$copy_profile" != "$PROFILE" ]]; then
                continue
            fi

            src_abs="$DOTFILES_DIR/$src_rel"
            dest_path=$(expand_path "$dest_rel")
            process_copy "$src_abs" "$dest_path" "$if_missing"
        done
    fi

    setup_script=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].setup // empty')
    if [[ -n "$setup_script" ]]; then
        setup_abs="$DOTFILES_DIR/$setup_script"
        echo -e "  Delegating to $setup_script..."

        setup_env=("SETUP_INTERACTIVE=$INTERACTIVE")
        setup_args_json=$(echo "$MANIFEST_JSON" | jq -r --arg c "$component" '.components[$c].setup_args // empty')
        if [[ -n "$setup_args_json" && "$setup_args_json" != "null" ]]; then
            while IFS='=' read -r key value; do
                if [[ -n "$key" && -n "$value" && "$value" != "null" ]]; then
                    env_name="SETUP_$(echo "$key" | tr '[:lower:]' '[:upper:]')"
                    setup_env+=("$env_name=$value")
                fi
            done < <(echo "$setup_args_json" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
        fi

        if $DRY_RUN; then
            env "${setup_env[@]}" bash "$setup_abs" --dry-run || fail_count=$((fail_count + 1))
        else
            env "${setup_env[@]}" bash "$setup_abs" || fail_count=$((fail_count + 1))
        fi
    fi

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
