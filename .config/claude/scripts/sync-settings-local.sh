#!/bin/bash

# Stop hook: worktree の settings.local.json を親リポジトリに同期する
# Claudeの応答完了時に毎回発火

# worktree でない場合は何もしない
if [ ! -f ".git" ]; then
    exit 0
fi

# 親リポジトリのパスを取得
GITDIR=$(cat .git | sed 's/gitdir: //')
MAIN_WORKTREE=$(dirname "$(dirname "$GITDIR")")

# settings.local.json が存在する場合のみ同期
SETTINGS_FILE=".claude/settings.local.json"
if [ -f "$SETTINGS_FILE" ]; then
    mkdir -p "$MAIN_WORKTREE/.claude"
    command cp -f "$SETTINGS_FILE" "$MAIN_WORKTREE/.claude/settings.local.json"
fi
