---
name: Git Ship
description: This skill should be used when code implementation is complete and uncommitted changes exist on a feature/fix/docs/chore branch. It automates the complete git workflow from branch creation and commits to draft PR creation, and can also be manually invoked with "/git-ship" or phrases like "ship changes", "create a PR".
version: 0.1.0
allowed-tools: TodoWrite, Read, Grep, "Bash(git:*)", "Bash(gh:*)", "Bash(find:*)", "Bash(cat:*)", "Bash(ls:*)"
argument-hint: "[draft] [--no-pr] [--base branch-name] [custom commit message]"
---

# Git Ship - Automated Git Workflow

## Overview

Automates the complete git workflow from uncommitted changes to PR creation. This skill handles branch management, commit creation, pushing to remote, and draft PR creation in a single automated flow.

**PR descriptions will be written in Japanese (日本語) for this repository.**

## Workflow Steps

### 1. Pre-flight Checks

- Check for uncommitted changes with `git status`
- If no changes: Exit with "Nothing to commit"
- Check for PR template at `.github/pull_request_template.md` or `.github/PULL_REQUEST_TEMPLATE.md`
- If creating PR and no template found: Stop and request template creation

### 2. Branch Management

Check current branch and create new if needed:

- Get current branch: `git branch --show-current`
- If on main branch with uncommitted changes:
  - Stash any uncommitted changes: `git stash --include-untracked`
  - Pull latest changes: `git pull origin main`
  - Analyze changes to determine branch type
  - Generate branch name: `prefix/description`
    - `feat/` - New features
    - `fix/` - Bug fixes
    - `docs/` - Documentation only
    - `chore/` - Maintenance tasks
  - Create and switch to the new branch: `git switch -c branch-name`
  - Restore stashed changes: `git stash pop`
- If already on a feature/fix/docs/chore branch:
  - Continue with current branch (no new branch creation)

### 3. Commit Changes

- Stage all changes: `git add -A`
- Generate or use provided commit message
- Follow conventional commits: `type: description`
- Create the commit

### 4. Push to Remote

- Push the new branch: `git push -u origin branch-name`

### 5. Create Pull Request (unless --no-pr)

- Determine base branch (default: main)
- Fill PR template with **Japanese descriptions**:
  - Summary from commit messages (日本語で記載)
  - List of changed files
  - Test cases if test files modified
- Create PR with `gh pr create`
  - **Default: Create as draft PR** (use `--no-draft` to create as ready for review)
  - Use filled template as body with Japanese content

### 6. Add Labels (C-FO organization only)

If the repository organization is `C-FO`:
- Add `ai-contribution-level:3` label to the PR
- Use `gh pr create --label "ai-contribution-level:3"` if supported
- If `--label` option is not available, use `gh pr edit <PR-NUMBER> --add-label "ai-contribution-level:3"` after PR creation

## Arguments

- `draft` - Create draft PR (default behavior)
- `--no-draft` - Create PR as ready for review
- `--no-pr` - Skip PR creation, only commit and push changes
- `--base branch` - Target branch for PR
- `"message"` - Custom commit message

## Examples

```bash
/git-ship                     # Full automation (draft PR)
/git-ship --no-draft          # Create PR ready for review
/git-ship --no-pr             # Commit and push only
/git-ship "fix: urgent bug"   # Custom commit message
```

## Error Handling

- No changes: Exit gracefully
- No template: Stop (for PR creation)
- Push failures: Check remote configuration
- PR exists: Show existing PR link

## Best Practices

- Always ensure changes are tested before shipping
- Use meaningful commit messages that describe the "why"
- Review the generated PR description before finalizing
