---
description: "Create a new slash command with correct format"
allowed-tools: Write, Read, AskUserQuestion, Task, Glob
argument-hint: "[command-name] [brief-description]"
---

# Create Slash Command

Create a new slash command file with the correct format, then validate it using the format-validator agent.

## Process

### Step 1: Gather Requirements

If `$1` (command name) is not provided, ask the user:
- Command name (kebab-case, e.g., `review-pr`, `run-tests`)

If `$2` (description) is not provided, ask the user:
- What should this command do? (Brief description)

Also ask:
- What tools does this command need? (Read, Write, Bash, etc.)
- Does it accept arguments? If so, what format?

### Step 2: Determine Save Location

Ask the user where to save:
- **Project-local**: `.claude/commands/[name].md` (current project only)
- **Personal**: `.config/claude/commands/[name].md` (all projects via dotfiles)

### Step 3: Generate Command File

Use this EXACT format template:

```markdown
---
description: "[Brief description under 60 chars]"
allowed-tools: [Comma-separated tools, e.g., Read, Write, Bash(git:*)]
argument-hint: "[arg1] [arg2]"
---

# [Command Title]

[Instructions FOR Claude in imperative form]

## Process
1. [Step 1]
2. [Step 2]
...
```

### Format Rules (CRITICAL - must follow exactly)

1. **Frontmatter**:
   - MUST start with `---` on line 1
   - MUST have `description` field (string, <60 chars recommended)
   - `allowed-tools`: List only required tools
   - `argument-hint`: Document expected arguments

2. **Body Content**:
   - Write instructions FOR Claude, NOT messages TO the user
   - Use imperative form: "Read the file", "Analyze the code"
   - WRONG: "This command will analyze your code"
   - RIGHT: "Analyze the provided code for issues"

3. **Arguments**:
   - `$ARGUMENTS` - All arguments as single string
   - `$1`, `$2`, `$3` - Positional arguments
   - `@$1` - File reference (auto-reads file content)

### Step 4: Write File

Write the generated content to the determined path.

### Step 5: Validate Format

After writing, invoke the format-validator agent using Task tool:

```
Validate the command format for [full file path]
Read the file and check all command format rules.
Report any Critical, Major, or Minor issues found.
```

### Step 6: Handle Validation Results

If validation **PASSES**:
- Report success to user
- Show the file path

If validation **FAILS**:
- Show the validation errors
- Offer to fix automatically
- After fixing, re-validate

## Example Output

A properly formatted command:

```markdown
---
description: "Review PR changes for code quality issues"
allowed-tools: Read, Bash(gh:*), Bash(git:*)
argument-hint: "[pr-number]"
---

# Review Pull Request

Review the specified pull request for code quality, security, and best practices.

## Process

1. Fetch PR details using `gh pr view $1`
2. Get the diff using `gh pr diff $1`
3. Analyze changes for:
   - Code style violations
   - Potential bugs
   - Security concerns
   - Missing tests
4. Provide structured feedback with specific line references
```
