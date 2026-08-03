#!/usr/bin/env python3
# ADR: ADR-084, ADR-085
# Purpose: nix/symlinks.nix と setup.sh 側の symlink 定義の整合を検証する。
#
# ADR-085 以降、full profile の symlink は home-manager が張り、setup.sh は
# setup-manifest.yml の `nix_managed: true` を見てスキップする。両者の定義がずれると
# full profile でリンクが張られない（Nix 側に無いのに setup.sh もスキップする）ため、
# 静的に検査する。
#
# 使い方: python3 nix/check-parity.py [--quiet]
# 終了コード: 0 = 整合 / 1 = 差分あり
#
# NOTE: .gitignore 済みの端末固有 fish 関数（configs/fish/functions/__* など）は
#       git worktree 内には存在しないため、実機の差分は main worktree で確認する。

import glob
import os
import re
import subprocess
import sys

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QUIET = "--quiet" in sys.argv

# configs/fish/setup.sh が full profile で home-manager に委ねる conf.d ファイル
FISH_CONFD = [
    "aliases.fish", "completions.fish", "env.fish", "fzf-fish-config.fish",
    "fzf.fish", "herdr-ssh-tab.fish", "path.fish", "ssh-agent.fish",
]
# 同じく fish のルートファイル
# （fish_variables は両レイヤとも管理しない。ADR-084 知見 6）
FISH_ROOT_FILES = ["config.fish", "fish_plugins"]


def tracked_fish_functions():
    """git が追跡している fish 関数名の集合。判定不能なら None。"""
    d = os.path.join(ROOT, "configs/fish/functions")
    try:
        out = subprocess.run(
            ["git", "-C", d, "ls-files"],
            capture_output=True, text=True, check=True,
        ).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return {line.strip() for line in out.splitlines() if line.strip().endswith(".fish")}


def nix_symlinks():
    """nix/symlinks.nix が定義する (link, target)。"""
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

    tracked = tracked_fish_functions()
    for path in sorted(glob.glob(os.path.join(ROOT, "configs/fish/functions/*.fish"))):
        name = os.path.basename(path)
        # flake source は git tracked のみを含むため、端末固有関数は nix 側に現れない
        if tracked is not None and name not in tracked:
            continue
        pairs[f".config/fish/functions/{name}"] = f"configs/fish/functions/{name}"
    return pairs


def setup_symlinks():
    """setup.sh 側の定義を full profile 視点で 3 つに分類する。

    戻り値 (nix_expected, sh_only, local_only):
      nix_expected: full では home-manager が張るべきもの（manifest の nix_managed: true
                    と、configs/{fish,claude}/setup.sh が full でスキップする分）
      sh_only:      full でも setup.sh が張り続けるもの
      local_only:   端末固有 fish 関数（.gitignore 済み。両レイヤの比較対象外）
    """
    with open(os.path.join(ROOT, "scripts", "setup-manifest.yml")) as f:
        manifest = yaml.safe_load(f)

    nix_expected, sh_only = {}, {}
    for comp in manifest["profiles"]["full"]:
        for s in (manifest["components"].get(comp) or {}).get("symlinks", []) or []:
            link = s["link"].replace("~/", "")
            (nix_expected if s.get("nix_managed") else sh_only)[link] = s["target"]

    # configs/fish/setup.sh: full では conf.d / completions / ルートファイル /
    # tracked な functions を home-manager に委ねる（ADR-085）
    for name in FISH_CONFD:
        nix_expected[f".config/fish/conf.d/{name}"] = f"configs/fish/conf.d/{name}"
    for name in FISH_ROOT_FILES:
        nix_expected[f".config/fish/{name}"] = f"configs/fish/{name}"
    nix_expected[".config/fish/completions"] = "configs/fish/completions"

    tracked = tracked_fish_functions()
    local_only = []
    for path in sorted(glob.glob(os.path.join(ROOT, "configs/fish/functions/*.fish"))):
        name = os.path.basename(path)
        if tracked is not None and name not in tracked:
            local_only.append(name)
            continue
        nix_expected[f".config/fish/functions/{name}"] = f"configs/fish/functions/{name}"

    # configs/claude/setup.sh: full では dotfiles 由来 skill を home-manager に委ねる
    for path in sorted(glob.glob(os.path.join(ROOT, "configs/claude/skills/*/"))):
        name = os.path.basename(path.rstrip("/"))
        nix_expected[f".claude/skills/{name}"] = f"configs/claude/skills/{name}"

    return nix_expected, sh_only, local_only


def path_collisions():
    """Nix profile と aqua が同名コマンドを提供していないか（ADR-084 知見 8）。

    Determinate Nix は ~/.nix-profile/bin を PATH の最先頭に置くため、同名のコマンドが
    あると aqua のバージョン固定が黙って無効になる。実機でしか検査できないので、
    両ディレクトリが揃っていない環境（CI 等）では None を返してスキップする。
    """
    nix_bin = os.path.expanduser("~/.nix-profile/bin")
    aqua_bin = os.path.expanduser("~/.local/share/aquaproj-aqua/bin")
    if not (os.path.isdir(nix_bin) and os.path.isdir(aqua_bin)):
        return None
    return sorted(set(os.listdir(nix_bin)) & set(os.listdir(aqua_bin)))


def main():
    nix = nix_symlinks()
    nix_expected, sh_only, local_only = setup_symlinks()
    collisions = path_collisions()

    mismatch = {k: (v, nix[k]) for k, v in nix_expected.items()
                if k in nix and v != nix[k]}
    missing_in_nix = {k: v for k, v in nix_expected.items() if k not in nix}
    extra_in_nix = {k: v for k, v in nix.items() if k not in nix_expected}
    double_defined = {k: v for k, v in sh_only.items() if k in nix}
    missing_target = {k: v for k, v in nix.items()
                      if not os.path.exists(os.path.join(ROOT, v))}

    failed = bool(mismatch or missing_in_nix or extra_in_nix
                  or double_defined or missing_target or collisions)

    if not QUIET or failed:
        print(f"nix: {len(nix)} links / nix に委ねる想定: {len(nix_expected)}"
              f" / setup.sh が張り続ける: {len(sh_only)}")
        for k, (a, b) in sorted(mismatch.items()):
            print(f"  MISMATCH: {k}\n    setup.sh 側: {a}\n    nix 側:      {b}")
        for k, v in sorted(missing_in_nix.items()):
            print(f"  MISSING IN NIX: {k} -> {v}"
                  "（setup.sh は full でスキップするので誰も張らない）")
        for k, v in sorted(extra_in_nix.items()):
            print(f"  EXTRA IN NIX: {k} -> {v}（setup.sh 側に対応する定義がない）")
        for k, v in sorted(double_defined.items()):
            print(f"  DOUBLE DEFINED: {k} -> {v}"
                  "（nix_managed: true を付けるか nix 側から外す）")
        for k, v in sorted(missing_target.items()):
            print(f"  TARGET MISSING: {v} (link: {k})")
        for name in collisions or []:
            print(f"  PATH COLLISION: {name} が Nix profile と aqua の両方にある"
                  "（Nix が PATH 上で優先され aqua のバージョン固定が無効化される）")
        for name in sorted(local_only):
            print(f"  local only (setup.sh のみが張る): configs/fish/functions/{name}")
        if collisions is None and not QUIET:
            print("  （PATH 衝突検査: skip — Nix profile / aqua のどちらかが未導入）")

    if failed:
        return 1
    if not QUIET:
        print("OK: nix と setup.sh の symlink 定義は整合している")
    return 0


if __name__ == "__main__":
    sys.exit(main())
