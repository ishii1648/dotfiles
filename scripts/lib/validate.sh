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
