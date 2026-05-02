#!/bin/bash
# ADR: -
# Purpose: PostToolUse(Skill) で Skill 呼び出しを ~/.claude/skill-metrics/counts.jsonl にカウント記録（メトリクス用）
# Claude Code Hook: Skill ツール呼び出しをカウントする PostToolUse フック
# ~/.claude/skill-metrics/counts.jsonl に JSONL 形式で追記する

set -euo pipefail

METRICS_DIR="$HOME/.claude/skill-metrics"
COUNTS_FILE="$METRICS_DIR/counts.jsonl"

input=$(cat)

skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // empty')

if [ -z "$skill" ]; then
    exit 0
fi

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$METRICS_DIR"
printf '{"skill":"%s","timestamp":"%s"}\n' "$skill" "$timestamp" >> "$COUNTS_FILE"
