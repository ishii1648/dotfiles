---
allowed-tools: Bash(bash:*), Bash(git:*)
description: "Create git worktree and move uncommitted changes to it"
---

# Worktree Creation Command

Create a new git worktree and transfer all uncommitted changes to it.

## Step 1: Generate Feature Name

Analyze the current session context to generate an appropriate feature name:

1. Review the conversation history to understand what was discussed/implemented
2. Check for any created or modified files with `git status`
3. Generate a concise, descriptive feature name in kebab-case (e.g., `add-user-auth`, `fix-login-bug`, `refactor-api-client`)

**Naming rules:**
- Use kebab-case (lowercase with hyphens)
- Keep it short (2-4 words)
- Be descriptive of the feature/fix/change
- Examples: `add-dark-mode`, `fix-validation-error`, `update-api-endpoints`

## Step 2: Rename Current Session

Before creating the worktree, rename the current session so it can be resumed in the new worktree:

```
/rename <feature-name>
```

This allows the session to be resumed with `claude --resume <feature-name>` in the new worktree.

## Step 3: Execute Worktree Creation

Once you have renamed the session, run:

```bash
bash ~/.claude/scripts/worktree-command.sh <feature-name>
```

Replace `<feature-name>` with the name you generated in Step 1.
