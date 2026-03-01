#!/bin/bash
# シンボリックリンク管理関数

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
