#!/bin/bash
# パス解決ユーティリティ（ADR-084）
#
# home-manager は out-of-store symlink を二段構成で張る:
#   ~/.claude/CLAUDE.md -> /nix/store/<hash>-hm_CLAUDE.md -> <dotfiles>/configs/claude/CLAUDE.md
# readlink の一段目だけを文字列比較すると、これを「WRONG TARGET」と誤判定して
# 張り替えてしまい、Nix 側の symlink を破壊する（ADR-084 Phase A の共存が壊れる）。
# 最終解決先で比較することで、setup.sh と home-manager のどちらが張ったリンクでも
# 同一と判定できるようにする。

# symlink の最終解決先を返す（解決できなければ空文字）
resolve_link() {
    local p="$1"
    if command -v realpath >/dev/null 2>&1; then
        realpath "$p" 2>/dev/null
    else
        # PyYAML と同じく python3 は setup.sh の前提（scripts/lib/deps-macos.sh）
        python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$p" 2>/dev/null
    fi
}

# link が expected を指しているか判定する。
# 一段目の文字列一致（setup.sh が張ったリンク）と、最終解決先の一致
# （home-manager が張った二段リンク）の両方を許容する。
symlink_points_to() {
    local link="$1"
    local expected="$2"

    local actual
    actual="$(readlink "$link" 2>/dev/null)"
    [[ "${actual%/}" == "${expected%/}" ]] && return 0

    local resolved_link resolved_expected
    resolved_link="$(resolve_link "$link")"
    resolved_expected="$(resolve_link "$expected")"
    [[ -n "$resolved_link" && "$resolved_link" == "$resolved_expected" ]]
}

# link が home-manager 管理下（/nix/store 経由）かどうか
is_nix_managed_link() {
    [[ "$(readlink "$1" 2>/dev/null)" == /nix/store/* ]]
}
