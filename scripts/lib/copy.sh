#!/bin/bash
# ファイルコピー処理関数

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
