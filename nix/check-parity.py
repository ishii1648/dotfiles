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
INTENTIONAL_NIX_EXCLUDES = {
    ".config/fish/fish_variables": "fish が set -U で実行時に書き換える（ADR-084 設計案 A-3）",
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


def setup_symlinks():
    """setup-manifest.yml（full profile）と configs/*/setup.sh の symlink を再現する。"""
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
    for path in sorted(glob.glob(os.path.join(ROOT, "configs/fish/functions/*.fish"))):
        name = os.path.basename(path)
        pairs[f".config/fish/functions/{name}"] = f"configs/fish/functions/{name}"
    for name in ["config.fish", "fish_plugins", "fish_variables"]:
        pairs[f".config/fish/{name}"] = f"configs/fish/{name}"
    pairs[".config/fish/completions"] = "configs/fish/completions"

    # configs/claude/setup.sh（skills の個別 symlink）
    for path in sorted(glob.glob(os.path.join(ROOT, "configs/claude/skills/*/"))):
        name = os.path.basename(path.rstrip("/"))
        pairs[f".claude/skills/{name}"] = f"configs/claude/skills/{name}"
    return pairs


def main():
    nix = nix_symlinks()
    sh = setup_symlinks()

    mismatch = {k: (sh[k], nix[k]) for k in sh if k in nix and sh[k] != nix[k]}
    only_sh = {k: v for k, v in sh.items() if k not in nix}
    only_nix = {k: v for k, v in nix.items() if k not in sh}
    missing = {k: v for k, v in nix.items() if not os.path.exists(os.path.join(ROOT, v))}
    unexpected_sh = {k: v for k, v in only_sh.items() if k not in INTENTIONAL_NIX_EXCLUDES}

    failed = bool(mismatch or only_nix or missing or unexpected_sh)

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

    if failed:
        return 1
    if not QUIET:
        print("OK: 意図的除外を除いて一致")
    return 0


if __name__ == "__main__":
    sys.exit(main())
