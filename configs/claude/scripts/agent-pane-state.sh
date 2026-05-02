#!/bin/bash
# ADR: 063
# Purpose: ペインごとの agent ランタイム状態を /tmp/agent-pane-state/ に書き出す（Claude Code / Codex CLI 共通、ADR-007 から汎用化）
# Hook: ペインごとのランタイム状態をファイルに書き出す（Claude Code / Codex CLI 共通）
# 使い方: agent-pane-state.sh <state> <agent> [source]
#   state:  running | permission | ask | idle | end
#   agent:  claude | codex
#   source: post (PostToolUse 経由の場合のみ指定)
#
# 状態ファイル形式:
#   pane_N の 1 行目 = state、2 行目 = agent 種別

INPUT=$(cat)

[ -z "$TMUX_PANE" ] && exit 0

STATE_DIR="/tmp/agent-pane-state"
PANE_NUM="${TMUX_PANE#%}"
PANE_FILE="$STATE_DIR/pane_${PANE_NUM}"
STARTED_FILE="$STATE_DIR/pane_${PANE_NUM}_started"
SESSION_ID_FILE="$STATE_DIR/pane_${PANE_NUM}_session_id"
STATE="${1:-unknown}"
AGENT="${2:-}"
SOURCE="${3:-}"

# agent 種別の検証（claude / codex のみ受理）
case "$AGENT" in
    claude|codex) ;;
    *) AGENT="" ;;
esac

if command -v jq >/dev/null 2>&1 && [ -n "$INPUT" ]; then
    SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
    if [ -n "$SID" ]; then
        mkdir -p "$STATE_DIR"
        printf '%s' "$SID" > "$SESSION_ID_FILE"
    fi
fi

if [ "$STATE" = "end" ]; then
    rm -f "$PANE_FILE" "$STARTED_FILE" "$SESSION_ID_FILE"
    exit 0
fi

# PostToolUse 経由の running 設定時、直近（5秒以内）の高優先度状態を保護
#   - permission/ask: 並列ツール完了による上書きを防止
#   - idle: Stop 直後の PostToolUse による上書きを防止
if [ "$STATE" = "running" ] && [ "$SOURCE" = "post" ] && [ -f "$PANE_FILE" ]; then
    current=$(head -n 1 "$PANE_FILE")
    if [ "$current" = "permission" ] || [ "$current" = "ask" ] || [ "$current" = "idle" ]; then
        file_mtime=$(stat -f %m "$PANE_FILE" 2>/dev/null || echo 0)
        current_time=$(date +%s)
        age=$((current_time - file_mtime))
        if [ "$age" -lt 5 ]; then
            exit 0
        fi
    fi
fi

# タイムスタンプ管理: running 開始時に記録、それ以外で削除
if [ "$STATE" = "running" ]; then
    prev_state=$(head -n 1 "$PANE_FILE" 2>/dev/null)
    if [ -z "$SOURCE" ] || [ ! -f "$STARTED_FILE" ] || \
       [ "$prev_state" = "permission" ] || [ "$prev_state" = "ask" ]; then
        mkdir -p "$STATE_DIR"
        date +%s > "$STARTED_FILE"
    fi
elif [ "$STATE" = "idle" ] || [ "$STATE" = "end" ]; then
    rm -f "$STARTED_FILE"
fi

mkdir -p "$STATE_DIR"
printf '%s\n%s\n' "$STATE" "$AGENT" > "$PANE_FILE"
