---
allowed-tools: TodoWrite, Read, Grep, "Bash(git:*)", "Bash(find:*)", "Bash(cat:*)", "Bash(ls:*)"
description: "Automate git workflow: create commit, push"
---

# Auto Commit

## Overview
Automates the complete git workflow from uncommitted changes to push.

## Workflow Steps

### 1. Pre-flight Checks
- Get current branch: `git branch --show-current`

### 2. Commit Changes
- Stage all changes: `git add -A`
- Generate or use provided commit message
- Follow conventional commits: `type: description`
- **IMPORTANT: Write commit messages in English**
- Create the commit

### 3. Push to Remote
- Push the new branch: `git push -u origin branch-name`
