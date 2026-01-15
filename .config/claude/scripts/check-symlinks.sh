#!/bin/bash
# ~/.claude/ 配下のシンボリックリンクが適切に設定されているかチェック
#
# .config/claude/ 配下の全エントリに対して、対応する ~/.claude/ の
# シンボリックリンクが正しく設定されているか検証する。
#
# 終了コード:
#   0 - 全てOK
#   1 - 問題あり

set -euo pipefail

# dotfiles リポジトリのパスを取得（このスクリプトの位置から算出）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SOURCE_DIR="$DOTFILES_DIR/.config/claude"
TARGET_DIR="$HOME/.claude"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "Checking Claude Code symlinks..."
echo "Source: $SOURCE_DIR"
echo ""

ok_count=0
fail_count=0
total_count=0

# .config/claude/ 配下のエントリをスキャン
for entry in "$SOURCE_DIR"/*; do
    name=$(basename "$entry")
    target_path="$TARGET_DIR/$name"
    expected_target="$entry"

    total_count=$((total_count + 1))

    # シンボリックリンクが存在するかチェック
    if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
        echo -e "${RED}$name${NC}\t✗ MISSING (symlink not found)"
        echo "  Fix: ln -s $expected_target $target_path"
        echo ""
        fail_count=$((fail_count + 1))
        continue
    fi

    # シンボリックリンクであるかチェック
    if [[ ! -L "$target_path" ]]; then
        echo -e "${YELLOW}$name${NC}\t✗ NOT A SYMLINK (regular file/directory exists)"
        echo "  Current: $(file "$target_path")"
        echo "  Fix: rm -rf $target_path && ln -s $expected_target $target_path"
        echo ""
        fail_count=$((fail_count + 1))
        continue
    fi

    # リンク先が正しいかチェック
    actual_target=$(readlink "$target_path")
    if [[ "$actual_target" != "$expected_target" && "$actual_target" != "$expected_target/" ]]; then
        echo -e "${YELLOW}$name${NC}\t✗ WRONG TARGET"
        echo "  Current:  $actual_target"
        echo "  Expected: $expected_target"
        echo "  Fix: rm $target_path && ln -s $expected_target $target_path"
        echo ""
        fail_count=$((fail_count + 1))
        continue
    fi

    # OK
    echo -e "${GREEN}$name${NC}\t✓ OK"
    ok_count=$((ok_count + 1))
done

echo ""
echo "Result: $ok_count/$total_count OK"

if [[ $fail_count -gt 0 ]]; then
    exit 1
fi
exit 0
