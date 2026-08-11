#!/usr/bin/env python3
# ADR: 008, 091
# Purpose: Bash 実行前に find/grep/cat 等を Glob/Grep/Read 等のネイティブツールへ誘導する
"""PreToolUse hook: redirect Bash commands to native Claude Code tools.

Checks the first command in each pipe chain segment and blocks commands
that should use native tools (Glob, Grep, Read, Edit, Write) instead.

All rules exist to suppress permission prompts in default mode. When
permission_mode is auto/bypassPermissions/dontAsk, the entire hook is
skipped because permissions are no longer requested.

Fail-open design: any exception results in sys.exit(0) to fall back
to the normal permission prompt.

Redirect rules:
  find          → Glob
  grep / rg     → Grep
  cat (no >)    → Read
  cat (with >)  → Write
  echo (with >) → Write
  sed -i        → Edit（インプレース編集は Edit に寄せてファイル追跡を維持する）
  cd <path> && … → 絶対パス / git -C（Bash 呼び出し間で cwd は持続しない）
  > /tmp/...    → .outputs/claude/ に出力（プロジェクト内に出力を集約）

ADR-091 で削除したルール: `&&` 全面禁止 / `$()` 全面禁止 / head / tail /
awk / sed（-i なし）/ mkdir / cp / for / while / python -c /
プロジェクト外 .py 実行。prompt を減らさない、あるいは助言として誤っていた。

All rules are skipped when permission_mode is auto/bypassPermissions/dontAsk.
"""

import json
import os
import re
import sys


# Reuse the same chain-splitting logic as enforce-bash-permissions.py
def split_chain(command: str) -> list:
    """Split a chained command into segments on &&, ||, ; (respects quoted strings)."""
    segments = []
    current = []
    i = 0
    in_single = False
    in_double = False

    while i < len(command):
        c = command[i]

        if c == "'" and not in_double:
            in_single = not in_single
            current.append(c)
        elif c == '"' and not in_single:
            in_double = not in_double
            current.append(c)
        elif not in_single and not in_double:
            # Check for && or ||
            if command[i:i+2] in ("&&", "||"):
                seg = "".join(current).strip()
                if seg:
                    segments.append(seg)
                current = []
                i += 2
                continue
            # Check for ;
            elif c == ";":
                seg = "".join(current).strip()
                if seg:
                    segments.append(seg)
                current = []
            else:
                current.append(c)
        else:
            current.append(c)

        i += 1

    seg = "".join(current).strip()
    if seg:
        segments.append(seg)

    return segments


def get_first_pipe_command(segment: str) -> str:
    """Get the first command in a pipe chain.

    For "git log | grep fix", returns "git log".
    For "grep -r pattern src/", returns "grep -r pattern src/".
    """
    parts = segment.split("|")
    return parts[0].strip()


def extract_base_command(command_str: str) -> str:
    """Extract the base command name, skipping env var assignments.

    For "VAR=val cmd arg", returns "cmd".
    For "cmd arg", returns "cmd".
    """
    words = command_str.split()
    for word in words:
        if "=" in word and not word.startswith("-"):
            continue
        return word
    return ""


def is_sed_in_place(command_str: str) -> bool:
    """Check if sed is invoked with an in-place edit flag.

    Returns True for:  sed -i '' 's/a/b/' f, sed -i.bak 's/a/b/' f, sed -ri 's//' f
    Returns False for: sed -n '1,50p' f, sed 's/a/b/' f
    """
    words = command_str.split()
    for w in words[1:]:
        if not w.startswith("-") or w.startswith("--"):
            if w == "--in-place" or w.startswith("--in-place="):
                return True
            continue
        # Short flag cluster (e.g. -i, -i.bak, -ri, -n)
        if "i" in w[1:].split(".")[0]:
            return True
    return False


def writes_to_tmp(command_str: str) -> bool:
    """Check if the command writes to /tmp/ via redirect or tee.

    Matches patterns like:
        gh pr view 123 --json body -q '.body' > /tmp/pr-body.txt
        printf 'hello' > /tmp/msg.txt
        echo 'data' | tee /tmp/output.txt
    """
    return bool(re.search(r">\s*/tmp/", command_str)) or bool(
        re.search(r"\btee\s+/tmp/", command_str)
    )


def has_stdout_redirect(command_str: str) -> bool:
    """Check if the command has a stdout file redirect.

    Matches > or >> but not >&2 or other fd redirects.
    """
    return bool(re.search(r"(?<![&\d])>{1,2}(?!\s*&)", command_str))


# Redirect rules: (base_command, condition_fn, tool_name, message)
REDIRECT_RULES = [
    (
        "find",
        lambda _cmd: True,
        "Glob",
        "Bash の find ではなく Glob ツールを使用してください",
    ),
    (
        "grep",
        lambda _cmd: True,
        "Grep",
        "Bash の grep ではなく Grep ツールを使用してください",
    ),
    (
        "rg",
        lambda _cmd: True,
        "Grep",
        "Bash の rg ではなく Grep ツールを使用してください",
    ),
    (
        "cat",
        has_stdout_redirect,
        "Write",
        "Bash の cat > ではなく Write ツールを使用してください",
    ),
    (
        "cat",
        lambda cmd: not has_stdout_redirect(cmd),
        "Read",
        "Bash の cat ではなく Read ツールを使用してください",
    ),
    (
        "echo",
        has_stdout_redirect,
        "Write",
        "Bash の echo > ではなく Write ツールを使用してください",
    ),
    (
        "sed",
        is_sed_in_place,
        "Edit",
        "sed -i によるインプレース編集ではなく Edit ツールを使用してください",
    ),
]


def check_command(command_str: str):
    """Check a single pipe-first command against redirect rules.

    Returns (tool_name, message) if blocked, or None if allowed.
    """
    first_cmd = get_first_pipe_command(command_str)
    base = extract_base_command(first_cmd)

    for rule_cmd, condition_fn, tool_name, message in REDIRECT_RULES:
        if base == rule_cmd and condition_fn(first_cmd):
            return (tool_name, message)

    return None


def check_and_chain(segments: list):
    """Detect the `cd <path> && <cmd>` pattern and instruct to avoid it.

    cwd は Bash 呼び出し間で持続せず、worktree 分離運用では別 worktree を
    指したまま操作する事故につながるため、cd 起点の連結だけを deny する
    （ADR-081 / ADR-082）。cd 以外の `&&` 連結は ADR-091 で許可した。

    Returns (tool_name, message) if the pattern is detected, or None otherwise.
    """
    if len(segments) < 2:
        return None

    first_words = segments[0].split()
    if not first_words or first_words[0] != "cd":
        return None

    path = first_words[1] if len(first_words) > 1 else "<path>"
    next_words = segments[1].split()
    next_cmd = next_words[0] if next_words else ""

    if next_cmd == "git":
        git_rest = " ".join(next_words[1:]) if len(next_words) > 1 else "<cmd>"
        suggestion = f"git -C {path} {git_rest}"
        message = (
            f"Bash の `cd && git` パターンではなく `git -C` を使用してください。"
            f" 代替コマンド: `{suggestion}`"
        )
        return ("Bash(git -C)", message)

    message = (
        f"Bash の `cd && {next_cmd}` パターンは使用しないでください。"
        f" `{next_cmd}` の引数に絶対パス（{path}/...）を直接指定するか、"
        f" 専用ツール（Glob/Grep/Read/Edit/Write）を使用してください。"
    )
    return (f"Bash({next_cmd} with abspath)", message)


def _write_deny_log(session_id: str, tool_name: str, reason: str) -> None:
    """deny 決定を ~/.claude/logs/deny.log に記録する（fail-open）。"""
    try:
        from datetime import datetime, timezone
        log_dir = os.path.expanduser("~/.claude/logs")
        os.makedirs(log_dir, exist_ok=True)
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        reason_prefix = reason[:40]
        with open(os.path.join(log_dir, "deny.log"), "a") as f:
            f.write(f"{ts} session={session_id} tool={tool_name} reason={reason_prefix}\n")
    except Exception:
        pass


def _deny(session_id: str, tool_name: str, reason: str) -> None:
    """deny 決定を stdout に出力し、ログに記録する。"""
    _write_deny_log(session_id, tool_name, reason)
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }
    print(json.dumps(output, ensure_ascii=False))


def main():
    try:
        hook_input = json.load(sys.stdin)

        tool_name = hook_input.get("tool_name", "")
        session_id = hook_input.get("session_id", "unknown")
        if tool_name != "Bash":
            sys.exit(0)

        # 全 rule は permission 頻発を抑える目的のため、
        # permission がそもそも出ない mode では hook 全体を skip する
        permission_mode = hook_input.get("permission_mode", "")
        if permission_mode in ("auto", "bypassPermissions", "dontAsk"):
            sys.exit(0)

        tool_input = hook_input.get("tool_input", {})
        command = tool_input.get("command", "")
        if not command:
            sys.exit(0)

        # /tmp/ 書き込みチェック（default mode で /tmp/ がプロジェクト外として
        # permission 対象になるのを避けるため .outputs/claude/ に誘導）
        if writes_to_tmp(command):
            _deny(
                session_id,
                tool_name,
                "/tmp/ への書き込みではなく .outputs/claude/ に出力してください。"
                " 例: > .outputs/claude/pr-body.txt",
            )
            sys.exit(0)

        segments = split_chain(command)

        # cd 起点の連結コマンドを先にチェック
        chain_result = check_and_chain(segments)
        if chain_result:
            _tool, message = chain_result
            _deny(session_id, tool_name, message)
            sys.exit(0)

        for segment in segments:
            result = check_command(segment)
            if result:
                tool, message = result
                _deny(session_id, tool_name, f"{message} (代わりに {tool} ツールを使ってください)")
                sys.exit(0)

        # No redirect needed — pass through
        sys.exit(0)

    except Exception:
        # Fail-open: fall back to normal behavior
        sys.exit(0)


if __name__ == "__main__":
    main()
