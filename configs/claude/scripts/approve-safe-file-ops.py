#!/usr/bin/env python3
"""PreToolUse hook: auto-approve file ops in .claude/ subdirectories.

.claude/ 直下のファイル（settings.json 等）は通常の permission prompt。
.claude/{skills,agents,commands,...}/ 以下はauto-approve。

Fail-open: 例外時は sys.exit(0) でデフォルト動作にフォールバック。
"""
import json
import os
import sys


def is_safe_claude_subdir_path(file_path: str) -> bool:
    parts = os.path.normpath(os.path.expanduser(file_path)).split(os.sep)
    try:
        idx = next(i for i, p in enumerate(parts) if p == ".claude")
    except StopIteration:
        return False
    # .claude/ の次にサブディレクトリが存在すること（直下ファイルは除外）
    # parts[idx+1] がディレクトリ名、parts[idx+2] 以降がファイル名
    return idx + 2 < len(parts)


def main():
    try:
        hook_input = json.load(sys.stdin)
        tool_name = hook_input.get("tool_name", "")
        if tool_name not in ("Write", "Edit", "NotebookEdit"):
            sys.exit(0)
        tool_input = hook_input.get("tool_input", {})
        file_path = tool_input.get("file_path") or tool_input.get("notebook_path", "")
        if not file_path:
            sys.exit(0)
        if is_safe_claude_subdir_path(file_path):
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow"
            }}))
        sys.exit(0)
    except Exception:
        sys.exit(0)


if __name__ == "__main__":
    main()
