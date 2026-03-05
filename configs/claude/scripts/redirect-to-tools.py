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
  python3 <外部パス>.py → Read/Grep/Edit/jq（プロジェクト外スクリプトの代わりに専用ツール）
  python <外部パス>.py  → Read/Grep/Edit/jq
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


def _is_external_script(command_str: str) -> bool:
    """Check if python is executing a .py file outside the current working directory.

    Returns True for: python3 /tmp/foo.py, python ~/debug.py
    Returns False for: python3 -m pytest, python3 claudedog/server.py, python3 -c '...'
    """
    words = command_str.split()
    # Skip the python command itself
    for arg in words[1:]:
        # Skip flags and their values
        if arg.startswith("-"):
            continue
        # Found a positional argument — check if it's a .py file
        if arg.endswith(".py"):
            abs_path = os.path.abspath(os.path.expanduser(arg))
            cwd = os.getcwd()
            if not abs_path.startswith(cwd + os.sep) and abs_path != cwd:
                return True
        break
    return False


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
    (
        "python3",
        _is_external_script,
        "Read/Grep/Edit",
        "プロジェクト外の Python スクリプト実行ではなく専用ツール（Read/Grep/Edit/jq）を使用してください",
    ),
    (
        "python",
        _is_external_script,
        "Read/Grep/Edit",
        "プロジェクト外の Python スクリプト実行ではなく専用ツール（Read/Grep/Edit/jq）を使用してください",
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
    """Detect any '&&' compound command pattern and instruct to split.

    Special cases:
    - cd <path> && git <cmd>  → suggest 'git -C <path> <cmd>'
    - cd <path> && <any cmd>  → instruct to use absolute path
    - <any> && <any>          → instruct to split into separate Bash calls

    Returns (tool_name, message) if the pattern is detected, or None otherwise.
    """
    if len(segments) < 2:
        return None

    # Check for cd as first segment (special handling)
    first_words = segments[0].split()
    if first_words and first_words[0] == "cd":
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
        else:
            message = (
                f"Bash の `cd && {next_cmd}` パターンは使用しないでください。"
                f" `{next_cmd}` の引数に絶対パス（{path}/...）を直接指定するか、"
                f" 専用ツール（Glob/Grep/Read/Edit/Write）を使用してください。"
            )
            return (f"Bash({next_cmd} with abspath)", message)

    # General && pattern: instruct to split into separate Bash calls
    cmds = " && ".join(seg.strip() for seg in segments)
    message = (
        f"`&&` で連結された複合コマンドは使用しないでください。"
        f" 各コマンドを個別の Bash ツール呼び出しに分割してください: {cmds}"
    )
    return ("Bash(compound)", message)


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


def main():
    try:
        hook_input = json.load(sys.stdin)

        tool_name = hook_input.get("tool_name", "")
        session_id = hook_input.get("session_id", "unknown")
        if tool_name != "Bash":
            sys.exit(0)

        tool_input = hook_input.get("tool_input", {})
        command = tool_input.get("command", "")
        if not command:
            sys.exit(0)

        segments = split_chain(command)

        # Check for && compound command pattern first
        chain_result = check_and_chain(segments)
        if chain_result:
            tool, message = chain_result
            _write_deny_log(session_id, tool_name, message)
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": message,
                }
            }
            print(json.dumps(output, ensure_ascii=False))
            sys.exit(0)

        for segment in segments:
            result = check_command(segment)
            if result:
                tool, message = result
                reason = f"{message} (代わりに {tool} ツールを使ってください)"
                _write_deny_log(session_id, tool_name, reason)
                output = {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "deny",
                        "permissionDecisionReason": reason,
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
