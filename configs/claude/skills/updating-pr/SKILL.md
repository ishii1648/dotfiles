---
name: updating-pr
description: >-
  Updates an existing PR title and description based on commit history.
  Analyzes commits since branch divergence from base and regenerates PR content.
  Use when PR content is outdated after additional commits, or when user says
  "update PR", "refresh PR description", or "sync PR with commits".
version: 0.1.0
allowed-tools: Read, Grep, "Bash(git:*)", "Bash(gh:*)"
---

# Updating PR - Commit-Based PR Content Updater

## Overview

Analyzes the commit history of the current branch and updates the associated Pull Request's title and description to reflect the actual changes. Ensures PR content stays synchronized with the code changes.

**PR descriptions will be written in Japanese (日本語) for this repository.**

## Workflow Steps

### 1. Pre-flight Checks

#### 1a. Verify Branch Status

```bash
git branch --show-current
```

- If on `main` or `master`: Exit with "Not on a feature branch. Nothing to update."

#### 1b. Check for Associated PR

```bash
gh pr view --json number,title,body,baseRefName
```

- If no PR found: Exit with "No PR associated with this branch. Use /git-ship to create one."
- Store PR number, current title, body, and base branch name

### 2. Gather Commit Information

#### 2a. Get Base Branch

Use `baseRefName` from PR data (e.g., `main`, `master`, `develop`).

#### 2b. Get Commit History Since Divergence

```bash
git log <base-branch>..HEAD --pretty=format:"%s%n%b" --reverse
```

Collect all commit subjects and bodies for analysis.

#### 2c. Get Changed Files Summary

```bash
git diff <base-branch>...HEAD --stat
```

### 3. Generate Updated PR Content

#### 3a. Analyze Commits

- Identify the primary change type (feat, fix, docs, chore, refactor)
- Extract key changes from commit messages
- Group related commits

#### 3b. Generate New Title

- Keep under 70 characters
- Follow conventional commit style: `type: concise description`
- Reflect the overall change, not individual commits

#### 3c. Generate New Description

**Preserve the existing PR description format.** Analyze the current PR body structure (sections, headings, bullet style) and update the content while maintaining the same format.

- If the PR has sections like `## Summary`, `## Changes`, etc., keep those section names
- If the PR uses Japanese headings like `## 概要`, keep Japanese
- If the PR uses bullet points, continue using bullet points
- Only update the content within each section based on the new commit information

**If the existing PR body is empty or minimal**, use this default format:

```markdown
## 概要
<1-3 bullet points summarizing the changes>

## 変更内容
<List of key changes based on commits>
```

### 4. Update the PR

```bash
gh pr edit <PR-NUMBER> --title "<new-title>" --body "<new-body>"
```

### 5. Confirmation

Display:
- PR URL
- Updated title
- Summary of description changes

## Arguments

This skill accepts no arguments. It operates on the current branch's associated PR.

## Examples

```bash
/updating-pr    # Update PR title and description from commits
```

## Error Handling

| Scenario | Response |
|----------|----------|
| On main/master branch | Exit: "Not on a feature branch" |
| No associated PR | Exit: "No PR found. Use /git-ship to create one" |
| No commits since base | Exit: "No commits to analyze" |
| gh command fails | Display error and suggest checking gh auth status |
