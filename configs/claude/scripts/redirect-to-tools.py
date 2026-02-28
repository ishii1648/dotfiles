#!/usr/bin/env python3
"""PreToolUse hook: redirect Bash commands to native Claude Code tools.

Checks the first command in each pipe chain segment and blocks commands
that should use native tools (Glob, Grep, Read, Edit, Write) instead.

Fail-open design: any exception results in sys.exit(0) to fall back
to the normal permission prompt.

Redirect rules:
  find        → Glob
  grep / rg   → Grep
  cat (no >)  → Read
  cat (with >) → Write
  head / tail → Read
  sed / awk   → Edit
  echo (with >) → Write
  for / while → Glob + 個別ツール（ループの代わりに個別ツール呼び出し）
  python3 -c  → Read/Grep/Edit/jq（インラインスクリプトの代わりに専用ツール）
  python -c   → Read/Grep/Edit/jq
"""

import json
import re
import sys


# Reuse the same chain-splitting logic as enforce-bash-permissions.py
def split_chain(command: str) -> list:
    """Split a chained command into segments on &&, ||, ;."""
    segments = re.split(r"\s*(?:&&|\|\||;)\s*", command)
    return [s.strip() for s in segments if s.strip()]


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
        "head",
        lambda _cmd: True,
        "Read",
        "Bash の head ではなく Read ツールを使用してください",
    ),
    (
        "tail",
        lambda _cmd: True,
        "Read",
        "Bash の tail ではなく Read ツールを使用してください",
    ),
    (
        "sed",
        lambda _cmd: True,
        "Edit",
        "Bash の sed ではなく Edit ツールを使用してください",
    ),
    (
        "awk",
        lambda _cmd: True,
        "Edit",
        "Bash の awk ではなく Edit ツールを使用してください",
    ),
    (
        "echo",
        has_stdout_redirect,
        "Write",
        "Bash の echo > ではなく Write ツールを使用してください",
    ),
    (
        "for",
        lambda _cmd: True,
        "Glob/個別ツール",
        "Bash の for ループではなく Glob + 個別ツール（Read/Edit/Bash）を使用してください",
    ),
    (
        "while",
        lambda _cmd: True,
        "Glob/個別ツール",
        "Bash の while ループではなく Glob + 個別ツール（Read/Edit/Bash）を使用してください",
    ),
    (
        "python3",
        lambda cmd: any(a == "-c" for a in cmd.split()[1:]),
        "Read/Grep/Edit",
        "Bash の python3 -c インラインスクリプトではなく専用ツール（Read/Grep/Edit/jq）を使用してください",
    ),
    (
        "python",
        lambda cmd: any(a == "-c" for a in cmd.split()[1:]),
        "Read/Grep/Edit",
        "Bash の python -c インラインスクリプトではなく専用ツール（Read/Grep/Edit/jq）を使用してください",
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


def main():
    try:
        hook_input = json.load(sys.stdin)

        tool_name = hook_input.get("tool_name", "")
        if tool_name != "Bash":
            sys.exit(0)

        tool_input = hook_input.get("tool_input", {})
        command = tool_input.get("command", "")
        if not command:
            sys.exit(0)

        segments = split_chain(command)
        for segment in segments:
            result = check_command(segment)
            if result:
                tool, message = result
                output = {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "deny",
                        "permissionDecisionReason": f"{message} (代わりに {tool} ツールを使ってください)",
                    }
                }
                print(json.dumps(output, ensure_ascii=False))
                sys.exit(0)

        # No redirect needed — pass through
        sys.exit(0)

    except Exception:
        # Fail-open: fall back to normal behavior
        sys.exit(0)


if __name__ == "__main__":
    main()
