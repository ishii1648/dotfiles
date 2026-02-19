#!/bin/bash
# Claude Code Hook: SessionStart でセッションインデックスを記録する
# 出力先: ~/.claude/session-index.jsonl

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
TRANSCRIPT=$(echo "$INPUT"  | jq -r '.transcript_path // ""')
CWD=$(echo "$INPUT"         | jq -r '.cwd // ""')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# git リポジトリ情報を取得（非 git ディレクトリでは空文字）
REPO=""
BRANCH=""
if git -C "$CWD" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    REMOTE_URL=$(git -C "$CWD" remote get-url origin 2>/dev/null || echo "")
    if [ -n "$REMOTE_URL" ]; then
        # SSH: git@github.com:ORG/REPO.git  HTTPS: https://github.com/ORG/REPO.git
        REPO=$(echo "$REMOTE_URL" | sed -E 's|.*[:/]([^/]+/[^/]+)(\.git)?$|\1|')
    else
        # リモートなしの場合は ghq パス構造から推測: ~/ghq/<host>/<org>/<repo>
        TOPLEVEL=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "")
        REPO=$(echo "$TOPLEVEL" | sed -E 's|.*/([^/]+/[^/@]+)(@.*)?$|\1|')
    fi
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "")
fi

INDEX_FILE="$HOME/.claude/session-index.jsonl"
echo "{\"timestamp\": \"$TIMESTAMP\", \"session_id\": \"$SESSION_ID\", \"cwd\": \"$CWD\", \"repo\": \"$REPO\", \"branch\": \"$BRANCH\", \"transcript\": \"$TRANSCRIPT\"}" >> "$INDEX_FILE"
