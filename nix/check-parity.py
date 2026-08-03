#!/usr/bin/env python3
# ADR: ADR-084
# Purpose: nix/symlinks.nix と既存 setup 定義（setup-manifest.yml / configs/*/setup.sh）の
#          symlink が同一パス・同一ターゲットであることを検証する。
#
# ADR-084 Phase A は「Nix と setup.sh の共存」が前提であり、両者が同じ symlink を主張して
# いることが正しさの条件になる。Phase B で manifest 側を削除する際も、削除前後でこの
# スクリプトを実行して差分が意図通りであることを確認する。
#
# 使い方: python3 nix/check-parity.py [--quiet]
# 終了コード: 0 = 一致（意図的除外を除く） / 1 = 差分あり
#
# NOTE: .gitignore 済みの端末固有ファイル（configs/fish/functions/__* など）は
#       git worktree 内には存在しないため、実機の差分を見るには main worktree で実行する。

import glob
import os
import re
import sys

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUIET = "--quiet" in sys.argv

# nix 側が意図的に管理しない link → 理由
# fish_variables はここではなく setup.sh 側からも外した（ADR-084 知見 6）。fish が
# set -U のたびに rename で書き換えるため、どちらのレイヤでも symlink を維持できない。
INTENTIONAL_NIX_EXCLUDES = {}

# full profile の manifest から外して home-manager に移管済みの link → 理由
# remote / linux profile は Nix の対象外なので manifest 側に定義が残っている点に注意。
MIGRATED_TO_NIX = {
    ".vimrc": "ADR-084 Phase A の先行検証で full profile から移管",
}

# flake source は git tracked のみを含むため、nix 側に現れない端末固有 fish 関数
LOCAL_FISH_FUNCTIONS = ("claude.fish", "fable.fish")


def nix_symlinks():
    """nix/symlinks.nix から (link, target) を抽出する。"""
    src = open(os.path.join(ROOT, "nix", "symlinks.nix")).read()
    pairs = {
        m.group(1): m.group(2)
        for m in re.finditer(r'"([^"]+)"\.source\s*=\s*link\s*"([^"]+)"', src)
    }

    confd = re.search(r"fishConfdNames\s*=\s*\[(.*?)\]", src, re.S)
    if confd is None:
        raise SystemExit("nix/symlinks.nix: fishConfdNames を抽出できない")
    for name in re.findall(r'"([^"]+)"', confd.group(1)):
        pairs[f".config/fish/conf.d/{name}"] = f"configs/fish/conf.d/{name}"

    for path in sorted(glob.glob(os.path.join(ROOT, "configs/fish/functions/*.fish"))):
        name = os.path.basename(path)
        if name.startswith("__") or name in LOCAL_FISH_FUNCTIONS:
            continue
        pairs[f".config/fish/functions/{name}"] = f"configs/fish/functions/{name}"
    return pairs


def is_local_fish_function(name):
    """.gitignore 済みの端末固有 fish 関数か（ADR-012 / ADR-020）。

    setup.sh は実ディレクトリを glob するのでこれらも symlink するが、flake source は
    git tracked のみを含むため Nix 側には現れない。dotfiles が管理する共通設定ではない
    ので、parity の比較対象からは両側とも外す。
    """
    return name.startswith("__") or name in LOCAL_FISH_FUNCTIONS


def setup_symlinks():
    """setup-manifest.yml（full profile）と configs/*/setup.sh の symlink を再現する。

    戻り値は (pairs, local_only) で、local_only は比較対象から外した端末固有 fish 関数。
    """
    with open(os.path.join(ROOT, "scripts", "setup-manifest.yml")) as f:
        manifest = yaml.safe_load(f)

    pairs = {}
    for comp in manifest["profiles"]["full"]:
        for s in (manifest["components"].get(comp) or {}).get("symlinks", []) or []:
            pairs[s["link"].replace("~/", "")] = s["target"]

    # configs/fish/setup.sh
    for name in [
        "aliases.fish", "completions.fish", "env.fish", "fzf-fish-config.fish",
        "fzf.fish", "herdr-ssh-tab.fish", "path.fish", "ssh-agent.fish",
    ]:
        pairs[f".config/fish/conf.d/{name}"] = f"configs/fish/conf.d/{name}"
    local_only = []
    for path in sorted(glob.glob(os.path.join(ROOT, "configs/fish/functions/*.fish"))):
        name = os.path.basename(path)
        if is_local_fish_function(name):
            local_only.append(name)
            continue
        pairs[f".config/fish/functions/{name}"] = f"configs/fish/functions/{name}"
    for name in ["config.fish", "fish_plugins"]:
        pairs[f".config/fish/{name}"] = f"configs/fish/{name}"
    pairs[".config/fish/completions"] = "configs/fish/completions"

    # configs/claude/setup.sh（skills の個別 symlink）
    for path in sorted(glob.glob(os.path.join(ROOT, "configs/claude/skills/*/"))):
        name = os.path.basename(path.rstrip("/"))
        pairs[f".claude/skills/{name}"] = f"configs/claude/skills/{name}"
    return pairs, local_only


def path_collisions():
    """Nix profile と aqua が同名コマンドを提供していないか検査する（ADR-084 知見 8）。

    Determinate Nix は ~/.nix-profile/bin を PATH の最先頭に置くため、同名のコマンドが
    あると aqua のバージョン固定が黙って無効になる。実機でしか検査できないので、
    両ディレクトリが揃っていない環境（CI 等）では空リストを返してスキップする。
    """
    nix_bin = os.path.expanduser("~/.nix-profile/bin")
    aqua_bin = os.path.expanduser("~/.local/share/aquaproj-aqua/bin")
    if not (os.path.isdir(nix_bin) and os.path.isdir(aqua_bin)):
        return None
    return sorted(set(os.listdir(nix_bin)) & set(os.listdir(aqua_bin)))


def main():
    nix = nix_symlinks()
    sh, local_only = setup_symlinks()
    collisions = path_collisions()

    mismatch = {k: (sh[k], nix[k]) for k in sh if k in nix and sh[k] != nix[k]}
    only_sh = {k: v for k, v in sh.items() if k not in nix}
    only_nix = {k: v for k, v in nix.items() if k not in sh and k not in MIGRATED_TO_NIX}
    missing = {k: v for k, v in nix.items() if not os.path.exists(os.path.join(ROOT, v))}
    unexpected_sh = {k: v for k, v in only_sh.items() if k not in INTENTIONAL_NIX_EXCLUDES}

    failed = bool(mismatch or only_nix or missing or unexpected_sh or collisions)

    if not QUIET or failed:
        print(f"nix: {len(nix)} links / setup.sh(full): {len(sh)} links")
        for k, (a, b) in sorted(mismatch.items()):
            print(f"  MISMATCH: {k}\n    setup.sh: {a}\n    nix:      {b}")
        for k, v in sorted(unexpected_sh.items()):
            print(f"  NOT MIGRATED: {k} -> {v}")
        for k, v in sorted(only_nix.items()):
            print(f"  NIX ONLY: {k} -> {v}")
        for k, v in sorted(missing.items()):
            print(f"  TARGET MISSING: {v} (link: {k})")
        for k in sorted(set(only_sh) & set(INTENTIONAL_NIX_EXCLUDES)):
            print(f"  excluded by design: {k}  # {INTENTIONAL_NIX_EXCLUDES[k]}")
        for k in sorted(set(nix) & set(MIGRATED_TO_NIX)):
            print(f"  migrated to nix: {k}  # {MIGRATED_TO_NIX[k]}")
        for name in sorted(local_only):
            print(f"  local only (setup.sh のみが張る): configs/fish/functions/{name}")
        for name in collisions or []:
            print(f"  PATH COLLISION: {name} が Nix profile と aqua の両方にある"
                  f"（Nix が PATH 上で優先され aqua のバージョン固定が無効化される）")
        if collisions is None and not QUIET:
            print("  （PATH 衝突検査: skip — Nix profile / aqua のどちらかが未導入）")

    if failed:
        return 1
    if not QUIET:
        print("OK: 意図的除外を除いて一致")
    return 0


if __name__ == "__main__":
    sys.exit(main())
