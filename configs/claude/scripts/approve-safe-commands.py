#!/usr/bin/env python3
"""PreToolUse hook: approve safe command patterns.

Auto-approves Bash commands that contain only safe $() patterns,
such as `git commit -m "$(cat <<'EOF'...EOF)"`.

Also auto-approves commands where the only quoted flag-like strings
are dash-only separators (e.g. echo "---"), which trigger a false
positive in the built-in "quoted characters in flag names" check.

Fail-open design: any exception results in sys.exit(0) to fall back
to the normal permission prompt.

Approve rules:
  1. git commit with $(cat <<'EOF'...EOF) or $(cat <<EOF...EOF)
  2. Commands where all quoted dash-prefixed strings are dash-only
     separators (e.g. "---", '--')
"""

import json
import re
import sys


def has_only_dash_separators_in_quotes(command: str) -> bool:
    """Check if all quoted flag-like strings are dash-only separators.

    The built-in heuristic flags commands containing quoted strings that
    start with dashes (e.g. "---") as potential flag obfuscation.
    This function returns True when every such quoted string consists
    entirely of dashes, meaning it's a harmless separator like "---".

    Examples that return True:
        echo "---"
        ls -la /path 2>&1; echo "---"; ls -la /other 2>&1
        echo '----'

    Examples that return False:
        cmd "--dangerous-flag"
        cmd '-rf'
    """
    # Match both single- and double-quoted strings
    quoted_strings = re.findall(r"""(?:"([^"]*)")|(?:'([^']*)')""", command)
    dash_prefixed = []
    for dq, sq in quoted_strings:
        value = dq if dq else sq
        if value.startswith("-"):
            dash_prefixed.append(value)

    if not dash_prefixed:
        return False

    # Safe only if ALL dash-prefixed quoted strings are purely dashes
    return all(re.fullmatch(r"-+", s) for s in dash_prefixed)


def is_safe_command_substitution(command: str) -> bool:
    """Check if all $() in the command are safe heredoc patterns.

    Safe pattern: $(cat <<'EOF'...EOF) or $(cat <<EOF...EOF)
    Returns True if the command contains git commit AND all $()
    substitutions are safe heredoc cat patterns.

    Supports both `git commit` and `git -C <path> commit` forms.
    """
    if not re.search(r"\bgit\b.*\bcommit\b", command):
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

        if is_safe_command_substitution(command) or has_only_dash_separators_in_quotes(command):
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
