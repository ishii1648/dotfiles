#!/usr/bin/env bash
# ADR: 070
# Purpose: 実装役と レビュー役（claude / codex を任意に割当）を交互駆動する反復レビューループのコーディネータ
#
# サブコマンド:
#   launch <repo_root> --session-id <id> --task-file <path>
#          [--implementer claude|codex] [--reviewer claude|codex]
#          [--max-rounds N] [--base <ref>] [--inherit-size] [--trust-workdir]
#   cleanup <session-id>
#   selftest                       # 純粋ロジック(収束判定/プロンプト生成/コマンド生成)の自己テスト
#
# 設計: ADR-070
#   - ロールは固定しない。既定は implementer=claude / reviewer=codex。--implementer / --reviewer で入替可。
#   - 完了検知は「エージェントが最後に書く完了マーカー」のみに依存する（フック非依存・capture-pane 非依存・
#     プロセス終了非依存）。実装役は round-N-impl.done に REVIEW_LOOP_IMPL_DONE を書き、レビュー役は
#     round-N-review.md に REVIEW_RESULT 行を書く（codex は stdout リダイレクトで生成）。
#   - claude はタスク完了後も REPL に留まり終了しない（2.1.x, auto mode）。そこでマーカー検知後に
#     Ctrl-D を送って claude を終了させ、次ラウンドは `claude --resume <uuid>` で文脈を引き継いで再起動する。
#     `-p`/`--print` は使わない（subscription 課金を維持）。
#   - codex はどのロールでも headless `codex exec`（reviewer=read-only で stdout 捕捉、implementer=
#     workspace-write で worktree 編集）。各ラウンド stateless（前回レビューはプロンプトに同梱）。
#   - tmux-sidebar 等が window にペインを足しても誤爆しないよう、起動時に pane_id を固定して send-keys する。

set -euo pipefail

REVIEW_LOOP_DIR="${REVIEW_LOOP_DIR:-$HOME/.review-loop}"
MARKER_TIMEOUT="${REVIEW_LOOP_MARKER_TIMEOUT:-900}"   # 1ターンあたりのマーカー待ちタイムアウト(秒)
IMPL_MARKER_TOKEN="REVIEW_LOOP_IMPL_DONE"
REVIEW_VERDICT_RE='REVIEW_RESULT:[[:space:]]*(APPROVED|CHANGES_REQUESTED)'

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
  # 重要: 判定行のフォーマットを説明する際、`REVIEW_RESULT:` の直後に判定語（APPROVED/CHANGES_REQUESTED）を
  # 隣接させて書かない。codex exec はプロンプトを stdout にエコーするため、プロンプト内に判定パターンが
  # リテラルで含まれると完了検知・収束判定がプロンプトのエコーを誤検知する（ADR-070 のライブ検証で判明）。
  if [ "$agent" = claude ] && [ -n "$out_file" ]; then
    # claude は対話 TUI のため stdout を捕捉できない。レビュー結果をファイルに書き出させる（これが完了マーカーも兼ねる）。
    cat <<EOF

レビュー結果は、あなたの応答ではなく必ずファイル \`${out_file}\` に書き出してください（Write ツール等を使用）。
そのファイルの最後の行を判定行にしてください。判定行は \`REVIEW_RESULT:\` で始め、続けて半角スペースのあと判定語を1つ書きます。
判定語は、修正すべき実質的な問題が残っていなければ「承認」を表す語、対応すべき指摘が残っていれば「変更要求」を表す語にします:
  - 承認のときの判定語 … APPROVED
  - 変更要求のときの判定語 … CHANGES_REQUESTED
（この判定行で完了検知と収束判定を行います）
EOF
  else
    # codex(headless) は stdout がそのままレビューファイルになる。
    cat <<'EOF'

レビューの最後に、判定行をちょうど1行出力してください。判定行は `REVIEW_RESULT:` で始め、続けて半角スペースのあと判定語を1つ書きます。
判定語は、修正すべき実質的な問題が残っていなければ「承認」を表す語、対応すべき指摘が残っていれば「変更要求」を表す語にします:
  - 承認のときの判定語 … APPROVED
  - 変更要求のときの判定語 … CHANGES_REQUESTED
（この判定行で完了検知と収束判定を行います）
EOF
  fi
}

# 実装役へのプロンプトを stdout に生成する（agent 非依存）。
# $1: round, $2: タスクファイル, $3: 前ラウンドのレビューファイル（round1 では空）, $4: 完了マーカーファイル
rl_build_implementer_prompt() {
  local round="$1" task_file="$2" review_file="${3:-}" marker_file="${4:-}"
  if [ "$round" -eq 1 ] || [ -z "$review_file" ]; then
    cat <<EOF
以下のタスクを実装してください。

--- タスク ---
$(cat "$task_file")
--- タスクここまで ---
EOF
  else
    cat <<EOF
レビュー(round $((round - 1)))で以下の指摘がありました。妥当な指摘に対応してコードを修正してください。指摘に同意できない場合は対応せず、その理由を簡潔に述べてください。

--- レビュー指摘 ---
$(cat "$review_file")
--- 指摘ここまで ---
EOF
  fi
  if [ -n "$marker_file" ]; then
    cat <<EOF

作業が完了したら、最後に必ず次のファイルに完了マーカーを書き込んでください（これがコーディネータへの完了の合図です。これを書くまでループは進みません）:
  ファイル: ${marker_file}
  内容: ${IMPL_MARKER_TOKEN}
（このファイルは .outputs 配下で git 管理外です。マーカーを書いたら追加の指示は待たず、そのまま待機して構いません）
EOF
  fi
}

# エージェント起動コマンド（trailing シグナルは含まない）を stdout に生成する。
# $1: agent, $2: role, $3: round, $4: work_dir, $5: prompt_file, $6: claude_sid, $7: out_file(codex reviewer のみ)
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
        printf "codex exec -C '%s' -s read-only - < '%s' > '%s' 2>&1" "$work_dir" "$prompt_file" "$out_file"
      else
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
# tmux ペイン操作
# ============================================================

# pane の current command がシェルに戻る（＝エージェントが終了して入力受付状態）まで待つ。
wait_pane_shell() {
  local pane_id="$1" timeout="${2:-30}" waited=0 cmd
  while [ "$waited" -lt "$timeout" ]; do
    cmd=$(tmux display-message -p -t "$pane_id" '#{pane_current_command}' 2>/dev/null || echo "")
    case "$cmd" in
      fish|bash|zsh|sh|dash|-fish|-bash|-zsh|-sh) return 0 ;;
    esac
    sleep 1; waited=$((waited + 1))
  done
  return 1
}

# 指定ファイルに token(ERE) が現れるまで待つ。エージェントの完了マーカー検知に使う。
wait_for_marker() {
  local file="$1" token="$2" timeout="${3:-$MARKER_TIMEOUT}" waited=0
  while [ "$waited" -lt "$timeout" ]; do
    if [ -f "$file" ] && grep -qE "$token" "$file" 2>/dev/null; then return 0; fi
    sleep 5; waited=$((waited + 5))
  done
  return 1
}

# REPL に留まる claude を終了させる（Ctrl-D、効かなければ二重 Ctrl-C にフォールバック）。
terminate_claude() {
  local pane_id="$1"
  tmux send-keys -t "$pane_id" C-d 2>/dev/null || true
  if wait_pane_shell "$pane_id" 15; then return 0; fi
  tmux send-keys -t "$pane_id" C-c 2>/dev/null || true
  tmux send-keys -t "$pane_id" C-c 2>/dev/null || true
  wait_pane_shell "$pane_id" 15 || true
}

# 既存の pane でコマンドを起動する（pane がシェルに戻ってから送る）。
launch_in_pane() {
  local pane_id="$1" work_dir="$2" cmd="$3"
  wait_pane_shell "$pane_id" 30 || true
  sleep 0.3
  tmux send-keys -t "$pane_id" "cd '$work_dir'; $cmd" Enter
}

# 新しい window を作って pane_id を返す（tmux-sidebar 等が後からペインを足しても誤爆しないよう pane_id を固定）。
create_role_window() {
  local tmux_session="$1" role="$2" work_dir="$3" pid
  pid=$(tmux new-window -P -F '#{pane_id}' -t "=${tmux_session}:" -n "$role" -c "$work_dir") || return 1
  tmux set-option -t "$pid" allow-rename off 2>/dev/null || true
  echo "$pid"
}

# ============================================================
# advance ループ（バックグラウンド・循環）
# ============================================================

advance_loop() {
  local session_id="$1" tmux_session="$2" work_dir="$3" max_rounds="$4" base_ref="$5" task_file="$6" out_dir="$7"
  local implementer="$8" reviewer="$9" impl_sid="${10}" rev_sid="${11}" impl_pane="${12}"

  local rev_pane="" result="exhausted" round=1 note=""

  while [ "$round" -le "$max_rounds" ]; do
    # 1. 実装役の完了をマーカーで待つ
    local impl_marker="$out_dir/round-${round}-impl.done"
    if ! wait_for_marker "$impl_marker" "$IMPL_MARKER_TOKEN" "$MARKER_TIMEOUT"; then
      result="timeout"; note="round $round の実装役が ${MARKER_TIMEOUT}s 以内に完了マーカーを書きませんでした"; break
    fi
    [ "$implementer" = claude ] && terminate_claude "$impl_pane"
    update_manifest "$session_id" ".rounds += [{round:$round, impl_done_at:(now|todate)}]"

    # 2. レビュー役を起動（reviewer window は初回に作成して pane_id を固定）
    if [ -z "$rev_pane" ]; then
      rev_pane=$(create_role_window "$tmux_session" reviewer "$work_dir") \
        || { result="error"; note="reviewer window の作成に失敗"; break; }
    fi
    local review_out="$out_dir/round-${round}-review.md"
    local review_prompt="$out_dir/round-${round}-review-prompt.txt"
    local prev_review=""
    [ "$round" -gt 1 ] && prev_review="$out_dir/round-$((round - 1))-review.md"
    rl_build_reviewer_prompt "$round" "$base_ref" "$prev_review" "$reviewer" "$review_out" > "$review_prompt"
    local rcmd
    rcmd=$(rl_build_agent_cmd "$reviewer" reviewer "$round" "$work_dir" "$review_prompt" "$rev_sid" "$review_out")
    launch_in_pane "$rev_pane" "$work_dir" "$rcmd"

    # 3. レビュー完了をマーカー(review.md の REVIEW_RESULT 行)で待つ
    if ! wait_for_marker "$review_out" "$REVIEW_VERDICT_RE" "$MARKER_TIMEOUT"; then
      result="timeout"; note="round $round のレビュー役が ${MARKER_TIMEOUT}s 以内に REVIEW_RESULT を出しませんでした"; break
    fi
    # codex は exit するまで待って出力を確定（ストリーミング途中の取りこぼし防止 + pane 解放）。claude は終了させる。
    if [ "$reviewer" = claude ]; then
      terminate_claude "$rev_pane"
    else
      wait_pane_shell "$rev_pane" 120 || true
    fi
    sleep 1

    # 4. 収束判定
    if rl_review_converged "$review_out"; then
      result="converged"
      update_manifest "$session_id" "(.rounds[-1].review_done_at)=(now|todate) | (.rounds[-1].verdict)=\"APPROVED\""
      break
    fi
    update_manifest "$session_id" "(.rounds[-1].review_done_at)=(now|todate) | (.rounds[-1].verdict)=\"CHANGES_REQUESTED\""

    # 5. 最大ラウンド到達なら打ち切り
    if [ "$round" -eq "$max_rounds" ]; then result="exhausted"; break; fi

    # 6. 次ラウンド: 実装役にレビュー指摘を渡して反映させる（claude は --resume で文脈引き継ぎ）
    round=$((round + 1))
    local impl_prompt="$out_dir/round-${round}-impl-prompt.txt"
    local next_marker="$out_dir/round-${round}-impl.done"
    rl_build_implementer_prompt "$round" "$task_file" "$review_out" "$next_marker" > "$impl_prompt"
    local icmd
    icmd=$(rl_build_agent_cmd "$implementer" implementer "$round" "$work_dir" "$impl_prompt" "$impl_sid" "")
    launch_in_pane "$impl_pane" "$work_dir" "$icmd"
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
    case "$result" in
      converged) echo "レビュー役($reviewer)が round $round で APPROVED。レビューループは収束しました。" ;;
      exhausted) echo "最大ラウンド($max_rounds)に達しても APPROVED が得られませんでした。残課題は round-${round}-review.md を参照してください。" ;;
      *)         echo "ループが異常終了しました: $note" ;;
    esac
  } > "$summary"
  update_manifest "$session_id" \
    ".state=\"complete\" | .result=\"$result\" | .rounds_executed=$round | .summary=\"$summary\" | .note=\"$note\""
  tmux display-message -d 8000 "review-loop: $result (round $round/$max_rounds) [$session_id]" 2>/dev/null || true
}

# ============================================================
# claude 信頼登録（--trust-workdir 明示時のみ）
# ============================================================

# 未信頼ディレクトリで claude を interactive 起動すると信頼ダイアログでループが止まる（`-p` ならスキップ）。
# 通常 review-loop は信頼済みの現 worktree 上で動くため不要。ユーザが明示的に --trust-workdir を渡したときだけ
# work_dir の realpath を ~/.claude.json に登録する（信頼ゲートの無断回避はしない）。
ensure_claude_trust() {
  local dir; dir=$(cd "$1" 2>/dev/null && pwd -P) || return 0
  local cfg="$HOME/.claude.json"
  [ -f "$cfg" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  if [ "$(jq -r --arg d "$dir" '.projects[$d].hasTrustDialogAccepted // false' "$cfg" 2>/dev/null)" = "true" ]; then
    return 0
  fi
  local tmp; tmp=$(mktemp)
  if jq --arg d "$dir" \
      '.projects = (.projects // {}) | .projects[$d] = ((.projects[$d] // {}) + {hasTrustDialogAccepted: true})' \
      "$cfg" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$cfg"
  else
    rm -f "$tmp"
  fi
}

# ============================================================
# サブコマンド: launch
# ============================================================

cmd_launch() {
  local repo_root="" session_id="" task_file="" max_rounds=3 base_ref="" inherit_size=false
  local implementer="claude" reviewer="codex" trust_workdir=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --session-id)    session_id="$2"; shift 2 ;;
      --task-file)     task_file="$2"; shift 2 ;;
      --max-rounds)    max_rounds="$2"; shift 2 ;;
      --base)          base_ref="$2"; shift 2 ;;
      --implementer)   implementer="$2"; shift 2 ;;
      --reviewer)      reviewer="$2"; shift 2 ;;
      --inherit-size)  inherit_size=true; shift ;;
      --trust-workdir) trust_workdir=true; shift ;;
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
  tmux display-message -p '#{session_name}' >/dev/null 2>&1 || die "tmux セッション外では動作しません"
  git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1 || die "git リポジトリではありません: $repo_root"

  # work_dir は現在の worktree（レビュー対象ブランチ）。新規 worktree は作らない。
  local work_dir="$repo_root"
  [ -z "$base_ref" ] && base_ref=$(rl_resolve_base_ref "$work_dir")

  if [ "$trust_workdir" = true ] && { [ "$implementer" = claude ] || [ "$reviewer" = claude ]; }; then
    ensure_claude_trust "$work_dir"
  fi

  # claude ロール用のセッション ID（UUID）。各ロールが claude のときのみ実際に使われる。
  local impl_sid rev_sid
  impl_sid=$(uuidgen | tr '[:upper:]' '[:lower:]')
  rev_sid=$(uuidgen | tr '[:upper:]' '[:lower:]')

  local out_dir="$work_dir/.outputs/claude/review-loop/$session_id"
  mkdir -p "$out_dir"

  # tmux セッション作成（implementer window）。pane_id を固定取得する。
  local tmux_session="review-loop-$session_id" impl_pane
  if [ "$inherit_size" = true ]; then
    local w h
    w=$(tmux display-message -p '#{window_width}' 2>/dev/null || echo 200)
    h=$(tmux display-message -p '#{window_height}' 2>/dev/null || echo 50)
    impl_pane=$(tmux new-session -d -P -F '#{pane_id}' -s "$tmux_session" -n implementer -c "$work_dir" -x "$w" -y "$h") \
      || die "tmux セッションの作成に失敗しました: $tmux_session"
  else
    impl_pane=$(tmux new-session -d -P -F '#{pane_id}' -s "$tmux_session" -n implementer -c "$work_dir") \
      || die "tmux セッションの作成に失敗しました: $tmux_session"
  fi
  tmux set-option -t "$impl_pane" allow-rename off 2>/dev/null || true

  write_manifest "$session_id" "$repo_root" "$work_dir" "$max_rounds" "$base_ref" "$tmux_session" \
    "$implementer" "$reviewer" "$impl_sid" "$rev_sid"
  update_manifest "$session_id" ".impl_pane=\"$impl_pane\""

  # round1: 実装役にタスクを実装させる
  local impl_marker="$out_dir/round-1-impl.done"
  local impl_prompt="$out_dir/round-1-impl-prompt.txt"
  rl_build_implementer_prompt 1 "$task_file" "" "$impl_marker" > "$impl_prompt"
  local icmd
  icmd=$(rl_build_agent_cmd "$implementer" implementer 1 "$work_dir" "$impl_prompt" "$impl_sid" "")
  launch_in_pane "$impl_pane" "$work_dir" "$icmd"

  # advance ループをバックグラウンド起動
  advance_loop "$session_id" "$tmux_session" "$work_dir" "$max_rounds" "$base_ref" "$task_file" "$out_dir" \
    "$implementer" "$reviewer" "$impl_sid" "$rev_sid" "$impl_pane" &
  local advance_pid=$!
  disown "$advance_pid"
  update_manifest "$session_id" ".advance_pid=$advance_pid"

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
  tmux display-message -d 5000 "review-loop: launched [$session_id] ${implementer} -> ${reviewer}" 2>/dev/null || true
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
  assert_contains() { case "$3" in (*"$2"*) echo "ok  $1" ;; (*) echo "NG  $1 [needle=$2]"; fail=1 ;; esac; }
  assert_excludes() { case "$3" in (*"$2"*) echo "NG  $1 [見つかってはいけない: $2]"; fail=1 ;; (*) echo "ok  $1" ;; esac; }
  # プロンプトに判定パターン(REVIEW_RESULT: <verdict>)がリテラルで含まれないこと（codex のプロンプトエコー誤検知の回帰防止）
  assert_no_verdict() {
    if grep -qE 'REVIEW_RESULT:[[:space:]]*(APPROVED|CHANGES_REQUESTED)' <<<"$2"; then
      echo "NG  $1 [判定パターンがプロンプトに混入]"; fail=1
    else echo "ok  $1"; fi
  }
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

  # --- 実装役プロンプト: round1 はタスク、round2 はレビュー指摘、両方で完了マーカー指示 ---
  printf 'タスク本文XYZ' > "$tmp/task.md"
  printf 'レビュー指摘ABC' > "$tmp/review.md"
  assert_contains "impl prompt r1: タスク含む"       'タスク本文XYZ'           "$(rl_build_implementer_prompt 1 "$tmp/task.md" "" "$tmp/r1.done")"
  assert_contains "impl prompt r1: マーカー指示含む" "$IMPL_MARKER_TOKEN"       "$(rl_build_implementer_prompt 1 "$tmp/task.md" "" "$tmp/r1.done")"
  assert_contains "impl prompt r1: マーカーパス含む" 'r1.done'                  "$(rl_build_implementer_prompt 1 "$tmp/task.md" "" "$tmp/r1.done")"
  assert_contains "impl prompt r2: 指摘含む"         'レビュー指摘ABC'         "$(rl_build_implementer_prompt 2 "$tmp/task.md" "$tmp/review.md" "$tmp/r2.done")"
  assert_contains "impl prompt r2: マーカー指示含む" "$IMPL_MARKER_TOKEN"       "$(rl_build_implementer_prompt 2 "$tmp/task.md" "$tmp/review.md" "$tmp/r2.done")"

  # --- レビュー役プロンプト ---
  local rev_codex rev_claude
  rev_codex=$(rl_build_reviewer_prompt 1 main "" codex "$tmp/round-1-review.md")
  rev_claude=$(rl_build_reviewer_prompt 1 main "" claude "$tmp/round-1-review.md")
  assert_contains "review prompt(codex): REVIEW_RESULT 指示"  'REVIEW_RESULT:'    "$rev_codex"
  assert_contains "review prompt(codex): APPROVED 言及"       'APPROVED'          "$rev_codex"
  assert_contains "review prompt(codex): CHANGES_REQUESTED 言及" 'CHANGES_REQUESTED' "$rev_codex"
  assert_no_verdict "review prompt(codex): 判定パターン非混入(回帰防止)" "$rev_codex"
  assert_no_verdict "review prompt(claude): 判定パターン非混入(回帰防止)" "$rev_claude"
  assert_contains "review prompt r2(codex): 前回同梱" 'レビュー指摘ABC'        "$(rl_build_reviewer_prompt 2 main "$tmp/review.md" codex "$tmp/round-2-review.md")"
  assert_contains "review prompt(claude): ファイル書き出し指示" 'round-1-review.md' "$rev_claude"
  assert_excludes "review prompt(codex): ファイル書き出し指示は無い" 'Write ツール' "$rev_codex"

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
  assert_excludes "cmd claude reviewer: --print 不使用" '--print' "$c"
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
