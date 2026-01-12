---
description: "Create a new skill with correct format and directory structure"
allowed-tools: Write, Read, AskUserQuestion, Task, Glob, Bash(mkdir:*)
argument-hint: "[skill-name]"
---

# Create Skill

Create a new skill with the correct directory structure and SKILL.md format, then validate it using the format-validator agent.

## Process

### Step 1: Gather Requirements

Ask the user (if not provided in `$ARGUMENTS`):

1. **Skill Name**: What should this skill be called? (kebab-case for directory, Display Name for frontmatter)
2. **Trigger Phrases**: What specific phrases should trigger this skill? (Give 3-5 examples in quotes)
3. **Purpose**: What knowledge or capability does this skill provide?
4. **Resources Needed**: Will it need:
   - Reference documentation? (`references/`)
   - Example files? (`examples/`)
   - Helper scripts? (`scripts/`)

### Step 2: Determine Save Location

Ask the user where to save:
- **Project-local**: `.claude/skills/[skill-name]/`
- **Personal**: `.config/claude/skills/[skill-name]/`

### Step 3: Create Directory Structure

Create the skill directory and subdirectories as needed:

```bash
mkdir -p [location]/skills/[skill-name]
mkdir -p [location]/skills/[skill-name]/references  # if needed
mkdir -p [location]/skills/[skill-name]/examples    # if needed
mkdir -p [location]/skills/[skill-name]/scripts     # if needed
```

### Step 4: Generate SKILL.md

Use this EXACT format template:

```markdown
---
name: [Display Name]
description: This skill should be used when the user asks to "[phrase1]", "[phrase2]", "[phrase3]", or needs guidance on [topic]. Provides comprehensive knowledge about [domain].
version: 0.1.0
---

# [Skill Title]

## Overview

[2-3 paragraphs explaining what this skill provides and when to use it]

## [Core Section 1]

### [Subsection]

[Content in imperative/infinitive form]
- To accomplish X, do Y
- For best results, ensure Z

### [Subsection]

[More content]

## [Core Section 2]

[Additional content]

## Best Practices

- [Practice 1]
- [Practice 2]
- [Practice 3]

## Additional Resources

### Reference Files
- **`references/[file].md`** - [Description of what it contains]

### Examples
- **`examples/[file]`** - [Description of the example]

### Scripts
- **`scripts/[file].sh`** - [Description of what it does]
```

### Format Rules (CRITICAL - must follow exactly)

1. **Frontmatter Fields**:
   - `name`: Display name for the skill
   - `description`: MUST be third person ("This skill should be used when...")
   - `description`: MUST include specific trigger phrases in quotes
   - `version`: Semantic version (e.g., `0.1.0`)

2. **Description Format**:
   - MUST start with "This skill should be used when"
   - Include 3-5 specific trigger phrases in quotes
   - WRONG: "Use this skill for working with hooks"
   - RIGHT: "This skill should be used when the user asks to \"create a hook\", \"add a PreToolUse hook\", \"validate tool use\""

3. **Body Content**:
   - Use imperative/infinitive form, NOT second person
   - WRONG: "You should start by reading the file"
   - RIGHT: "Start by reading the file" or "To begin, read the file"
   - Target 1,500-2,000 words for SKILL.md (core concepts only)
   - Put detailed content in `references/` for progressive disclosure

4. **Progressive Disclosure**:
   - `SKILL.md`: Core concepts, workflow overview (always loaded when skill triggers)
   - `references/`: Detailed patterns, API docs, troubleshooting (loaded on demand)
   - `examples/`: Working examples, templates (loaded on demand)
   - `scripts/`: Executable utilities (executed, not loaded)

### Step 5: Write SKILL.md

Write the generated content to `[skill-directory]/SKILL.md`.

### Step 6: Create Supporting Files (if needed)

If the user requested references/examples/scripts, create placeholder or initial content:

**Reference file template** (`references/[topic].md`):
```markdown
# [Topic] Reference

## Overview
[Detailed information about the topic]

## Patterns
[Common patterns and usage]

## Troubleshooting
[Common issues and solutions]
```

**Example file template** (`examples/[example-name].md` or actual code files):
```markdown
# [Example Name]

## Purpose
[What this example demonstrates]

## Code
[The example code or content]

## Explanation
[How it works]
```

### Step 7: Validate Format

After writing, invoke the format-validator agent using Task tool:

```
Validate the skill format for [full path to SKILL.md]
Read the file and check all skill format rules including:
- Required frontmatter fields (name, description)
- Description in third person ("This skill should be used when...")
- Specific trigger phrases in quotes
- Body in imperative/infinitive form (not second person)
Report any Critical, Major, or Minor issues found.
```

### Step 8: Handle Validation Results

If validation **PASSES**:
- Report success to user
- Show the skill directory structure

If validation **FAILS**:
- Show the validation errors
- Offer to fix automatically
- After fixing, re-validate

## Example Output

A properly formatted skill:

**Directory structure:**
```
skills/
└── hook-development/
    ├── SKILL.md
    ├── references/
    │   ├── hook-events.md
    │   └── prompt-hooks.md
    └── examples/
        └── validation-hook.md
```

**SKILL.md content:**
```markdown
---
name: Hook Development
description: This skill should be used when the user asks to "create a hook", "add a PreToolUse hook", "validate tool use", "implement prompt-based hooks", or mentions hook events like PreToolUse, PostToolUse, Stop. Provides comprehensive guidance for creating Claude Code plugin hooks.
version: 0.1.0
---

# Hook Development for Claude Code

## Overview

Hooks are event-driven automations that execute in response to specific events during a Claude Code session. They enable validation, logging, and custom behaviors.

## Hook Types

### Command Hooks

Execute shell commands in response to events.

To create a command hook:
1. Define the event type (PreToolUse, PostToolUse, etc.)
2. Specify the command to execute
3. Set appropriate timeout

### Prompt Hooks

Use LLM evaluation for context-aware decisions.

To create a prompt hook:
1. Define the event type
2. Write the evaluation prompt
3. Handle the response

## Best Practices

- Use minimum required permissions
- Set appropriate timeouts
- Test hooks in isolation before deployment

## Additional Resources

### Reference Files
- **`references/hook-events.md`** - Complete event type documentation
- **`references/prompt-hooks.md`** - Advanced prompt hook patterns

### Examples
- **`examples/validation-hook.md`** - Pre-tool validation example
```
