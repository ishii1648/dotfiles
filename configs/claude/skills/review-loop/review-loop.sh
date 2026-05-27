#!/usr/bin/env bash
# ADR: 070
# Purpose: 実装役と レビュー役（claude / codex を任意に割当）を tmux wait-for で交互駆動する反復レビューループのコーディネータ
#
# サブコマンド:
#   launch <repo_root> --session-id <id> --task-file <path>
#          [--implementer claude|codex] [--reviewer claude|codex]
#          [--max-rounds N] [--base <ref>] [--inherit-size]
#   cleanup <session-id>
#   selftest                       # 純粋ロジック(終了判定/プロンプト生成/コマンド生成)の自己テスト
#
# 設計: ADR-070
#   - ロールは固定しない。既定は implementer=claude / reviewer=codex。--implementer / --reviewer で入替可。
#   - claude（どのロールでも）: round1 は `claude --session-id <uuid>`、round2 以降は `claude --resume <uuid>`
#     で interactive 起動（subscription 課金、`-p` 不使用）。stdin EOF で終了 → wait-for が完了通知。
#     レビュー役のときは TUI 出力を捕捉できないため、verdict を指定ファイルに書かせる（プロンプトで指示）。
#   - codex（どのロールでも）: headless `codex exec`。レビュー役は `-s read-only` で stdout をファイル捕捉、
#     実装役は `-s workspace-write` で worktree を編集。各ラウンド stateless（前回レビューはプロンプトに同梱）。
#   - コーディネータ(advance_loop): バックグラウンドで `tmux wait-for` をゼロコスト待機し、
#     implementer→reviewer→(収束判定)→implementer... を回す。REVIEW_RESULT: APPROVED か最大ラウンドで終了。

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

# レビュー出力ファイルから収束を判定する。
# 最後に出現した `REVIEW_RESULT:` 行が APPROVED なら収束（exit 0）、それ以外は未収束（exit 1）。
rl_review_converged() {
  local out_file="$1"
  [ -f "$out_file" ] || return 1
  local verdict
  verdict=$( { grep -oiE 'REVIEW_RESULT:[[:space:]]*(APPROVED|CHANGES_REQUESTED)' "$out_file" 2>/dev/null \
    | tail -n 1 | grep -oiE '(APPROVED|CHANGES_REQUESTED)' | tr '[:lower:]' '[:upper:]'; } || true)
  [ "$verdict" = "APPROVED" ]
}

# レビュー役へのプロンプトを stdout に生成する。
# $1: round, $2: base_ref, $3: 前ラウンドのレビューファイル（空可）, $4: agent(claude|codex), $5: out_file
rl_build_reviewer_prompt() {
  local round="$1" base_ref="$2" prev_review="${3:-}" agent="${4:-codex}" out_file="${5:-}"
  cat <<EOF
あなたはコードレビュー担当です。このリポジトリの現在のブランチに加えられた変更をレビューしてください。コードは変更せず、レビューに徹してください。

- 変更全体を把握するには次を実行してください: \`git diff ${base_ref}...HEAD\` および \`git status\` / \`git diff\`（未コミットの作業ツリー変更も対象に含める）
- バグ・正しさの問題・抜けたエッジケース・既存コードとの不整合を優先して指摘してください
- 各指摘は「ファイル:行 — 問題 — 推奨対応」の形式で具体的に書いてください
- スタイルの好みではなく、修正すべき実質的な問題に絞ってください
EOF
  if [ -n "$prev_review" ] && [ -f "$prev_review" ]; then
    cat <<EOF

これは round ${round} の再レビューです。前回(round $((round - 1)))のレビュー指摘は以下です。実装役が対応済みか確認し、未対応・新規の問題のみを今回の指摘として挙げてください:

--- 前回のレビュー ---
$(cat "$prev_review")
--- 前回のレビューここまで ---
EOF
  fi
  if [ "$agent" = claude ] && [ -n "$out_file" ]; then
    # claude は対話 TUI のため stdout を捕捉できない。レビュー結果をファイルに書き出させる。
    cat <<EOF

レビュー結果は、あなたの応答ではなく必ずファイル \`${out_file}\` に書き出してください（Write ツール等を使用）。
そのファイルの最終行を、レビュー結果に応じて次のいずれかにしてください（この行で収束を判定します）:
  REVIEW_RESULT: APPROVED            （修正すべき実質的な問題が残っていない）
  REVIEW_RESULT: CHANGES_REQUESTED   （対応すべき指摘が残っている）
EOF
  else
    # codex(headless) は stdout がそのままレビューファイルになる。
    cat <<'EOF'

出力の最終行に、レビュー結果を必ず次のいずれかで明記してください（この行で収束を判定します）:
  REVIEW_RESULT: APPROVED            （修正すべき実質的な問題が残っていない）
  REVIEW_RESULT: CHANGES_REQUESTED   （対応すべき指摘が残っている）
EOF
  fi
}

# 実装役へのプロンプトを stdout に生成する（agent 非依存）。
# $1: round, $2: タスクファイル, $3: 前ラウンドのレビューファイル（round1 では空）
rl_build_implementer_prompt() {
  local round="$1" task_file="$2" review_file="${3:-}"
  if [ "$round" -eq 1 ] || [ -z "$review_file" ]; then
    cat <<EOF
以下のタスクを実装してください。完了したらそのまま終了してください（追加の指示は待たないでください）。

--- タスク ---
$(cat "$task_file")
--- タスクここまで ---
EOF
  else
    cat <<EOF
レビュー(round $((round - 1)))で以下の指摘がありました。妥当な指摘に対応してコードを修正してください。対応が完了したらそのまま終了してください（追加の指示は待たないでください）。指摘に同意できない場合は対応せず、その理由を簡潔に述べてください。

--- レビュー指摘 ---
$(cat "$review_file")
--- 指摘ここまで ---
EOF
  fi
}

# エージェント起動コマンド（trailing の wait-for は含まない）を stdout に生成する。
# $1: agent(claude|codex), $2: role(implementer|reviewer), $3: round,
# $4: work_dir, $5: prompt_file, $6: claude_sid（agent=claude のとき使用）, $7: out_file（agent=codex かつ reviewer のとき使用）
rl_build_agent_cmd() {
  local agent="$1" role="$2" round="$3" work_dir="$4" prompt_file="$5" claude_sid="${6:-}" out_file="${7:-}"
  case "$agent" in
    claude)
      # interactive 起動（`-p`/`--print` は使わない＝subscription 課金）。文脈は session-id で継続。
      if [ "$round" -eq 1 ]; then
        printf "claude --session-id '%s' < '%s'" "$claude_sid" "$prompt_file"
      else
        printf "claude --resume '%s' < '%s'" "$claude_sid" "$prompt_file"
      fi
      ;;
    codex)
      if [ "$role" = reviewer ]; then
        # read-only sandbox。stdout をレビューファイルに捕捉。
        printf "codex exec -C '%s' -s read-only - < '%s' > '%s' 2>&1" "$work_dir" "$prompt_file" "$out_file"
      else
        # 実装役: worktree を編集。非対話なので承認待ちで固まらないよう approval_policy=never。
        printf "codex exec -C '%s' -s workspace-write -c approval_policy=never - < '%s'" "$work_dir" "$prompt_file"
      fi
      ;;
    *)
      die "未知の agent: $agent"
      ;;
  esac
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
  local session_id="$1" repo_root="$2" work_dir="$3" max_rounds="$4" base_ref="$5" tmux_session="$6"
  local implementer="$7" reviewer="$8" impl_sid="$9" rev_sid="${10}"
  mkdir -p "$REVIEW_LOOP_DIR/$session_id"
  jq -n \
    --arg sid "$session_id" --arg repo "$repo_root" --arg wd "$work_dir" \
    --argjson mr "$max_rounds" --arg base "$base_ref" --arg ts "$tmux_session" \
    --arg impl "$implementer" --arg rev "$reviewer" \
    --arg isid "$impl_sid" --arg rsid "$rev_sid" \
    '{session_id:$sid, repo_root:$repo, work_dir:$wd,
      implementer:$impl, reviewer:$rev,
      impl_claude_session_id:$isid, rev_claude_session_id:$rsid,
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

# ロールに対応する tmux window を必要なら作成する。window 名 = role。
ensure_window() {
  local tmux_session="$1" window="$2" work_dir="$3"
  if ! tmux list-windows -t "=${tmux_session}" -F '#{window_name}' 2>/dev/null | grep -qx "$window"; then
    tmux new-window -t "=${tmux_session}:" -n "$window" -c "$work_dir" -d \
      || die "tmux window の作成に失敗しました: $window"
    tmux set-option -t "=${tmux_session}:${window}" allow-rename off 2>/dev/null || true
  fi
}

# ロール（implementer / reviewer）を起動する。window 名 = role。
# $1: tmux_session, $2: role, $3: agent, $4: round, $5: work_dir, $6: prompt_file,
# $7: claude_sid, $8: out_file（reviewer のみ意味を持つ）, $9: signal
launch_role() {
  local tmux_session="$1" role="$2" agent="$3" round="$4" work_dir="$5" prompt_file="$6"
  local claude_sid="$7" out_file="$8" signal="$9"
  ensure_window "$tmux_session" "$role" "$work_dir"
  local cmd
  cmd=$(rl_build_agent_cmd "$agent" "$role" "$round" "$work_dir" "$prompt_file" "$claude_sid" "$out_file")
  sleep 0.3
  tmux send-keys -t "=${tmux_session}:${role}" \
    "cd '$work_dir'; $cmd; tmux wait-for -S '$signal'" Enter
}

# ============================================================
# advance ループ（バックグラウンド・循環）
# ============================================================

advance_loop() {
  local session_id="$1" tmux_session="$2" work_dir="$3" max_rounds="$4" base_ref="$5" task_file="$6" out_dir="$7"
  local implementer="$8" reviewer="$9" impl_sid="${10}" rev_sid="${11}"

  local result="exhausted"
  local round=1
  while [ "$round" -le "$max_rounds" ]; do
    # 1. 実装役の完了を待つ
    tmux wait-for "rl-done-${session_id}-impl-${round}" 2>/dev/null || true
    update_manifest "$session_id" ".rounds += [{round:$round, impl_done_at:(now|todate)}]"

    # 2. レビュー役を起動
    local review_out="$out_dir/round-${round}-review.md"
    local review_prompt="$out_dir/round-${round}-review-prompt.txt"
    local prev_review=""
    [ "$round" -gt 1 ] && prev_review="$out_dir/round-$((round - 1))-review.md"
    rl_build_reviewer_prompt "$round" "$base_ref" "$prev_review" "$reviewer" "$review_out" > "$review_prompt"
    launch_role "$tmux_session" reviewer "$reviewer" "$round" "$work_dir" "$review_prompt" \
      "$rev_sid" "$review_out" "rl-done-${session_id}-review-${round}"

    # 3. レビュー完了を待つ
    tmux wait-for "rl-done-${session_id}-review-${round}" 2>/dev/null || true

    # 4. 収束判定
    if rl_review_converged "$review_out"; then
      result="converged"
      update_manifest "$session_id" \
        "(.rounds[-1].review_done_at) = (now|todate) | (.rounds[-1].verdict) = \"APPROVED\""
      break
    fi
    update_manifest "$session_id" \
      "(.rounds[-1].review_done_at) = (now|todate) | (.rounds[-1].verdict) = \"CHANGES_REQUESTED\""

    # 5. 最大ラウンド到達なら打ち切り
    if [ "$round" -eq "$max_rounds" ]; then
      result="exhausted"
      break
    fi

    # 6. 次ラウンド: 実装役にレビュー指摘を渡して反映させる
    round=$((round + 1))
    local impl_prompt="$out_dir/round-${round}-impl-prompt.txt"
    rl_build_implementer_prompt "$round" "$task_file" "$review_out" > "$impl_prompt"
    launch_role "$tmux_session" implementer "$implementer" "$round" "$work_dir" "$impl_prompt" \
      "$impl_sid" "" "rl-done-${session_id}-impl-${round}"
  done

  # 最終サマリ
  local summary="$out_dir/SUMMARY.md"
  {
    echo "# review-loop summary"
    echo
    echo "- session-id: $session_id"
    echo "- implementer: $implementer / reviewer: $reviewer"
    echo "- result: $result"
    echo "- rounds executed: $round / $max_rounds"
    echo "- base ref: $base_ref"
    echo
    if [ "$result" = "converged" ]; then
      echo "レビュー役($reviewer)が round $round で APPROVED。レビューループは収束しました。"
    else
      echo "最大ラウンド($max_rounds)に達しても APPROVED が得られませんでした。残課題は round-${round}-review.md を参照してください。"
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
  local implementer="claude" reviewer="codex"

  while [ $# -gt 0 ]; do
    case "$1" in
      --session-id)   session_id="$2"; shift 2 ;;
      --task-file)    task_file="$2"; shift 2 ;;
      --max-rounds)   max_rounds="$2"; shift 2 ;;
      --base)         base_ref="$2"; shift 2 ;;
      --implementer)  implementer="$2"; shift 2 ;;
      --reviewer)     reviewer="$2"; shift 2 ;;
      --inherit-size) inherit_size=true; shift ;;
      *) if [ -z "$repo_root" ]; then repo_root="$1"; fi; shift ;;
    esac
  done

  [ -z "$repo_root" ]   && die "repo-root が指定されていません"
  [ -z "$session_id" ]  && die "--session-id が指定されていません"
  [ -z "$task_file" ]   && die "--task-file が指定されていません"
  [ ! -d "$repo_root" ] && die "リポジトリが見つかりません: $repo_root"
  [ ! -f "$task_file" ] && die "タスクファイルが見つかりません: $task_file"
  case "$implementer" in claude|codex) ;; *) die "--implementer は claude または codex: $implementer" ;; esac
  case "$reviewer"    in claude|codex) ;; *) die "--reviewer は claude または codex: $reviewer" ;; esac
  case "$max_rounds" in (''|*[!0-9]*) die "--max-rounds は整数で指定してください: $max_rounds" ;; esac
  [ "$max_rounds" -lt 1 ] && die "--max-rounds は 1 以上で指定してください"

  command -v jq >/dev/null 2>&1 || die "jq が利用できません"
  if [ "$implementer" = codex ] || [ "$reviewer" = codex ]; then
    command -v codex >/dev/null 2>&1 || die "codex が利用できません"
  fi
  if [ "$implementer" = claude ] || [ "$reviewer" = claude ]; then
    command -v claude >/dev/null 2>&1 || die "claude が利用できません"
  fi
  if ! tmux display-message -p '#{session_name}' >/dev/null 2>&1; then
    die "tmux セッション外では動作しません"
  fi
  git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1 || die "git リポジトリではありません: $repo_root"

  # work_dir は現在の worktree（レビュー対象ブランチ）。新規 worktree は作らない。
  local work_dir="$repo_root"
  [ -z "$base_ref" ] && base_ref=$(rl_resolve_base_ref "$work_dir")

  # claude ロール用のセッション ID（UUID）。各ロールが claude のときのみ実際に使われる。
  local impl_sid rev_sid
  impl_sid=$(uuidgen | tr '[:upper:]' '[:lower:]')
  rev_sid=$(uuidgen | tr '[:upper:]' '[:lower:]')

  local out_dir="$work_dir/.outputs/claude/review-loop/$session_id"
  mkdir -p "$out_dir"

  # tmux セッション作成（最初の window = implementer）
  local tmux_session="review-loop-$session_id"
  local tmux_opts=(-d -s "$tmux_session" -n implementer -c "$work_dir")
  if [ "$inherit_size" = true ]; then
    local w h
    w=$(tmux display-message -p '#{window_width}' 2>/dev/null || echo 200)
    h=$(tmux display-message -p '#{window_height}' 2>/dev/null || echo 50)
    tmux_opts+=(-x "$w" -y "$h")
  fi
  tmux new-session "${tmux_opts[@]}" || die "tmux セッションの作成に失敗しました: $tmux_session"
  tmux set-option -t "=${tmux_session}:implementer" allow-rename off 2>/dev/null || true

  write_manifest "$session_id" "$repo_root" "$work_dir" "$max_rounds" "$base_ref" "$tmux_session" \
    "$implementer" "$reviewer" "$impl_sid" "$rev_sid"

  # round1: 実装役にタスクを実装させる
  local impl_prompt="$out_dir/round-1-impl-prompt.txt"
  rl_build_implementer_prompt 1 "$task_file" "" > "$impl_prompt"
  launch_role "$tmux_session" implementer "$implementer" 1 "$work_dir" "$impl_prompt" \
    "$impl_sid" "" "rl-done-${session_id}-impl-1"

  # advance ループをバックグラウンド起動
  advance_loop "$session_id" "$tmux_session" "$work_dir" "$max_rounds" "$base_ref" "$task_file" "$out_dir" \
    "$implementer" "$reviewer" "$impl_sid" "$rev_sid" &
  local advance_pid=$!
  disown "$advance_pid"
  update_manifest "$session_id" ".advance_pid = $advance_pid"

  echo "STATUS: LAUNCHED"
  echo "SESSION_ID: $session_id"
  echo "TMUX_SESSION: $tmux_session"
  echo "WORK_DIR: $work_dir"
  echo "IMPLEMENTER: $implementer"
  echo "REVIEWER: $reviewer"
  echo "BASE_REF: $base_ref"
  echo "MAX_ROUNDS: $max_rounds"
  echo "OUT_DIR: $out_dir"
  echo "MANIFEST: $(manifest_path "$session_id")"
  tmux display-message -d 5000 "review-loop: launched [$session_id] $implementer→$reviewer" 2>/dev/null || true
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

  # 出力を変数にキャプチャしてから glob 照合する（pipefail + grep -q 早期終了の SIGPIPE を避ける）
  assert_contains()  { case "$3" in (*"$2"*) echo "ok  $1" ;; (*) echo "NG  $1 [needle=$2]"; fail=1 ;; esac; }
  assert_excludes()  { case "$3" in (*"$2"*) echo "NG  $1 [見つかってはいけない: $2]"; fail=1 ;; (*) echo "ok  $1" ;; esac; }
  check_true()  { local label="$1"; shift; if "$@"; then echo "ok  $label"; else echo "NG  $label"; fail=1; fi; }
  check_false() { local label="$1"; shift; if "$@"; then echo "NG  $label"; fail=1; else echo "ok  $label"; fi; }

  # --- 収束判定 ---
  printf 'some findings\nREVIEW_RESULT: APPROVED\n' > "$tmp/a.md"
  check_true  "converged: APPROVED" rl_review_converged "$tmp/a.md"
  printf 'REVIEW_RESULT: CHANGES_REQUESTED\n' > "$tmp/b.md"
  check_false "not-converged: CHANGES_REQUESTED" rl_review_converged "$tmp/b.md"
  printf 'REVIEW_RESULT: changes_requested\n...fixed...\nreview_result: approved\n' > "$tmp/c.md"
  check_true  "converged: 最後の行(approved)を採用" rl_review_converged "$tmp/c.md"
  check_false "not-converged: 欠損ファイル" rl_review_converged "$tmp/missing"
  printf 'no verdict line here\n' > "$tmp/d.md"
  check_false "not-converged: 判定行なし" rl_review_converged "$tmp/d.md"

  # --- 実装役プロンプト: round1 はタスク、round2 はレビュー指摘 ---
  printf 'タスク本文XYZ' > "$tmp/task.md"
  printf 'レビュー指摘ABC' > "$tmp/review.md"
  assert_contains "impl prompt r1: タスク含む"   'タスク本文XYZ' "$(rl_build_implementer_prompt 1 "$tmp/task.md" "")"
  assert_contains "impl prompt r2: 指摘含む"     'レビュー指摘ABC'  "$(rl_build_implementer_prompt 2 "$tmp/task.md" "$tmp/review.md")"

  # --- レビュー役プロンプト: 判定行の指示・前回レビュー同梱・claude のときファイル書き出し指示 ---
  assert_contains "review prompt r1(codex): 判定行" 'REVIEW_RESULT: APPROVED' "$(rl_build_reviewer_prompt 1 main "" codex "$tmp/round-1-review.md")"
  assert_contains "review prompt r2(codex): 前回同梱" 'レビュー指摘ABC' "$(rl_build_reviewer_prompt 2 main "$tmp/review.md" codex "$tmp/round-2-review.md")"
  assert_contains "review prompt(claude): ファイル書き出し指示" 'round-1-review.md' "$(rl_build_reviewer_prompt 1 main "" claude "$tmp/round-1-review.md")"
  assert_excludes "review prompt(codex): ファイル書き出し指示は無い" 'Write ツール' "$(rl_build_reviewer_prompt 1 main "" codex "$tmp/round-1-review.md")"

  # --- エージェントコマンド生成 ---
  local c
  c=$(rl_build_agent_cmd claude implementer 1 /w /p/r1 sid-impl "")
  assert_contains "cmd claude impl r1: --session-id" "--session-id 'sid-impl'" "$c"
  assert_excludes "cmd claude impl r1: -p 不使用" ' -p ' "$c"
  assert_excludes "cmd claude impl r1: --print 不使用" '--print' "$c"
  c=$(rl_build_agent_cmd claude implementer 2 /w /p/r2 sid-impl "")
  assert_contains "cmd claude impl r2: --resume" "--resume 'sid-impl'" "$c"
  c=$(rl_build_agent_cmd claude reviewer 1 /w /p/rv sid-rev "/o/rev.md")
  assert_contains "cmd claude reviewer: interactive(--session-id)" "--session-id 'sid-rev'" "$c"
  assert_excludes "cmd claude reviewer: -p 不使用" '--print' "$c"
  c=$(rl_build_agent_cmd codex reviewer 1 /w /p/rv "" "/o/rev.md")
  assert_contains "cmd codex reviewer: codex exec" 'codex exec' "$c"
  assert_contains "cmd codex reviewer: read-only" '-s read-only' "$c"
  assert_contains "cmd codex reviewer: stdout 捕捉" "> '/o/rev.md'" "$c"
  c=$(rl_build_agent_cmd codex implementer 1 /w /p/im "" "")
  assert_contains "cmd codex impl: workspace-write" '-s workspace-write' "$c"
  assert_contains "cmd codex impl: approval_policy=never" 'approval_policy=never' "$c"

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
