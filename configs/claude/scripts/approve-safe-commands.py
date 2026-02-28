#!/usr/bin/env python3
"""PreToolUse hook: approve safe command patterns.

Auto-approves Bash commands that contain only safe $() patterns,
such as `git commit -m "$(cat <<'EOF'...EOF)"`.

Fail-open design: any exception results in sys.exit(0) to fall back
to the normal permission prompt.

Approve rules:
  git commit with $(cat <<'EOF'...EOF) or $(cat <<EOF...EOF)
"""

import json
import re
import sys


def is_safe_command_substitution(command: str) -> bool:
    """Check if all $() in the command are safe heredoc patterns.

    Safe pattern: $(cat <<'EOF'...EOF) or $(cat <<EOF...EOF)
    Returns True if the command contains git commit AND all $()
    substitutions are safe heredoc cat patterns.
    """
    if "git commit" not in command:
        return False

    # Find all $(...) substitutions
    # Use a simple approach: find all $( and match balanced parens
    substitutions = []
    i = 0
    while i < len(command):
        if command[i] == "$" and i + 1 < len(command) and command[i + 1] == "(":
            # Find matching closing paren, handling nesting
            depth = 1
            start = i
            i += 2
            while i < len(command) and depth > 0:
                if command[i] == "(":
                    depth += 1
                elif command[i] == ")":
                    depth -= 1
                i += 1
            substitutions.append(command[start:i])
        else:
            i += 1

    if not substitutions:
        # No $() at all — no need to approve (won't trigger permission ask)
        return False

    # Check that every $() is a safe cat heredoc pattern
    safe_pattern = re.compile(
        r"^\$\(\s*cat\s+<<\s*'?EOF'?\s*\n.*\nEOF\s*\)$", re.DOTALL
    )
    for sub in substitutions:
        if not safe_pattern.match(sub):
            return False

    return True


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

        if is_safe_command_substitution(command):
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow",
                }
            }
            print(json.dumps(output, ensure_ascii=False))
            sys.exit(0)

        # Not a safe pattern — pass through to default permission check
        sys.exit(0)

    except Exception:
        # Fail-open: fall back to normal behavior
        sys.exit(0)


if __name__ == "__main__":
    main()
