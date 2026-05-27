#!/usr/bin/env bash
# ADR: 070
# Purpose: claude(実装役) と codex(レビュー役) を tmux wait-for で交互駆動する反復レビューループのコーディネータ
#
# サブコマンド:
#   launch <repo_root> --session-id <id> --task-file <path> [--max-rounds N] [--base <ref>] [--inherit-size]
#   cleanup <session-id>
#   selftest                       # 純粋ロジック(終了判定/プロンプト生成/引数パース)の自己テスト
#
# 設計: ADR-070
#   - claude(実装役): round1 は `claude --session-id <uuid> < prompt`、round2 以降は
#     `claude --resume <uuid> < prompt` で interactive 起動（subscription 課金、`-p` 不使用）。
#     stdin EOF で claude が終了 → `tmux wait-for -S <signal>` が完了を通知する。
#   - codex(レビュー役): 各ラウンド stateless な `codex exec -s read-only - < prompt` で
#     現在の作業ツリー差分をレビュー。前回指摘はプロンプトに同梱する（resume フラグ非依存）。
#   - コーディネータ(advance_loop): バックグラウンドで `tmux wait-for` をゼロコスト待機し、
#     claude→codex→(収束判定)→claude... を回す。codex 承認 or 最大ラウンドで終了。

set -euo pipefail

REVIEW_LOOP_DIR="${REVIEW_LOOP_DIR:-$HOME/.review-loop}"

die() {
  echo "STATUS: ERROR"
  echo "MESSAGE: $1"
  tmux display-message -d 5000 "review-loop: ERROR: $1" 2>/dev/null || true
  exit 1
}

# ============================================================
# 純粋ロジック（selftest 対象 — 副作用なし）
# ============================================================

# codex の出力ファイルからレビュー収束を判定する。
# 最後に出現した `REVIEW_RESULT:` 行が APPROVED なら収束（exit 0）、それ以外は未収束（exit 1）。
rl_review_converged() {
  local out_file="$1"
  [ -f "$out_file" ] || return 1
  local verdict
  verdict=$( { grep -oiE 'REVIEW_RESULT:[[:space:]]*(APPROVED|CHANGES_REQUESTED)' "$out_file" 2>/dev/null \
    | tail -n 1 | grep -oiE '(APPROVED|CHANGES_REQUESTED)' | tr '[:lower:]' '[:upper:]'; } || true)
  [ "$verdict" = "APPROVED" ]
}

# codex レビュー役へのプロンプトを stdout に生成する。
# $1: round, $2: base_ref, $3: 前ラウンドの指摘ファイル（空可）
rl_build_codex_prompt() {
  local round="$1" base_ref="$2" prev_findings="${3:-}"
  cat <<EOF
あなたはコードレビュー担当です。このリポジトリの現在のブランチに加えられた変更をレビューしてください。

- 変更全体を把握するには次を実行してください: \`git diff ${base_ref}...HEAD\` および \`git status\` / \`git diff\`（未コミットの作業ツリー変更も対象に含める）
- バグ・正しさの問題・抜けたエッジケース・既存コードとの不整合を優先して指摘してください
- 各指摘は「ファイル:行 — 問題 — 推奨対応」の形式で具体的に書いてください
- スタイルの好みではなく、修正すべき実質的な問題に絞ってください
EOF
  if [ -n "$prev_findings" ] && [ -f "$prev_findings" ]; then
    cat <<EOF

これは round ${round} の再レビューです。前回(round $((round - 1)))あなたが出した指摘は以下です。実装役がこれらに対応済みか確認し、未対応・新規の問題のみを今回の指摘として挙げてください:

--- 前回の指摘 ---
$(cat "$prev_findings")
--- 前回の指摘ここまで ---
EOF
  fi
  cat <<'EOF'

出力の最終行に、レビュー結果を必ず次のいずれかで明記してください（この行で収束を判定します）:
  REVIEW_RESULT: APPROVED            （修正すべき実質的な問題が残っていない）
  REVIEW_RESULT: CHANGES_REQUESTED   （対応すべき指摘が残っている）
EOF
}

# claude 実装役へのプロンプトを stdout に生成する。
# $1: round, $2: タスクファイル, $3: codex 指摘ファイル（round1 では空）
rl_build_claude_prompt() {
  local round="$1" task_file="$2" codex_findings="${3:-}"
  if [ "$round" -eq 1 ] || [ -z "$codex_findings" ]; then
    cat <<EOF
以下のタスクを実装してください。完了したらそのまま終了してください（追加の指示は待たないでください）。

--- タスク ---
$(cat "$task_file")
--- タスクここまで ---
EOF
  else
    cat <<EOF
codex によるレビュー(round $((round - 1)))で以下の指摘がありました。妥当な指摘に対応してコードを修正してください。対応が完了したらそのまま終了してください（追加の指示は待たないでください）。指摘に同意できない場合は対応せず、その理由を簡潔に述べてください。

--- codex の指摘 ---
$(cat "$codex_findings")
--- 指摘ここまで ---
EOF
  fi
}

# base ref を解決する（origin/HEAD → main → master）。
rl_resolve_base_ref() {
  local repo="$1"
  local base
  base=$(git -C "$repo" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/||')
  if [ -n "$base" ]; then echo "$base"; return; fi
  if git -C "$repo" show-ref --verify --quiet refs/heads/main 2>/dev/null; then echo "main"; return; fi
  if git -C "$repo" show-ref --verify --quiet refs/heads/master 2>/dev/null; then echo "master"; return; fi
  echo "HEAD~1"
}

# ============================================================
# manifest
# ============================================================

manifest_path() { echo "$REVIEW_LOOP_DIR/$1/manifest.json"; }

write_manifest() {
  local session_id="$1" repo_root="$2" work_dir="$3" claude_sid="$4" max_rounds="$5" base_ref="$6" tmux_session="$7"
  local dir="$REVIEW_LOOP_DIR/$session_id"
  mkdir -p "$dir"
  jq -n \
    --arg sid "$session_id" \
    --arg repo "$repo_root" \
    --arg wd "$work_dir" \
    --arg csid "$claude_sid" \
    --argjson mr "$max_rounds" \
    --arg base "$base_ref" \
    --arg ts "$tmux_session" \
    '{session_id:$sid, repo_root:$repo, work_dir:$wd, claude_session_id:$csid,
      max_rounds:$mr, base_ref:$base, tmux_session:$ts,
      state:"launched", result:null, rounds:[], advance_pid:null,
      created_at:(now|todate)}' \
    > "$(manifest_path "$session_id")"
}

update_manifest() {
  local session_id="$1" filter="$2"
  local mf; mf=$(manifest_path "$session_id")
  [ -f "$mf" ] || return 0
  local tmp; tmp=$(mktemp)
  if jq "$filter" "$mf" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$mf"
  else
    rm -f "$tmp"
  fi
}

# ============================================================
# エージェント起動
# ============================================================

# claude(実装役)を起動する。round1 は --session-id で UUID 固定、以降は --resume。
launch_claude() {
  local tmux_session="$1" work_dir="$2" prompt_file="$3" signal="$4" claude_sid="$5" round="$6"
  local claude_cmd
  if [ "$round" -eq 1 ]; then
    claude_cmd="claude --session-id '$claude_sid' < '$prompt_file'"
  else
    claude_cmd="claude --resume '$claude_sid' < '$prompt_file'"
  fi
  sleep 0.3
  tmux send-keys -t "=${tmux_session}:claude" \
    "cd '$work_dir'; $claude_cmd; tmux wait-for -S '$signal'" Enter
}

# codex(レビュー役)を headless 起動する。stateless（毎回 fresh exec、read-only sandbox）。
launch_codex() {
  local tmux_session="$1" work_dir="$2" prompt_file="$3" out_file="$4" signal="$5"
  # codex window を必要なら作成
  if ! tmux list-windows -t "=${tmux_session}" -F '#{window_name}' 2>/dev/null | grep -qx codex; then
    tmux new-window -t "=${tmux_session}:" -n codex -c "$work_dir" -d \
      || die "codex window の作成に失敗しました"
    tmux set-option -t "=${tmux_session}:codex" allow-rename off 2>/dev/null || true
  fi
  sleep 0.3
  # codex exec は非対話で stdin からプロンプトを読み、終了する（TUI ではないため ADR-065 の OSC11 待機は不要）
  tmux send-keys -t "=${tmux_session}:codex" \
    "cd '$work_dir'; codex exec -C '$work_dir' -s read-only - < '$prompt_file' > '$out_file' 2>&1; tmux wait-for -S '$signal'" Enter
}

# ============================================================
# advance ループ（バックグラウンド・循環）
# ============================================================

advance_loop() {
  local session_id="$1" tmux_session="$2" work_dir="$3" claude_sid="$4" max_rounds="$5" base_ref="$6" task_file="$7" out_dir="$8"

  local result="exhausted"
  local round=1
  while [ "$round" -le "$max_rounds" ]; do
    # 1. claude(実装/反映)の完了を待つ
    tmux wait-for "rl-done-${session_id}-claude-${round}" 2>/dev/null || true
    update_manifest "$session_id" \
      ".rounds += [{round:$round, claude_done_at:(now|todate)}]"

    # 2. codex レビューを起動
    local codex_out="$out_dir/round-${round}-codex.md"
    local codex_prompt="$out_dir/round-${round}-codex-prompt.txt"
    local prev_findings=""
    [ "$round" -gt 1 ] && prev_findings="$out_dir/round-$((round - 1))-codex.md"
    rl_build_codex_prompt "$round" "$base_ref" "$prev_findings" > "$codex_prompt"
    launch_codex "$tmux_session" "$work_dir" "$codex_prompt" "$codex_out" \
      "rl-done-${session_id}-codex-${round}"

    # 3. codex 完了を待つ
    tmux wait-for "rl-done-${session_id}-codex-${round}" 2>/dev/null || true

    # 4. 収束判定
    if rl_review_converged "$codex_out"; then
      result="converged"
      update_manifest "$session_id" \
        "(.rounds[-1].codex_done_at) = (now|todate) | (.rounds[-1].verdict) = \"APPROVED\""
      break
    fi
    update_manifest "$session_id" \
      "(.rounds[-1].codex_done_at) = (now|todate) | (.rounds[-1].verdict) = \"CHANGES_REQUESTED\""

    # 5. 最大ラウンド到達なら打ち切り
    if [ "$round" -eq "$max_rounds" ]; then
      result="exhausted"
      break
    fi

    # 6. 次ラウンド: claude に指摘を渡して反映させる
    round=$((round + 1))
    local claude_prompt="$out_dir/round-${round}-claude-prompt.txt"
    rl_build_claude_prompt "$round" "$task_file" "$codex_out" > "$claude_prompt"
    launch_claude "$tmux_session" "$work_dir" "$claude_prompt" \
      "rl-done-${session_id}-claude-${round}" "$claude_sid" "$round"
  done

  # 最終サマリ
  local summary="$out_dir/SUMMARY.md"
  {
    echo "# review-loop summary"
    echo
    echo "- session-id: $session_id"
    echo "- result: $result"
    echo "- rounds executed: $round / $max_rounds"
    echo "- base ref: $base_ref"
    echo
    if [ "$result" = "converged" ]; then
      echo "codex が round $round で APPROVED。レビューループは収束しました。"
    else
      echo "最大ラウンド($max_rounds)に達しても codex の APPROVED が得られませんでした。残課題は round-${round}-codex.md を参照してください。"
    fi
  } > "$summary"
  update_manifest "$session_id" \
    ".state = \"complete\" | .result = \"$result\" | .rounds_executed = $round | .summary = \"$summary\""
  tmux display-message -d 8000 "review-loop: $result (round $round/$max_rounds) [$session_id]" 2>/dev/null || true
}

# ============================================================
# サブコマンド: launch
# ============================================================

cmd_launch() {
  local repo_root="" session_id="" task_file="" max_rounds=3 base_ref="" inherit_size=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --session-id) session_id="$2"; shift 2 ;;
      --task-file)  task_file="$2"; shift 2 ;;
      --max-rounds) max_rounds="$2"; shift 2 ;;
      --base)       base_ref="$2"; shift 2 ;;
      --inherit-size) inherit_size=true; shift ;;
      *) if [ -z "$repo_root" ]; then repo_root="$1"; fi; shift ;;
    esac
  done

  [ -z "$repo_root" ]  && die "repo-root が指定されていません"
  [ -z "$session_id" ] && die "--session-id が指定されていません"
  [ -z "$task_file" ]  && die "--task-file が指定されていません"
  [ ! -d "$repo_root" ] && die "リポジトリが見つかりません: $repo_root"
  [ ! -f "$task_file" ] && die "タスクファイルが見つかりません: $task_file"
  case "$max_rounds" in (''|*[!0-9]*) die "--max-rounds は整数で指定してください: $max_rounds" ;; esac
  [ "$max_rounds" -lt 1 ] && die "--max-rounds は 1 以上で指定してください"

  command -v jq >/dev/null 2>&1 || die "jq が利用できません"
  command -v codex >/dev/null 2>&1 || die "codex が利用できません"
  if ! tmux display-message -p '#{session_name}' >/dev/null 2>&1; then
    die "tmux セッション外では動作しません"
  fi
  git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1 || die "git リポジトリではありません: $repo_root"

  # work_dir は現在の worktree（レビュー対象ブランチ）。新規 worktree は作らない。
  local work_dir="$repo_root"
  [ -z "$base_ref" ] && base_ref=$(rl_resolve_base_ref "$work_dir")

  # claude セッション ID（UUID）を固定生成 → round1 で --session-id、以降 --resume
  local claude_sid
  claude_sid=$(uuidgen | tr '[:upper:]' '[:lower:]')

  local out_dir="$work_dir/.outputs/claude/review-loop/$session_id"
  mkdir -p "$out_dir"

  # tmux セッション作成（claude window）
  local tmux_session="review-loop-$session_id"
  local tmux_opts=(-d -s "$tmux_session" -n claude -c "$work_dir")
  if [ "$inherit_size" = true ]; then
    local w h
    w=$(tmux display-message -p '#{window_width}' 2>/dev/null || echo 200)
    h=$(tmux display-message -p '#{window_height}' 2>/dev/null || echo 50)
    tmux_opts+=(-x "$w" -y "$h")
  fi
  tmux new-session "${tmux_opts[@]}" || die "tmux セッションの作成に失敗しました: $tmux_session"
  tmux set-option -t "=${tmux_session}:claude" allow-rename off 2>/dev/null || true

  write_manifest "$session_id" "$repo_root" "$work_dir" "$claude_sid" "$max_rounds" "$base_ref" "$tmux_session"

  # round1: claude にタスクを実装させる
  local claude_prompt="$out_dir/round-1-claude-prompt.txt"
  rl_build_claude_prompt 1 "$task_file" "" > "$claude_prompt"
  launch_claude "$tmux_session" "$work_dir" "$claude_prompt" \
    "rl-done-${session_id}-claude-1" "$claude_sid" 1

  # advance ループをバックグラウンド起動
  advance_loop "$session_id" "$tmux_session" "$work_dir" "$claude_sid" \
    "$max_rounds" "$base_ref" "$task_file" "$out_dir" &
  local advance_pid=$!
  disown "$advance_pid"
  update_manifest "$session_id" ".advance_pid = $advance_pid"

  echo "STATUS: LAUNCHED"
  echo "SESSION_ID: $session_id"
  echo "TMUX_SESSION: $tmux_session"
  echo "WORK_DIR: $work_dir"
  echo "BASE_REF: $base_ref"
  echo "MAX_ROUNDS: $max_rounds"
  echo "CLAUDE_SESSION_ID: $claude_sid"
  echo "OUT_DIR: $out_dir"
  echo "MANIFEST: $(manifest_path "$session_id")"
  tmux display-message -d 5000 "review-loop: launched [$session_id]" 2>/dev/null || true
}

# ============================================================
# サブコマンド: cleanup
# ============================================================

cmd_cleanup() {
  local session_id="${1:-}"
  [ -z "$session_id" ] && die "session-id が指定されていません"
  local mf; mf=$(manifest_path "$session_id")
  [ -f "$mf" ] || die "マニフェストが見つかりません: $mf"

  local deleted=()

  local advance_pid
  advance_pid=$(jq -r '.advance_pid // empty' "$mf" 2>/dev/null || true)
  if [ -n "$advance_pid" ] && kill -0 "$advance_pid" 2>/dev/null; then
    kill "$advance_pid" 2>/dev/null || true
    deleted+=("advance_loop:$advance_pid")
  fi

  local tmux_session
  tmux_session=$(jq -r '.tmux_session // empty' "$mf" 2>/dev/null || true)
  if [ -n "$tmux_session" ] && tmux has-session -t "=$tmux_session" 2>/dev/null; then
    tmux kill-session -t "=$tmux_session" 2>/dev/null || true
    deleted+=("tmux:$tmux_session")
  fi

  rm -rf "$REVIEW_LOOP_DIR/$session_id"
  deleted+=("manifest:$session_id")

  echo "STATUS: CLEANED"
  printf 'DELETED: %s\n' "${deleted[@]}"
}

# ============================================================
# サブコマンド: selftest（純粋ロジックのみ・副作用なし）
# ============================================================

cmd_selftest() {
  local fail=0
  local tmp; tmp=$(mktemp -d)
  trap "rm -rf '$tmp'" EXIT

  # アサーション補助: 実出力が部分文字列を含むか（pipefail + grep -q 早期終了の SIGPIPE を避けるため
  # 出力を変数にキャプチャしてから glob 照合する）
  assert_contains() { # <label> <needle> <haystack>
    case "$3" in (*"$2"*) echo "ok  $1" ;; (*) echo "NG  $1"; fail=1 ;; esac
  }
  check_true()  { local label="$1"; shift; if "$@"; then echo "ok  $label"; else echo "NG  $label"; fail=1; fi; }
  check_false() { local label="$1"; shift; if "$@"; then echo "NG  $label"; fail=1; else echo "ok  $label"; fi; }

  # 収束判定
  printf 'some findings\nREVIEW_RESULT: APPROVED\n' > "$tmp/a.md"
  check_true  "converged: APPROVED" rl_review_converged "$tmp/a.md"
  printf 'REVIEW_RESULT: CHANGES_REQUESTED\n' > "$tmp/b.md"
  check_false "not-converged: CHANGES_REQUESTED" rl_review_converged "$tmp/b.md"
  # 大小混在・複数行・最後の判定を採用
  printf 'REVIEW_RESULT: changes_requested\n...fixed...\nreview_result: approved\n' > "$tmp/c.md"
  check_true  "converged: 最後の行(approved)を採用" rl_review_converged "$tmp/c.md"
  check_false "not-converged: 欠損ファイル" rl_review_converged "$tmp/missing"
  printf 'no verdict line here\n' > "$tmp/d.md"
  check_false "not-converged: 判定行なし" rl_review_converged "$tmp/d.md"

  # claude プロンプト: round1 はタスク、round2 は codex 指摘
  printf 'タスク本文XYZ' > "$tmp/task.md"
  printf 'codex指摘ABC' > "$tmp/findings.md"
  assert_contains "claude prompt r1: タスク含む"   'タスク本文XYZ' "$(rl_build_claude_prompt 1 "$tmp/task.md" "")"
  assert_contains "claude prompt r2: 指摘含む"     'codex指摘ABC'  "$(rl_build_claude_prompt 2 "$tmp/task.md" "$tmp/findings.md")"

  # codex プロンプト: 判定行の指示と前回指摘の同梱
  assert_contains "codex prompt r1: 判定行の指示含む" 'REVIEW_RESULT: APPROVED' "$(rl_build_codex_prompt 1 "main" "")"
  assert_contains "codex prompt r2: 前回指摘同梱"     'codex指摘ABC'            "$(rl_build_codex_prompt 2 "main" "$tmp/findings.md")"

  if [ "$fail" -eq 0 ]; then
    echo "SELFTEST: PASS"
  else
    echo "SELFTEST: FAIL"
    return 1
  fi
}

# ============================================================
# メイン
# ============================================================

subcommand="${1:-}"
shift || true
case "$subcommand" in
  launch)   cmd_launch "$@" ;;
  cleanup)  cmd_cleanup "$@" ;;
  selftest) cmd_selftest ;;
  *) die "Unknown subcommand: $subcommand. Usage: review-loop.sh {launch|cleanup|selftest}" ;;
esac
