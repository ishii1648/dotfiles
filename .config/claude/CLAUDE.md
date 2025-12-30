# Claude Code Guidelines

## Design and Planning

- If you have any questions when starting design or work planning, please use AskUserQuestion or EnterPlanMode

## Worktree Safety

- When working inside a `.worktrees/` directory, you must never read, write, or modify files in the main repository. All file operations must be scoped to the current worktree's `$PWD`.
