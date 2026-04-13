#!/bin/bash
# Claude Code Hook: ペインごとのランタイム状態をファイルに書き出す
# 使い方: claude-pane-state.sh <state> [source]
#   state:  running | permission | ask | idle | end
#   source: post (PostToolUse 経由の場合のみ指定)

# stdin を読み取り（session_id 抽出用に保持）
INPUT=$(cat)

# tmux 外では何もしない
[ -z "$TMUX_PANE" ] && exit 0

STATE_DIR="/tmp/claude-pane-state"
PANE_NUM="${TMUX_PANE#%}"
PANE_FILE="$STATE_DIR/pane_${PANE_NUM}"
STARTED_FILE="$STATE_DIR/pane_${PANE_NUM}_started"
SESSION_ID_FILE="$STATE_DIR/pane_${PANE_NUM}_session_id"
STATE="${1:-unknown}"
SOURCE="${2:-}"

# stdin JSON から session_id を抽出して書き出す
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
# UserPromptSubmit 経由（SOURCE 未指定）はガードなしで常に設定
if [ "$STATE" = "running" ] && [ "$SOURCE" = "post" ] && [ -f "$PANE_FILE" ]; then
    current=$(cat "$PANE_FILE")
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
    # UserPromptSubmit (SOURCE空) → 常にリセット
    # PostToolUse (SOURCE=post) + _started なし → 作成
    # PostToolUse (SOURCE=post) + 直前が permission/ask → リセット（許可後の再開）
    prev_state=$(cat "$PANE_FILE" 2>/dev/null)
    if [ -z "$SOURCE" ] || [ ! -f "$STARTED_FILE" ] || \
       [ "$prev_state" = "permission" ] || [ "$prev_state" = "ask" ]; then
        mkdir -p "$STATE_DIR"
        date +%s > "$STARTED_FILE"
    fi
elif [ "$STATE" = "idle" ] || [ "$STATE" = "end" ]; then
    rm -f "$STARTED_FILE"
fi

mkdir -p "$STATE_DIR"
echo "$STATE" > "$PANE_FILE"
