---
description: "Share code or instructions to other Claude sessions"
allowed-tools: Write, Bash(mkdir:*)
argument-hint: "[name]"
---

# Share Content

Share code snippets or instructions to other Claude Code sessions via file-based sharing.

## Shared Directory Structure

```
~/.claude/shared/
├── clipboard.md      # Default (no name specified)
└── snippets/         # Named snippets
    └── [name].md
```

## Process

### Step 1: Determine Share Target

- If `$1` is provided: Save to `~/.claude/shared/snippets/$1.md`
- If `$1` is not provided: Save to `~/.claude/shared/clipboard.md`

### Step 2: Ensure Directory Exists

Create the shared directory if it doesn't exist:

```bash
mkdir -p ~/.claude/shared/snippets
```

### Step 3: Collect Content to Share

Ask the user what content they want to share. Common use cases:
- Code snippets from the current session
- Implementation patterns discovered
- Instructions or notes for the other session
- File contents that should be referenced

### Step 4: Write Shared File

Write the content to the appropriate file with metadata:

```markdown
---
shared_at: [ISO timestamp]
source_dir: [current working directory]
---

[Content provided by user]
```

### Step 5: Confirm

Report to the user:
- Where the content was saved
- How to retrieve it in another session: `/receive` or `/receive [name]`

## Example

User in Session A:
```
> /share auth-pattern
```

Claude saves to `~/.claude/shared/snippets/auth-pattern.md`:
```markdown
---
shared_at: 2025-01-17T10:30:00Z
source_dir: /path/to/repo-a
---

[User's shared content here]
```

User in Session B retrieves with:
```
> /receive auth-pattern
```
