#!/usr/bin/env python3
# ADR: 092
# Purpose: permissions baseline の Read() deny が塞げない Bash 経由の秘密鍵参照を PreToolUse でブロックする
"""PreToolUse hook: block Bash commands that reference an SSH private key.

`permissions.deny` の `Read(~/.ssh/id_*)` は Read / Edit / Write tool にしか
効かない。`cat ~/.ssh/id_ed25519` のように Bash 経由で読めば素通りするため、
deny の意図が守られない（Codex 側は seatbelt で kernel レベルに遮断しており
同じ穴は無い）。`Bash(cat ...)` を列挙する方式は head / xxd / base64 / cp /
リダイレクト等で無限に回避できるので、コマンド文字列そのものに秘密鍵の
パスが現れた時点で止める。

対象は「参照した時点で内容が transcript に載りうるもの」に絞る。ここで
ブロックしたコマンドを実行する必要が本当にあるときは、人間が手元の
シェルで直接実行する（`!` プレフィックス）。

Fail-open design: any exception results in sys.exit(0) to fall back to
normal behavior.
"""

import json
import re
import sys

# 検出パターン。(regex, 人間向けのラベル) の組。
#
# ssh-keygen が生成する秘密鍵の既定名 (id_rsa / id_dsa / id_ecdsa / id_ed25519 と
# その _sk 版) を、パス付き・ファイル名単体のどちらでも拾う。末尾の否定先読みで
# `id_ed25519.pub` のような公開鍵と `id_ed25519_backup` のような別名は除外する
# (公開鍵は user.signingkey として git が読むので、塞ぐと commit 署名が壊れる)。
SECRET_PATTERNS = [
    (
        re.compile(r"""(?:^|[\s'"=/(])id_(?:rsa|dsa|ecdsa|ed25519)(?:_sk)?(?![\w.-])"""),
        "SSH 秘密鍵",
    ),
    (
        re.compile(r"""\.aws/credentials(?![\w.-])"""),
        "AWS credentials",
    ),
]


def find_secret_reference(command: str):
    """Return (label, matched_text) for the first secret path found, else None."""
    if not command:
        return None
    for pattern, label in SECRET_PATTERNS:
        m = pattern.search(command)
        if m:
            return label, m.group(0).strip("\"' =(")
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    try:
        if payload.get("tool_name") != "Bash":
            sys.exit(0)

        command = payload.get("tool_input", {}).get("command", "")
        hit = find_secret_reference(command)
        if not hit:
            sys.exit(0)

        label, matched = hit
        reason = (
            f"{label}（`{matched}`）を参照するコマンドは実行できません。"
            "permissions の Read() deny と同じ意図を Bash 側でも守るためのガードです"
            "（cat / head / base64 / cp などツールを変えても同じく止まります）。"
            "本当に必要な場合は、エージェントに実行させず `!` プレフィックスで"
            "ユーザー自身が手元のシェルで実行してください。"
        )
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }
        print(json.dumps(output, ensure_ascii=False))
        sys.exit(0)

    except Exception:
        # Fail-open: fall back to normal behavior
        sys.exit(0)


if __name__ == "__main__":
    main()
