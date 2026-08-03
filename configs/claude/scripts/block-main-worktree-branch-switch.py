#!/usr/bin/env python3
# ADR: 081
# Purpose: main worktree での git switch/checkout による default branch からの離脱を PreToolUse でブロックし EnterWorktree 経由の分離を強制する
"""PreToolUse hook: block branch-changing git switch/checkout in the main worktree.

The main worktree (where `git rev-parse --git-dir` and `--git-common-dir`
resolve to the same path) is expected to always stay on the repository's
default branch; feature work should move to a linked worktree via
EnterWorktree instead. This hook blocks the `git switch`/`git checkout`
footgun that leaves the main worktree stranded on a non-default branch,
so the rule doesn't rely on the model remembering to call EnterWorktree
first.

Fail-open design: any exception (not a git repo, git not found, ambiguous
parse, etc.) results in sys.exit(0) to fall back to normal behavior.
"""

import json
import os
import re
import shlex
import subprocess
import sys


def _run_git(args, cwd):
    try:
        result = subprocess.run(
            ["git", *args], cwd=cwd, capture_output=True, text=True, timeout=5
        )
    except Exception:
        return None
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def is_main_worktree(cwd: str) -> bool:
    """True if cwd is the main worktree (not a linked worktree)."""
    git_dir = _run_git(["rev-parse", "--git-dir"], cwd)
    common_dir = _run_git(["rev-parse", "--git-common-dir"], cwd)
    if not git_dir or not common_dir:
        return False
    return os.path.abspath(os.path.join(cwd, git_dir)) == os.path.abspath(
        os.path.join(cwd, common_dir)
    )


def default_branch(cwd: str) -> str:
    ref = _run_git(["symbolic-ref", "refs/remotes/origin/HEAD"], cwd)
    if ref:
        return ref.rsplit("/", 1)[-1]
    configured = _run_git(["config", "init.defaultBranch"], cwd)
    return configured or "main"


def _split_on_shell_separators(command: str):
    return re.split(r"&&|\|\||[;|]", command)


def _switch_target(subcmd: str, rest: list, cwd: str) -> str:
    """Best-effort extraction of the branch target for switch/checkout.

    Returns "" when the invocation is not a branch-changing switch
    (no args, `-- <path>` file-restore forms, or ambiguous path checkout).
    """
    if "--" in rest:
        return ""

    positional = [w for w in rest if not w.startswith("-")]
    if not positional:
        return ""

    target = positional[0]
    if target in (".", "-"):
        return ""

    # checkout の曖昧系: 既存パスと一致する場合はファイル復元とみなし対象外にする
    if subcmd == "checkout" and os.path.exists(os.path.join(cwd, target)):
        return ""

    return target


def _resolve_dash_c(path: str, cwd: str) -> str:
    """Resolve a single `-C <path>` value against the current effective cwd.

    git resolves repeated -C flags relative to the previous one, so callers
    should thread the returned value back in as `cwd` for the next -C.
    """
    return path if os.path.isabs(path) else os.path.join(cwd, path)


def extract_git_switch_invocations(command: str, cwd: str):
    """Yield (subcmd, target, effective_cwd) for each branch-changing switch/checkout.

    `-C <path>` is resolved per invocation so the main-worktree/default-branch
    check runs against the directory git would actually operate on, not the
    process cwd. Without this, `git -C <other-repo> switch ...` would either
    bypass detection (cwd outside the main worktree) or false-positive block
    a legitimate linked-worktree operation (cwd is the main worktree but -C
    points elsewhere).
    """
    for segment in _split_on_shell_separators(command):
        segment = segment.strip()
        if not segment:
            continue
        try:
            words = shlex.split(segment)
        except ValueError:
            continue
        if not words or words[0] != "git":
            continue

        effective_cwd = cwd
        i = 1
        while i < len(words) and words[i].startswith("-"):
            if words[i] == "-C":
                if i + 1 >= len(words):
                    break
                effective_cwd = _resolve_dash_c(words[i + 1], effective_cwd)
                i += 2
                continue
            if words[i] in ("-c", "--git-dir", "--work-tree"):
                i += 2
                continue
            i += 1
        if i >= len(words):
            continue

        subcmd = words[i]
        if subcmd not in ("switch", "checkout"):
            continue

        target = _switch_target(subcmd, words[i + 1 :], effective_cwd)
        if target:
            yield subcmd, target, effective_cwd


def main():
    try:
        hook_input = json.load(sys.stdin)

        if hook_input.get("tool_name") != "Bash":
            sys.exit(0)

        tool_input = hook_input.get("tool_input", {})
        command = tool_input.get("command", "")
        if not command:
            sys.exit(0)

        cwd = os.getcwd()

        for subcmd, target, effective_cwd in extract_git_switch_invocations(command, cwd):
            if not is_main_worktree(effective_cwd):
                continue

            default = default_branch(effective_cwd)
            if target != default:
                reason = (
                    f"main worktree（{effective_cwd}）は {default} に固定してください。"
                    "作業ブランチへの切替は EnterWorktree で専用 worktree を作ってから行ってください"
                    f"（`git {subcmd} {target}` を main worktree で実行しようとしました）。"
                )
                output = {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "deny",
                        "permissionDecisionReason": reason,
                    }
                }
                print(json.dumps(output, ensure_ascii=False))
                sys.exit(0)

        sys.exit(0)

    except Exception:
        # Fail-open: fall back to normal behavior
        sys.exit(0)


if __name__ == "__main__":
    main()
