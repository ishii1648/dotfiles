#!/usr/bin/env python3
"""PreToolUse hook: approve safe file operations on .claude/ subdirectories.

Auto-approves Read operations on .claude/{subdir}/ paths.
Passes through for .claude/ direct files and non-.claude/ paths.
Fail-open design: any exception results in sys.exit(0) to fall back
to the normal permission prompt.
"""

import json
import re
import sys


def is_claude_subdir_path(file_path: str) -> bool:
    """Check if the path is under a .claude/ subdirectory (not .claude/ directly).

    Allow:
      ~/.claude/skills/textlint/SKILL.md
      /path/.claude/agents/foo.md
      .claude/commands/bar.md

    Pass-through (not allow):
      ~/.claude/settings.json
      ~/.claude/CLAUDE.md
    """
    return bool(re.search(r"\.claude/[^/]+/", file_path))


def main():
    try:
        hook_input = json.load(sys.stdin)

        tool_name = hook_input.get("tool_name", "")
        if tool_name != "Read":
            sys.exit(0)

        file_path = hook_input.get("tool_input", {}).get("file_path", "")
        if not file_path:
            sys.exit(0)

        if is_claude_subdir_path(file_path):
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow",
                }
            }
            print(json.dumps(output, ensure_ascii=False))

        sys.exit(0)

    except Exception:
        # Fail-open: fall back to normal permission check
        sys.exit(0)


if __name__ == "__main__":
    main()
