#!/usr/bin/env bash
# tmux-send-prompt.sh - tmux pane への安全なプロンプト送信
#
# Usage:
#   tmux-send-prompt.sh gather "<args>"           # 引数解析・候補収集・可能なら送信
#   tmux-send-prompt.sh send "<target>" "<prompt>" # 状態確認して送信
#
# gather の出力フォーマット:
#   STATUS: SENT|ERROR|NEED_PROMPT|NEED_TARGET|NEED_BOTH
#   TARGET: <target>        (SENT / NEED_PROMPT 時)
#   PROMPT: <prompt>        (SENT / NEED_TARGET 時)
#   MESSAGE: <msg>          (ERROR 時)
#   CANDIDATES:             (NEED_TARGET / NEED_BOTH 時の後続行)
#   <addr> [state=<state>]  (idle 候補のみ、1行1件)

set -uo pipefail

STATE_DIR="/tmp/agent-pane-state"

# ---------- ユーティリティ ----------

# pane の state を返す（idle / running / ask / permission / busy）
get_pane_state() {
  local pane_id="$1" pane_pid="$2"
  local pane_num state
  pane_num="${pane_id#%}"
  state=$(cat "${STATE_DIR}/pane_${pane_num}" 2>/dev/null || true)
  if [ -n "$state" ]; then
    printf '%s' "$state"
  elif pgrep -P "$pane_pid" > /dev/null 2>&1; then
    printf 'busy'
  else
    printf 'idle'
  fi
}

# 状態確認して送信（共通処理）
check_and_send() {
  local target="$1" prompt="$2"
  local pane_id pane_pid state

  pane_id=$(tmux display-message -t "$target" -p '#{pane_id}' 2>/dev/null) || {
    printf 'STATUS: ERROR\nMESSAGE: ターゲット "%s" が見つかりません\n' "$target"
    return
  }
  pane_pid=$(tmux display-message -t "$target" -p '#{pane_pid}' 2>/dev/null)
  state=$(get_pane_state "$pane_id" "$pane_pid")

  case "$state" in
    idle)
      tmux send-keys -t "$target" "$prompt" Enter
      printf 'STATUS: SENT\nTARGET: %s\nPROMPT: %s\n' "$target" "$prompt"
      ;;
    running)
      printf 'STATUS: ERROR\nMESSAGE: 現在処理中です（state=running）。完了後に再試行してください。\n'
      ;;
    ask)
      printf 'STATUS: ERROR\nMESSAGE: 入力待ち状態です（state=ask）。手動で操作してください。\n'
      ;;
    permission)
      printf 'STATUS: ERROR\nMESSAGE: 権限確認待ち状態です（state=permission）。手動で操作してください。\n'
      ;;
    busy)
      printf 'STATUS: ERROR\nMESSAGE: 子プロセスが動作中の可能性があります。完了後に再試行してください。\n'
      ;;
  esac
}

# ---------- gather モード ----------

mode_gather() {
  local args="$1"

  # セッション一覧取得
  local sessions
  sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null) || {
    printf 'STATUS: ERROR\nMESSAGE: tmux セッションが見つかりません\n'
    return
  }

  # 自身の pane を除いた claude/codex pane 一覧
  local my_pane candidates
  my_pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null)
  candidates=$(
    tmux list-panes -a \
      -F '#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{pane_pid} #{pane_current_command}' \
      2>/dev/null \
      | grep -v "^${my_pane} " \
      | grep -E ' (claude|codex)$' || true
  )

  if [ -z "$candidates" ]; then
    printf 'STATUS: ERROR\nMESSAGE: 利用可能なpane（claude/codex）がありません\n'
    return
  fi

  # ---------- 引数パース ----------
  local target_session="" target_window="" target_pane="" prompt=""

  if [ -n "$args" ]; then
    local first_token rest
    first_token="${args%% *}"
    rest="${args#* }"
    [ "$rest" = "$args" ] && rest=""   # スペースなし → rest は空

    # | を : に正規化
    local norm_token
    norm_token=$(printf '%s' "$first_token" | tr '|' ':')

    # セッション名に前方一致するか確認
    local matched=false session
    while IFS= read -r session; do
      if [ "$norm_token" = "$session" ] || \
         [ "${norm_token#${session}:}" != "$norm_token" ]; then
        matched=true
        local after="${norm_token#${session}}"
        after="${after#:}"
        if [ "${after}" != "${after%.*}" ]; then
          # session:window.pane
          target_session="$session"
          target_window="${after%%.*}"
          target_pane="${after#*.}"
        elif [ -n "$after" ]; then
          # session:window
          target_session="$session"
          target_window="$after"
        else
          # session のみ
          target_session="$session"
        fi
        prompt="$rest"
        break
      fi
    done <<< "$sessions"

    if [ "$matched" = false ]; then
      prompt="$args"
    fi
  fi

  # ---------- 候補フィルタリング ----------
  local filtered="$candidates"

  if [ -n "$target_session" ]; then
    filtered=$(printf '%s\n' "$filtered" | grep " ${target_session}:" || true)
  fi
  if [ -n "$target_session" ] && [ -n "$target_window" ]; then
    filtered=$(printf '%s\n' "$filtered" | grep " ${target_session}:${target_window}\." || true)
  fi

  if [ -z "$filtered" ]; then
    printf 'STATUS: ERROR\nMESSAGE: 指定されたターゲットが見つかりません\n'
    return
  fi

  # ---------- 完全指定の場合 ----------
  if [ -n "$target_session" ] && [ -n "$target_window" ] && [ -n "$target_pane" ]; then
    local full_target="${target_session}:${target_window}.${target_pane}"
    if [ -n "$prompt" ]; then
      check_and_send "$full_target" "$prompt"
    else
      printf 'STATUS: NEED_PROMPT\nTARGET: %s\n' "$full_target"
    fi
    return
  fi

  # ---------- 候補が1件の場合 ----------
  local candidate_count
  candidate_count=$(printf '%s\n' "$filtered" | grep -c . || true)

  if [ "$candidate_count" -eq 1 ]; then
    local single_addr
    single_addr=$(printf '%s\n' "$filtered" | awk '{print $2}')
    if [ -n "$prompt" ]; then
      check_and_send "$single_addr" "$prompt"
    else
      printf 'STATUS: NEED_PROMPT\nTARGET: %s\n' "$single_addr"
    fi
    return
  fi

  # ---------- 複数候補 → 選択が必要 ----------
  # idle な候補のみ列挙（最大4件）
  local idle_list="" idle_count=0
  while IFS= read -r row; do
    local pane_id pane_addr pane_pid state
    pane_id=$(printf '%s' "$row" | awk '{print $1}')
    pane_addr=$(printf '%s' "$row" | awk '{print $2}')
    pane_pid=$(printf '%s' "$row" | awk '{print $3}')
    state=$(get_pane_state "$pane_id" "$pane_pid")
    if [ "$state" = "idle" ]; then
      idle_list="${idle_list}${pane_addr} [state=idle]\n"
      idle_count=$((idle_count + 1))
      [ "$idle_count" -ge 4 ] && break
    fi
  done <<< "$filtered"

  if [ -z "$idle_list" ]; then
    printf 'STATUS: ERROR\nMESSAGE: 利用可能なpane（idle状態）がありません\n'
    return
  fi

  if [ -n "$prompt" ]; then
    printf 'STATUS: NEED_TARGET\nPROMPT: %s\nCANDIDATES:\n' "$prompt"
  else
    printf 'STATUS: NEED_BOTH\nCANDIDATES:\n'
  fi
  printf '%b' "$idle_list"
}

# ---------- send モード ----------

mode_send() {
  local target="${1:-}" prompt="${2:-}"
  if [ -z "$target" ] || [ -z "$prompt" ]; then
    printf 'STATUS: ERROR\nMESSAGE: send モードには target と prompt が必要です\n'
    return
  fi
  check_and_send "$target" "$prompt"
}

# ---------- エントリーポイント ----------

MODE="${1:-gather}"
shift || true

case "$MODE" in
  gather) mode_gather "${1:-}" ;;
  send)   mode_send   "${1:-}" "${2:-}" ;;
  *)
    printf 'STATUS: ERROR\nMESSAGE: 不明なモード: %s\n' "$MODE"
    exit 1
    ;;
esac
