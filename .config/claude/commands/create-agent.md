---
description: "Create a new agent with correct frontmatter format"
allowed-tools: Write, Read, AskUserQuestion, Task, Glob, Bash(mkdir:*)
argument-hint: "[agent-purpose]"
---

# Create Agent

Create a new agent file with the correct format including proper `<example>` blocks, then validate it using the format-validator agent.

## Process

### Step 1: Gather Requirements

Ask the user (if not provided in `$ARGUMENTS`):

1. **Purpose**: What should this agent do?
2. **Trigger Scenarios**: When should this agent be invoked? (Give 2-3 specific examples of user requests)
3. **Required Tools**: What tools does this agent need? (Read, Write, Bash, etc.)
4. **Model**: Which model? (inherit=parent model, haiku=fast/cheap, sonnet=balanced, opus=complex)
5. **Color**: Display color? (blue=analysis, green=creation, yellow=validation, red=security, magenta=creative, cyan=info)

### Step 2: Determine Save Location

Ask the user where to save:
- **Project-local**: `.claude/agents/[name].md`
- **Personal**: `.config/claude/agents/[name].md`

Ensure the agents directory exists (create if needed).

### Step 3: Generate Agent File

Use this EXACT format template:

```markdown
---
name: [kebab-case-identifier]
description: |
  Use this agent when [primary trigger condition], or when the user asks to "[phrase1]", "[phrase2]", "[phrase3]". Examples:

  <example>
  Context: [Specific situation description]
  user: "[Exact user message that should trigger this agent]"
  assistant: "[Claude's response before invoking agent]"
  <commentary>
  [Explanation of why this agent should trigger in this scenario]
  </commentary>
  </example>

  <example>
  Context: [Another situation]
  user: "[Another trigger message]"
  assistant: "[Response]"
  <commentary>
  [Why trigger here]
  </commentary>
  </example>

model: [inherit|sonnet|opus|haiku]
color: [blue|cyan|green|yellow|magenta|red]
tools: ["Tool1", "Tool2"]
---

You are [expert persona] specializing in [domain].

## Core Responsibilities

1. [Primary responsibility]
2. [Secondary responsibility]
3. [Additional responsibility]

## Process

1. **[Phase 1 Name]**
   - [Action 1]
   - [Action 2]

2. **[Phase 2 Name]**
   - [Action 1]
   - [Action 2]

## Output Format

[Describe expected output structure]

## Edge Cases

- [Edge case 1]: [How to handle]
- [Edge case 2]: [How to handle]
```

### Format Rules (CRITICAL - must follow exactly)

1. **Frontmatter Fields (ALL REQUIRED)**:
   - `name`: kebab-case, 3-50 chars, alphanumeric start/end
     - Good: `code-reviewer`, `test-runner`, `pr-helper`
     - Bad: `-invalid`, `TooLong...`, `has spaces`
   - `description`: MUST start with "Use this agent when"
   - `description`: MUST contain 2+ `<example>` blocks
   - `model`: MUST be `inherit`, `sonnet`, `opus`, or `haiku`
   - `color`: MUST be `blue`, `cyan`, `green`, `yellow`, `magenta`, or `red`

2. **Example Blocks (CRITICAL)**:
   - Each `<example>` MUST contain `<commentary>` explaining WHY the agent triggers
   - Include 2-4 diverse examples covering different trigger scenarios
   - Use realistic user messages, not generic ones

3. **System Prompt (Body)**:
   - MUST use second person: "You are...", "Your role is..."
   - Include: Responsibilities, Process, Output Format
   - Recommended: 500-3000 characters
   - WRONG: "This agent analyzes code"
   - RIGHT: "You are a code analysis expert..."

### Step 4: Write File

Write the generated content to the determined path.

### Step 5: Validate Format

After writing, invoke the format-validator agent using Task tool:

```
Validate the agent format for [full file path]
Read the file and check all agent format rules including:
- Required frontmatter fields (name, description, model, color)
- Name format (kebab-case, 3-50 chars)
- Description starts with "Use this agent when"
- Contains <example> blocks with <commentary>
- Valid model and color values
- System prompt in second person
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

A properly formatted agent:

```markdown
---
name: code-reviewer
description: |
  Use this agent when the user has written code and wants a quality review, or when the user asks to "review my code", "check this implementation", "look for bugs". Examples:

  <example>
  Context: User just implemented a new feature
  user: "Can you review this authentication code I wrote?"
  assistant: "I'll review your authentication implementation."
  <commentary>
  Explicit code review request. User wants quality feedback on their implementation.
  </commentary>
  </example>

  <example>
  Context: User finished a PR and wants feedback
  user: "Check my changes before I submit the PR"
  assistant: "Let me review your changes."
  <commentary>
  Pre-PR review request. User wants to catch issues before submission.
  </commentary>
  </example>

model: sonnet
color: blue
tools: ["Read", "Grep"]
---

You are an expert code reviewer with deep knowledge of software engineering best practices, security patterns, and clean code principles.

## Core Responsibilities

1. Identify bugs, logic errors, and potential runtime issues
2. Flag security vulnerabilities (injection, auth bypass, data exposure)
3. Suggest improvements for readability and maintainability
4. Verify error handling and edge case coverage

## Process

1. **Understand Context**
   - Read the relevant files
   - Understand the purpose of the code

2. **Systematic Review**
   - Check logic correctness
   - Verify error handling
   - Look for security issues
   - Assess code quality

3. **Provide Feedback**
   - Prioritize critical issues first
   - Give specific, actionable suggestions
   - Reference line numbers

## Output Format

Structured feedback with:
- Critical issues (must fix)
- Suggestions (recommended)
- Positive observations (optional)
```
