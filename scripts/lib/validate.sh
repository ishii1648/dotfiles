#!/bin/bash
# 設定ファイルバリデーション関数

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

    # hooks スクリプト存在チェック（~/.claude/scripts/ 参照のみ対象）
    if jq -e 'has("hooks")' "$dest" >/dev/null 2>&1; then
        local hook_errors=0
        while IFS= read -r cmd; do
            local script_path
            script_path=$(echo "$cmd" | awk '{print $1}' | sed "s|~|$HOME|g")
            if { [[ "$script_path" == "$HOME/.claude/scripts/"* ]] || [[ "$script_path" == "$HOME/.claude/claudedog/"* ]]; } && [[ ! -f "$script_path" ]]; then
                echo -e "  ${YELLOW}$display_name${NC}\tWARN: hook script not found: $cmd"
                hook_errors=$((hook_errors + 1))
            fi
        done < <(jq -r '
            .hooks // {} | to_entries[] | .value[] | .hooks[] |
            select(.type == "command") | .command
        ' "$dest" 2>/dev/null)
        warn_count=$((warn_count + hook_errors))
    fi

    if [[ $missing -eq 0 ]] && [[ ${hook_errors:-0} -eq 0 ]]; then
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
