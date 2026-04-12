#!/bin/bash
set -euo pipefail

# UserPromptSubmit hook: detect skill name from prompt and write active-skill marker.
# If the prompt starts with a skill name registered in ~/.workflow-sessions/config.json
# auto_log (object format), writes ~/.workflow-sessions/active-skill-<session_id>.json.

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty')

if [[ -z "$SESSION_ID" || -z "$PROMPT" ]]; then
    exit 0
fi

CONFIG_FILE="$HOME/.workflow-sessions/config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi

# auto_log must be an object: {"skill_name": {"log_dir": "..."}, ...}
AUTO_LOG_TYPE=$(jq -r '.auto_log | type' "$CONFIG_FILE" 2>/dev/null || echo "null")
if [[ "$AUTO_LOG_TYPE" != "object" ]]; then
    exit 0
fi

# Find first matching skill name: prompt must start with /<skill_name> (+ space or end)
MATCHED_SKILL=$(jq -r --arg p "$PROMPT" '
    .auto_log | to_entries[] | .key as $k |
    select($p | test("^/" + $k + "( |$)")) |
    $k' "$CONFIG_FILE" 2>/dev/null | head -1)

if [[ -z "$MATCHED_SKILL" ]]; then
    exit 0
fi

LOG_CONFIG=$(jq -c --arg skill "$MATCHED_SKILL" '.auto_log[$skill]' "$CONFIG_FILE")

mkdir -p "$HOME/.workflow-sessions"
printf '%s' "$LOG_CONFIG" | jq --arg skill "$MATCHED_SKILL" '. + {"skill": $skill}' \
    > "$HOME/.workflow-sessions/active-skill-${SESSION_ID}.json"

exit 0
