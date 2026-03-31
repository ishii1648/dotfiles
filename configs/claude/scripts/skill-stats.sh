#!/bin/bash
# Skill 呼び出し回数集計スクリプト
# ~/.claude/skill-metrics/counts.jsonl を読み込み、スキル別呼び出し回数を降順表示する

COUNTS_FILE="$HOME/.claude/skill-metrics/counts.jsonl"

if [ ! -f "$COUNTS_FILE" ]; then
    echo "No skill metrics found: $COUNTS_FILE"
    exit 0
fi

echo "Skill call counts:"
echo "-----------------------------"
jq -r '.skill' "$COUNTS_FILE" \
    | sort \
    | uniq -c \
    | sort -rn \
    | awk '{printf "%5d  %s\n", $1, $2}'
echo "-----------------------------"
total=$(wc -l < "$COUNTS_FILE")
printf "Total: %d calls\n" "$total"
