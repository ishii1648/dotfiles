#!/usr/bin/env python3
"""PreToolUse hook: enforce Bash permissions from settings.json.

Reads deny/allow rules from ~/.claude/settings.json and enforces them
for Bash tool calls. Deny rules are evaluated first and take priority.

Fail-open design: any exception results in sys.exit(0) to fall back
to the normal permission prompt.

Pattern modes:
  Bash(cmd:*)   → word_prefix: matches "cmd" or "cmd ..."
  Bash(cmd*)    → char_prefix: matches anything starting with "cmd"
  Bash(cmd)     → exact:       matches exactly "cmd"
"""

import json
import os
import re
import sys


def parse_bash_pattern(pattern: str):
    """Parse a Bash(...) permission pattern.

    Returns (prefix, mode) or None if not a Bash pattern.
    """
    m = re.match(r"^Bash\((.+)\)$", pattern)
    if not m:
        return None
    inner = m.group(1)

    if inner.endswith(":*"):
        return (inner[:-2], "word_prefix")
    elif inner.endswith("*"):
        return (inner[:-1], "char_prefix")
    else:
        return (inner, "exact")


def matches(command: str, prefix: str, mode: str) -> bool:
    """Check if a command matches a parsed pattern."""
    if mode == "word_prefix":
        return command == prefix or command.startswith(prefix + " ")
    elif mode == "char_prefix":
        return command.startswith(prefix)
    elif mode == "exact":
        return command == prefix
    return False


def split_chain(command: str) -> list:
    """Split a chained command into segments on &&, ||, ;, |."""
    segments = re.split(r"\s*(?:&&|\|\||[;|])\s*", command)
    return [s.strip() for s in segments if s.strip()]


def reconstruct_pattern(prefix: str, mode: str) -> str:
    """Reconstruct the original Bash(...) pattern string."""
    if mode == "word_prefix":
        return f"Bash({prefix}:*)"
    elif mode == "char_prefix":
        return f"Bash({prefix}*)"
    else:
        return f"Bash({prefix})"


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

        settings_path = os.path.expanduser("~/.claude/settings.json")
        with open(settings_path, "r") as f:
            settings = json.load(f)

        permissions = settings.get("permissions", {})

        deny_patterns = []
        for rule in permissions.get("deny", []):
            parsed = parse_bash_pattern(rule)
            if parsed:
                deny_patterns.append(parsed)

        allow_patterns = []
        for rule in permissions.get("allow", []):
            parsed = parse_bash_pattern(rule)
            if parsed:
                allow_patterns.append(parsed)

        # 1. Check deny rules — split chain commands and check each segment
        segments = split_chain(command)
        for segment in segments:
            for prefix, mode in deny_patterns:
                if matches(segment, prefix, mode):
                    result = {
                        "decision": "block",
                        "reason": f"Denied by permission rule: {reconstruct_pattern(prefix, mode)}",
                    }
                    print(json.dumps(result))
                    sys.exit(0)

        # 2. Check allow rules — full command only
        for prefix, mode in allow_patterns:
            if matches(command, prefix, mode):
                result = {"decision": "allow"}
                print(json.dumps(result))
                sys.exit(0)

        # 3. No match — fall through to normal permission prompt
        sys.exit(0)

    except Exception:
        # Fail-open: fall back to normal behavior
        sys.exit(0)


if __name__ == "__main__":
    main()
