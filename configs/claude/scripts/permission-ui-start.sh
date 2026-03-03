#!/bin/bash
# permission-ui-server.py をバックグラウンドで起動する
# 既に起動中なら何もしない

PID_FILE="$HOME/.claude/logs/permission-ui-server.pid"
PORT=18765

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Already running (PID: $(cat "$PID_FILE")) → http://localhost:$PORT"
  exit 0
fi

mkdir -p "$HOME/.claude/logs"

nohup python3 ~/.claude/scripts/permission-ui-server.py \
  >> ~/.claude/logs/permission-ui-server.log 2>&1 &

echo $! > "$PID_FILE"
echo "Started (PID: $!) → http://localhost:$PORT"
