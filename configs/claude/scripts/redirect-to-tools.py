#!/usr/bin/env python3
# ADR: 008
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
  find        → Glob
  grep / rg   → Grep
  cat (no >)  → Read
  cat (with >) → Write
  head / tail → Read
  sed / awk   → Edit
  echo (with >) → Write
  for / while → Glob + 個別ツール（ループの代わりに個別ツール呼び出し）
  python3 -c '...'     → Read/Grep/Edit/jq（インラインスクリプトの代わりに専用ツール）
  python -c '...'      → Read/Grep/Edit/jq
  python3 <外部パス>.py → Read/Grep/Edit/jq（プロジェクト外スクリプトの代わりに専用ツール）
  python <外部パス>.py  → Read/Grep/Edit/jq
  mkdir       → Write（ディレクトリ自動作成）
  cp          → Read + Write
  > /tmp/...  → .outputs/claude/ に出力（プロジェクト内に出力を集約）

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


def _is_inline_script(command_str: str) -> bool:
    """Check if python is invoked with -c flag (inline script).

    Returns True for: python3 -c 'print("hello")', python -c "import json; ..."
    Returns False for: python3 -m pytest, python3 foo.py
    """
    words = command_str.split()
    return "-c" in words[1:]


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


def has_command_substitution(command: str) -> bool:
    """コマンド置換 $() またはバッククォートを検出する。

    クォート内の $() も検出対象とする（シェルは "" 内の $() を展開するため）。
    シングルクォート内は展開されないためスキップする。
    $((...)) 算術展開は除外（安全なため）。
    git commit の heredoc パターンは approve-safe-commands.py で許可済みのため除外。
    """
    # git commit の heredoc パターンは除外
    if re.search(r"\bgit\b.*\bcommit\b", command) and re.search(r"\$\(\s*cat\s+<<", command):
        return False

    in_single = False
    i = 0
    while i < len(command):
        c = command[i]

        if c == "'" and not in_single:
            in_single = True
            i += 1
            continue
        elif c == "'" and in_single:
            in_single = False
            i += 1
            continue

        if in_single:
            i += 1
            continue

        # バッククォートによるコマンド置換を検出
        if c == "`":
            return True

        # $( を検出（$((...)) 算術展開は除外）
        if c == "$" and i + 1 < len(command) and command[i + 1] == "(":
            if i + 2 < len(command) and command[i + 2] == "(":
                # $((...)) 算術展開 — スキップ
                i += 3
                continue
            return True

        i += 1

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
        _is_inline_script,
        "Read/Grep/Edit/jq",
        "python -c のインラインスクリプトではなく専用ツール（Read/Grep/Edit/jq）を使用してください",
    ),
    (
        "python",
        _is_inline_script,
        "Read/Grep/Edit/jq",
        "python -c のインラインスクリプトではなく専用ツール（Read/Grep/Edit/jq）を使用してください",
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
    (
        "mkdir",
        lambda _cmd: True,
        "Write",
        "Bash の mkdir ではなく Write ツールを使用してください（Write はディレクトリを自動作成します）",
    ),
    (
        "cp",
        lambda _cmd: True,
        "Read/Write",
        "Bash の cp ではなく Read + Write ツールを使用してください",
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
            reason = (
                "/tmp/ への書き込みではなく .outputs/claude/ に出力してください。"
                " 例: > .outputs/claude/pr-body.txt"
            )
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

        # $() コマンド置換チェック（split_chain の前に実行）
        if has_command_substitution(command):
            reason = (
                "$() コマンド置換を含む Bash コマンドは使用しないでください。"
                " $() の結果を変数に格納する Bash 呼び出しと、"
                "その変数を使う Bash 呼び出しに分割してください。"
            )
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
