#!/bin/bash
# permission-ui-server.py を管理する
# 使い方: permission-ui-start.sh [start|stop|restart|help]

PID_FILE="$HOME/.claude/logs/permission-ui-server.pid"
PORT=18765

is_running() {
  [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

do_start() {
  if is_running; then
    echo "Already running (PID: $(cat "$PID_FILE")) → http://localhost:$PORT"
    exit 0
  fi
  mkdir -p "$HOME/.claude/logs"
  nohup python3 ~/.claude/scripts/permission-ui-server.py \
    >> ~/.claude/logs/permission-ui-server.log 2>&1 &
  echo $! > "$PID_FILE"
  echo "Started (PID: $!) → http://localhost:$PORT"
}

do_stop() {
  if ! is_running; then
    echo "Not running"
    exit 0
  fi
  kill "$(cat "$PID_FILE")" && rm -f "$PID_FILE"
  echo "Stopped"
}

do_help() {
  cat <<EOF
Usage: $(basename "$0") [start|stop|restart|help]

  start    起動（デフォルト。既に起動中なら何もしない）
  stop     停止
  restart  停止してから起動
  help     このヘルプを表示

Dashboard: http://localhost:$PORT
PID file:  $PID_FILE
Log file:  $HOME/.claude/logs/permission-ui-server.log
EOF
}

case "${1:-start}" in
  start)   do_start ;;
  stop)    do_stop ;;
  restart) do_stop; do_start ;;
  help)    do_help ;;
  *)       echo "Unknown command: $1"; do_help; exit 1 ;;
esac
