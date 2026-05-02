#!/usr/bin/env python3
"""PreToolUse hook: approve safe file operations on .claude/ subdirectories.

Auto-approves Read/Write/Edit/NotebookEdit operations on .claude/{subdir}/ paths.
Passes through for .claude/ direct files and non-.claude/ paths.
Fail-open design: any exception results in sys.exit(0) to fall back
to the normal permission prompt.
"""

import json
import os
import re
import sys

FILE_OPS_TOOLS = {"Read", "Write", "Edit", "NotebookEdit"}


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


def is_dispatch_path(file_path: str) -> bool:
    """Check if the path is under ~/.dispatch/ (dispatch session manifests).

    Allow:
      ~/.dispatch/ishii1648-tmux-sidebar-20260412-185317-eb61/manifest.json
    """
    expanded = os.path.expanduser(file_path)
    return bool(re.search(r"/\.dispatch/[^/]+/", expanded))


def get_file_path(tool_name: str, tool_input: dict) -> str:
    if tool_name == "NotebookEdit":
        return tool_input.get("notebook_path", "")
    return tool_input.get("file_path", "")


def main():
    try:
        hook_input = json.load(sys.stdin)

        tool_name = hook_input.get("tool_name", "")
        if tool_name not in FILE_OPS_TOOLS:
            sys.exit(0)

        # auto 系 mode では file ops が既に許可されるため approve は冗長
        permission_mode = hook_input.get("permission_mode", "")
        if permission_mode in ("auto", "bypassPermissions", "dontAsk", "acceptEdits"):
            sys.exit(0)

        file_path = get_file_path(tool_name, hook_input.get("tool_input", {}))
        if not file_path:
            sys.exit(0)

        if is_claude_subdir_path(file_path) or is_dispatch_path(file_path):
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
