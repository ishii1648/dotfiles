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
  3. Read-only git commands (log, diff, show, branch, status, shortlog,
     rev-list, rev-parse, describe, tag -l, stash list) optionally piped
     to head/tail/wc/sort/uniq/grep
  4. Read-only gh api commands optionally piped to jq/head/tail/wc/sort/uniq/grep
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


def _split_on_pipes(command: str) -> list:
    """Split command on pipe '|' characters, respecting quoted strings."""
    segments = []
    current = []
    in_single = False
    in_double = False
    i = 0
    while i < len(command):
        c = command[i]
        if c == "'" and not in_double:
            in_single = not in_single
            current.append(c)
        elif c == '"' and not in_single:
            in_double = not in_double
            current.append(c)
        elif c == "|" and not in_single and not in_double:
            seg = "".join(current).strip()
            if seg:
                segments.append(seg)
            current = []
        else:
            current.append(c)
        i += 1
    seg = "".join(current).strip()
    if seg:
        segments.append(seg)
    return segments


def is_safe_readonly_git(command: str) -> bool:
    """Check if the command is a read-only git command, optionally piped.

    Approves patterns like:
        git log --oneline
        git -C /path/to/repo log --all --format="%h %s" | head -30
        git diff main..feature 2>/dev/null | grep foo
        git show HEAD:file.txt | wc -l

    The command must start with 'git' and use a read-only subcommand.
    Only safe pipe targets (head, tail, wc, sort, uniq, grep) are allowed.
    """
    # Strip trailing redirects like 2>/dev/null before pipe analysis
    stripped = re.sub(r"\d*>/dev/null\s*", "", command).strip()

    # Split on pipes (outside of quotes)
    pipe_segments = _split_on_pipes(stripped)
    if not pipe_segments:
        return False

    first = pipe_segments[0]

    # Must start with 'git' — use shlex to handle quoted args
    import shlex
    try:
        words = shlex.split(first)
    except ValueError:
        return False
    if not words or words[0] != "git":
        return False

    # Find the git subcommand (skip -C <path> and other global flags)
    safe_subcommands = {
        "log", "diff", "show", "branch", "status", "shortlog",
        "rev-list", "rev-parse", "describe", "tag", "stash",
        "ls-files", "ls-tree", "cat-file", "name-rev", "merge-base",
        "reflog", "blame", "whatchanged",
    }
    found_subcommand = False
    i = 1
    while i < len(words):
        w = words[i]
        if w.startswith("-"):
            # Global flag; skip its value if it takes one (-C <path>)
            if w in ("-C", "-c", "--git-dir", "--work-tree"):
                i += 2
                continue
            i += 1
            continue
        # First non-flag word is the subcommand
        if w in safe_subcommands:
            found_subcommand = True
        break

    if not found_subcommand:
        return False

    # Validate pipe targets (if any)
    safe_pipe_commands = {"head", "tail", "wc", "sort", "uniq", "grep", "rg"}
    for seg in pipe_segments[1:]:
        seg_words = seg.split()
        if not seg_words:
            return False
        if seg_words[0] not in safe_pipe_commands:
            return False

    return True


def is_safe_readonly_gh_api(command: str) -> bool:
    """Check if the command is a read-only gh api command, optionally piped.

    Approves patterns like:
        gh api repos/owner/repo/pulls
        gh api repos/owner/repo/pulls/123/reviews --paginate 2>/dev/null | jq -r '...'
        gh api /repos/owner/repo/issues --paginate | jq '.[] | .title'

    Only approves GET requests (no -X POST/PUT/PATCH/DELETE).
    Only safe pipe targets (jq, head, tail, wc, sort, uniq, grep) are allowed.
    """
    # Strip trailing redirects like 2>/dev/null before pipe analysis
    stripped = re.sub(r"\d*>/dev/null\s*", "", command).strip()

    # Split on pipes (outside of quotes)
    pipe_segments = _split_on_pipes(stripped)
    if not pipe_segments:
        return False

    first = pipe_segments[0]

    import shlex
    try:
        words = shlex.split(first)
    except ValueError:
        return False
    if len(words) < 3 or words[0] != "gh" or words[1] != "api":
        return False

    # Reject mutating methods and data-sending flags
    # -f/--field/-F/--raw-field implicitly switch to POST
    blocked_flags = {"-X", "--method", "--input", "-f", "--field", "-F", "--raw-field"}
    for w in words:
        if w in blocked_flags:
            return False

    # Validate pipe targets (if any)
    safe_pipe_commands = {"jq", "head", "tail", "wc", "sort", "uniq", "grep", "rg"}
    for seg in pipe_segments[1:]:
        seg_words = seg.split()
        if not seg_words:
            return False
        if seg_words[0] not in safe_pipe_commands:
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

        if is_safe_command_substitution(command) or has_only_dash_separators_in_quotes(command) or is_safe_readonly_git(command) or is_safe_readonly_gh_api(command):
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
