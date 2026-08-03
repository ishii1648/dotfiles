#!/usr/bin/env python3
# ADR: 082
# Purpose: worktree と branch の 1:1 対応を守るため、main worktree の default branch からの離脱と、linked worktree の branch 切替を PreToolUse でブロックする
"""PreToolUse hook: keep every worktree pinned to a single branch.

The main worktree (where `git rev-parse --git-dir` and `--git-common-dir`
resolve to the same path) is expected to always stay on the repository's
default branch. Every linked worktree is expected to stay on whatever
branch it currently has checked out — branch changes always happen by
creating a new worktree (EnterWorktree), never by switching branches
inside an existing one. This hook blocks the `git switch`/`git checkout`
footgun that would otherwise let either kind of worktree drift onto a
different branch, so the rule doesn't rely on the model remembering to
call EnterWorktree first.

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


def current_branch(cwd: str) -> str:
    """Currently checked-out branch, or "" if detached/undeterminable (fail-open)."""
    return _run_git(["branch", "--show-current"], cwd) or ""


_HEREDOC_START_RE = re.compile(r"<<-?\s*(['\"]?)(\w+)\1")


def _strip_heredocs(command: str) -> str:
    """Blank out heredoc bodies so their literal text isn't parsed as shell.

    A heredoc body (e.g. the commit message inside
    `git commit -m "$(cat <<'EOF' ... EOF)"`) is arbitrary text, not shell
    syntax — but it can easily *contain* strings like `cd foo && git switch
    bar` (this file's own commit messages do). Without this, such text gets
    split on `&&`/`;`/`|` and misparsed as a real invocation.
    """
    lines = command.split("\n")
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        match = _HEREDOC_START_RE.search(line)
        if not match:
            out.append(line)
            i += 1
            continue
        delimiter = match.group(2)
        out.append(line)
        i += 1
        while i < len(lines) and lines[i].strip() != delimiter:
            i += 1
        if i < len(lines):
            out.append(lines[i])
            i += 1
    return "\n".join(out)


def _split_on_shell_separators(command: str):
    return re.split(r"&&|\|\||[;|]", _strip_heredocs(command))


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


def _resolve_path(path: str, base: str) -> str:
    """Resolve `path` (absolute, `~`, or relative) against `base`."""
    expanded = os.path.expanduser(path)
    return expanded if os.path.isabs(expanded) else os.path.join(base, expanded)


def extract_git_switch_invocations(command: str, cwd: str):
    """Yield (subcmd, target, effective_cwd) for each branch-changing switch/checkout.

    Segments are walked left to right with a `running_cwd` that mimics what a
    real shell's cwd would be at that point, so `cd <dir> && git switch ...`
    (no `-C` at all) is tracked instead of silently using the hook's original
    process cwd. `-C <path>` only affects that single git invocation's
    effective cwd (resolved against `running_cwd`, matching git's own
    behavior) and never mutates `running_cwd` itself, since -C is not a shell
    builtin.

    Without this, either of these would go undetected:
      - `cd <main worktree> && git switch <branch>` (bypass: no -C involved)
      - `cd <dir> && git -C <relative path> switch <branch>` (bypass: -C
        resolved against the hook's original cwd instead of the post-cd one)
    And this would false-positive block a legitimate linked-worktree op:
      - `git -C <linked worktree> switch <branch>` run from the main worktree
    """
    running_cwd = cwd

    for segment in _split_on_shell_separators(command):
        segment = segment.strip()
        if not segment:
            continue
        try:
            words = shlex.split(segment)
        except ValueError:
            continue
        if not words:
            continue

        if words[0] == "cd":
            target = words[1] if len(words) > 1 else "~"
            running_cwd = _resolve_path(target, running_cwd)
            continue

        if words[0] != "git":
            continue

        effective_cwd = running_cwd
        i = 1
        while i < len(words) and words[i].startswith("-"):
            if words[i] == "-C":
                if i + 1 >= len(words):
                    break
                effective_cwd = _resolve_path(words[i + 1], effective_cwd)
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

        target_branch = _switch_target(subcmd, words[i + 1 :], effective_cwd)
        if target_branch:
            yield subcmd, target_branch, effective_cwd


def main():
    try:
        hook_input = json.load(sys.stdin)

        if hook_input.get("tool_name") != "Bash":
            sys.exit(0)

        tool_input = hook_input.get("tool_input", {})
        command = tool_input.get("command", "")
        if not command:
            sys.exit(0)

        # hook_input の cwd（Claude Code が追跡する実際のセッション cwd）を優先し、
        # 無ければ hook プロセス自身の cwd にフォールバックする
        cwd = hook_input.get("cwd") or os.getcwd()

        for subcmd, target, effective_cwd in extract_git_switch_invocations(command, cwd):
            if is_main_worktree(effective_cwd):
                pinned = default_branch(effective_cwd)
                kind = "main worktree"
            else:
                pinned = current_branch(effective_cwd)
                if not pinned:
                    # detached HEAD 等、現在の branch を判定できない場合は fail-open
                    continue
                kind = "linked worktree"

            if target == pinned:
                continue

            reason = (
                f"{kind}（{effective_cwd}）は {pinned} に固定してください。"
                "別ブランチの作業は既存 worktree 内で切り替えず、"
                "EnterWorktree で新しい worktree を作ってから行ってください"
                f"（`git {subcmd} {target}` をこの worktree で実行しようとしました）。"
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
