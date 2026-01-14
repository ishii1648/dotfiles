#!/bin/bash

# Stop hook: worktree の settings.local.json を親リポジトリに同期する
# Claudeの応答完了時に毎回発火

# worktree でない場合は何もしない
if [ ! -f ".git" ]; then
    echo "[Stop Hook] Not in worktree, skipping sync" >&2
    exit 0
fi

# 親リポジトリのパスを取得
GITDIR=$(cat .git | sed 's/gitdir: //')
# .git ディレクトリのパスを取得してから、その親ディレクトリ（メインリポジトリ）を取得
GIT_DIR=$(dirname "$(dirname "$GITDIR")")
MAIN_WORKTREE=$(dirname "$GIT_DIR")

# settings.local.json が存在する場合のみ同期
SETTINGS_FILE=".claude/settings.local.json"
if [ -f "$SETTINGS_FILE" ]; then
    echo "[Stop Hook] Syncing settings.local.json..." >&2
    mkdir -p "$MAIN_WORKTREE/.claude"
    if command cp -f "$SETTINGS_FILE" "$MAIN_WORKTREE/.claude/settings.local.json"; then
        echo "[Stop Hook] ✓ Synced to $MAIN_WORKTREE/.claude/settings.local.json" >&2
    else
        echo "[Stop Hook] ✗ Failed to sync settings.local.json" >&2
        exit 1
    fi
else
    echo "[Stop Hook] No settings.local.json found, skipping sync" >&2
fi
