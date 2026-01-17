---
description: "Receive shared content from another Claude session"
allowed-tools: Read, Glob
argument-hint: "[name]"
---

# Receive Shared Content

Retrieve code snippets or instructions shared from another Claude Code session.

## Shared Directory Structure

```
~/.claude/shared/
├── clipboard.md      # Default (no name specified)
└── snippets/         # Named snippets
    └── [name].md
```

## Process

### Step 1: Determine Source File

- If `$1` is provided: Read from `~/.claude/shared/snippets/$1.md`
- If `$1` is not provided: Read from `~/.claude/shared/clipboard.md`

### Step 2: Check File Existence

Attempt to read the file. If it doesn't exist:
- Report that no shared content was found
- If named snippet was requested, list available snippets in `~/.claude/shared/snippets/`

### Step 3: Read and Parse Content

Read the shared file and extract:
- Metadata (shared_at, source_dir) from frontmatter
- The actual shared content

### Step 4: Present Content

Display to the user:
- When it was shared
- From which directory it was shared
- The content itself

### Step 5: Offer Actions

Ask the user what they want to do with the received content:
- Apply/use it in the current context
- Just view it (no action needed)
- Save it to a local file

## Example Output

```
Received shared content:
- Shared at: 2025-01-17T10:30:00Z
- From: /path/to/repo-a

---
[Content displayed here]
---

What would you like to do with this content?
```

## Listing Available Snippets

If `/receive` is called with no argument and clipboard is empty, or if the user wants to see what's available, list all files in `~/.claude/shared/snippets/`.
