#!/usr/bin/env bash
set -euo pipefail

# orchestrate.sh - エージェントチェーンの順次実行を tmux + git worktree で管理する
#
# サブコマンド:
#   launch <repo-root> --session-id <id> --session-name <name> --session-slug <slug>
#          --workflow <type> --task-file <path> [--agents <a,b,c>] [--inherit-size]
#   cleanup <session-id|session-name>
#   status <session-id|session-name>

ORCHESTRATE_DIR="$HOME/.orchestrate"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
  echo "STATUS: ERROR"
  echo "MESSAGE: $1"
  exit 1
}

# --- エージェントチェーン解決 ---
resolve_agent_chain() {
  local workflow="$1"
  local custom_agents="${2:-}"

  case "$workflow" in
    feature)  echo "planner tdd-guide code-reviewer security-reviewer" ;;
    bugfix)   echo "planner tdd-guide code-reviewer" ;;
    refactor) echo "architect code-reviewer tdd-guide" ;;
    security) echo "security-reviewer code-reviewer architect" ;;
    custom)
      if [ -z "$custom_agents" ]; then
        die "custom ワークフローには --agents が必要です"
      fi
      echo "$custom_agents" | tr ',' ' '
      ;;
    *) die "不明なワークフロータイプ: $workflow (feature/bugfix/refactor/security/custom)" ;;
  esac
}

# --- エージェント役割説明 ---
agent_role_description() {
  local agent="$1"
  case "$agent" in
    planner)
      cat <<'ROLE'
あなたは **planner** エージェントです。

タスクを分析し、実装計画を策定してください:
1. コードベースを読んでタスクの影響範囲を把握する
2. サブタスクに分解し、実装順序を決定する
3. 各サブタスクの対象ファイル・変更内容を明確にする
4. テスト戦略を検討する（どのレベルのテストが必要か）

計画は具体的かつ実行可能なレベルで記述してください。
ROLE
      ;;
    tdd-guide)
      cat <<'ROLE'
あなたは **tdd-guide** エージェントです。

TDD（テスト駆動開発）アプローチで実装を進めてください:
1. まずテストを書く（Red: 失敗するテストを作成）
2. テストを通す最小限の実装を行う（Green: テストを通過させる）
3. リファクタリングする（Refactor: コードを改善）
4. テストスイートを実行して全テストが通ることを確認する

前のエージェントの計画に従い、各サブタスクを順番に TDD で実装してください。
ROLE
      ;;
    code-reviewer)
      cat <<'ROLE'
あなたは **code-reviewer** エージェントです。

コードの品質を確認し、問題があれば修正してください:
1. 変更されたファイルを読んでレビューする
2. コードの可読性・保守性・一貫性を確認する
3. エッジケースの処理漏れがないか確認する
4. 問題があれば修正し、テストが通ることを確認する
ROLE
      ;;
    security-reviewer)
      cat <<'ROLE'
あなたは **security-reviewer** エージェントです。

セキュリティ観点でコードを確認してください:
1. OWASP Top 10 に該当する脆弱性がないか確認する
2. 入力バリデーション・サニタイズが適切か確認する
3. 認証・認可の処理に問題がないか確認する
4. 機密情報の取り扱いが適切か確認する
5. 問題があれば修正し、テストが通ることを確認する
ROLE
      ;;
    architect)
      cat <<'ROLE'
あなたは **architect** エージェントです。

アーキテクチャ設計を確認・改善してください:
1. コードの構造・依存関係を分析する
2. 設計パターンの一貫性を確認する
3. 拡張性・テスタビリティの観点で改善点を特定する
4. 問題があればリファクタリングし、テストが通ることを確認する
ROLE
      ;;
    *)
      echo "あなたは **${agent}** エージェントです。タスク記述に従って作業してください。"
      ;;
  esac
}

# --- エージェント別プロンプト生成 ---
generate_agent_prompt() {
  local agent="$1"
  local agent_index="$2"
  local total_agents="$3"
  local session_id="$4"
  local session_slug="$5"
  local workflow="$6"
  local worktree_path="$7"
  local task_file="$8"
  local prev_agent="${9:-}"
  local next_agent="${10:-}"

  local prompt_path="${worktree_path}/.outputs/claude/orchestrate-${session_slug}-${agent}.md"
  local handoff_dir="${worktree_path}/.outputs/claude/handoffs"

  local role_desc
  role_desc=$(agent_role_description "$agent")

  local task_content
  task_content=$(cat "$task_file")

  # ヘッダ
  cat > "$prompt_path" << PROMPT
# orchestrate: ${agent} エージェント

## コンテキスト

- session-id: ${session_id}
- workflow: ${workflow}
- agent: ${agent} ($((agent_index + 1))/${total_agents})
- worktree: ${worktree_path}
- handoff-dir: ${handoff_dir}/

あなたは worktree 内（\`${worktree_path}\`）で起動されています。すべてのファイル操作はこの worktree 内で行ってください。

## あなたの役割

${role_desc}
PROMPT

  # 前のエージェントからの引き継ぎ（2番目以降）
  if [ -n "$prev_agent" ]; then
    cat >> "$prompt_path" << PROMPT

## 前のエージェントからの引き継ぎ

以下のハンドオフ文書を **Read ツール**で読んでから作業を開始してください:
\`${handoff_dir}/HANDOFF-${prev_agent}-to-${agent}.md\`
PROMPT
  fi

  # タスク記述
  cat >> "$prompt_path" << PROMPT

## タスク記述

${task_content}

## 完了時の手順

PROMPT

  # 完了時の手順（最後のエージェントか否かで分岐）
  if [ -z "$next_agent" ]; then
    cat >> "$prompt_path" << PROMPT
1. 最終レポートを **Write ツール**で作成してください:
   \`${handoff_dir}/FINAL-REPORT.md\`

   形式:
   \`\`\`markdown
   # FINAL REPORT

   ## ワークフロー
   - タイプ: ${workflow}

   ## 実行結果サマリ
   - （全体の成果を記述）

   ## 変更ファイル一覧
   - （変更したファイルと内容の要約）

   ## 残課題
   - （あれば記載）
   \`\`\`

2. 変更を git commit する
PROMPT
  else
    cat >> "$prompt_path" << PROMPT
1. ハンドオフ文書を **Write ツール**で作成してください:
   \`${handoff_dir}/HANDOFF-${agent}-to-${next_agent}.md\`

   形式:
   \`\`\`markdown
   # HANDOFF: ${agent} → ${next_agent}

   ## 完了した作業
   - （箇条書きで具体的に）

   ## 変更したファイル
   - path/to/file: 変更内容の要約

   ## 次のエージェントへの指示
   - （具体的なアクションアイテム）

   ## 注意事項
   - （あれば記載）
   \`\`\`

2. 変更を git commit する
PROMPT
  fi

  # Bash 制約
  cat >> "$prompt_path" << 'PROMPT'

## Bash ツール使用の制約

以下の制約はすべての Bash 呼び出しに適用される（PreToolUse hook が強制）:
- `&&`/`||`/`;` での複数コマンド連結は**禁止**。各コマンドを個別の Bash 呼び出しに分割すること
- `$()` コマンド置換は**禁止**。前の Bash 呼び出し結果の出力から値を読み取ること
- ファイル書き込みには Write ツールを使用すること（`echo >` や `cat >` は禁止）
- `mkdir` は禁止。Write ツールはディレクトリを自動作成する
- Bash から `/tmp/` へのリダイレクト（`> /tmp/...`）は禁止（Write ツールは使用可）
PROMPT

  echo "$prompt_path"
}

# --- worktree 作成 (dispatch.sh パターン) ---
create_worktree() {
  local repo_root="$1"
  local session_id="$2"
  local branch_name="orchestrate/${session_id}/work"
  local worktree_dir_name
  worktree_dir_name="orchestrate-${session_id}-work"
  local worktree_path="${repo_root}@${worktree_dir_name}"

  # 既存 worktree があればそのまま使う
  if [ -d "$worktree_path" ]; then
    echo "$worktree_path"
    return
  fi

  # デフォルトブランチを特定
  local default_branch
  default_branch=$(git -C "$repo_root" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || true)
  if [ -z "$default_branch" ]; then
    default_branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  fi

  # worktree 作成
  git -C "$repo_root" worktree add "$worktree_path" -b "$branch_name" "$default_branch" >&2 \
    || die "worktree の作成に失敗しました: $worktree_path"

  # .claude/settings.local.json をコピー
  local main_worktree
  main_worktree=$(git -C "$repo_root" worktree list --porcelain | head -n1 | sed 's/^worktree //')
  if [ -n "$main_worktree" ] && [ -f "$main_worktree/.claude/settings.local.json" ]; then
    mkdir -p "$worktree_path/.claude"
    cp "$main_worktree/.claude/settings.local.json" "$worktree_path/.claude/settings.local.json"
  fi

  echo "$worktree_path"
}

# --- マニフェスト書き込み (v0.0.4: chain 構造対応) ---
write_manifest() {
  local session_id="$1"
  local session_name="$2"
  local session_slug="$3"
  local repo_root="$4"
  local worktree_path="$5"
  local branch_name="$6"
  local workflow="$7"
  local agents_str="$8"  # スペース区切り
  local creation_state="${9:-partial}"
  local tmux_created="${10:-false}"
  local worktree_created="${11:-false}"

  local manifest_dir="$ORCHESTRATE_DIR/$session_id"
  mkdir -p "$manifest_dir"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # agents 配列を JSON array に変換
  local agents_json="[]"
  local phases_json="[]"
  for agent in $agents_str; do
    agents_json=$(echo "$agents_json" | jq --arg a "$agent" '. + [$a]')
    phases_json=$(echo "$phases_json" | jq --arg a "$agent" '. + [{"agent": $a, "status": "pending", "handoff": null}]')
  done

  jq -n \
    --arg sid "$session_id" \
    --arg sname "$session_name" \
    --arg sslug "$session_slug" \
    --arg rroot "$repo_root" \
    --arg ts "$timestamp" \
    --arg cstate "$creation_state" \
    --arg wf "$workflow" \
    --arg wpath "$worktree_path" \
    --arg wbranch "$branch_name" \
    --argjson wcreated "$worktree_created" \
    --arg tsess "$session_name" \
    --argjson tcreated "$tmux_created" \
    --argjson agents "$agents_json" \
    --argjson phases "$phases_json" \
    '{
      session_id: $sid,
      session_name: $sname,
      session_slug: $sslug,
      repo_root: $rroot,
      created_at: $ts,
      creation_state: $cstate,
      workflow: $wf,
      worktree: {
        name: "work",
        path: $wpath,
        branch: $wbranch,
        created: $wcreated
      },
      tmux_session: $tsess,
      tmux_created: $tcreated,
      chain: {
        agents: $agents,
        current_phase: 0,
        phases: $phases
      },
      advance_pid: null
    }' > "$manifest_dir/manifest.json"
}

# --- マニフェスト更新 (jq で部分更新) ---
update_manifest() {
  local session_id="$1"
  shift
  local manifest="$ORCHESTRATE_DIR/$session_id/manifest.json"

  if [ ! -f "$manifest" ]; then
    die "マニフェストが見つかりません: $manifest"
  fi

  local filter="$1"
  local tmp
  tmp=$(jq "$filter" "$manifest")
  printf '%s\n' "$tmp" > "$manifest"
}

# --- セッション名の重複解決 ---
resolve_session_name() {
  local base_name="$1"
  local name="$base_name"
  local suffix=2

  while tmux has-session -t "=$name" 2>/dev/null; do
    name="${base_name}-${suffix}"
    suffix=$((suffix + 1))
  done

  echo "$name"
}

# --- エージェント起動 (tmux ウィンドウ作成 + Claude 起動) ---
launch_agent() {
  local resolved_name="$1"
  local agent="$2"
  local worktree_path="$3"
  local prompt_file="$4"
  local session_id="$5"
  local repo_root="$6"
  local is_first="${7:-false}"

  if [ "$is_first" = "true" ]; then
    # 最初のエージェント: セッション作成時のウィンドウをリネーム（既に作成済み）
    true
  else
    # 2番目以降: dispatch-new-worker-window で新規ウィンドウ作成
    local dnww
    dnww=$(command -v dispatch-new-worker-window 2>/dev/null || echo "$HOME/.claude/scripts/dispatch-new-worker-window")
    if [ -x "$dnww" ]; then
      "$dnww" "$resolved_name" "$agent" "$worktree_path" "$session_id" "$repo_root"
    else
      # フォールバック: 直接 tmux ウィンドウ作成
      local pane_id
      pane_id=$(tmux new-window -t "$resolved_name" -n "$agent" -c "$worktree_path" -P -F "#{pane_id}")
      tmux select-pane -t "$pane_id"
      local pane_num="${pane_id#%}"

      mkdir -p /tmp/claude-pane-state
      echo "$agent" > "/tmp/claude-pane-state/pane_${pane_num}_role"

      mkdir -p "$HOME/.workflow-sessions/pending"
      jq -n \
        --arg wsi "$session_id" \
        --arg role "$agent" \
        --arg repo_root "$repo_root" \
        --arg log_dir "docs/dispatch-logs/$session_id" \
        '{"workflow_session_id": $wsi, "role": $role, "repo_root": $repo_root, "log_dir": $log_dir}' \
        > "$HOME/.workflow-sessions/pending/pane-${pane_num}.json"
    fi
    tmux set-option -t "=${resolved_name}:=${agent}" allow-rename off
  fi

  # Claude 起動: 完了時に tmux wait-for -S でシグナルを送信
  sleep 0.5
  local signal="done-${session_id}-${agent}"
  tmux send-keys -t "${resolved_name}:${agent}" \
    "claude < '${prompt_file}'; tmux wait-for -S '${signal}'" Enter
}

# --- advance ループ (バックグラウンド実行) ---
advance_loop() {
  local session_id="$1"
  local resolved_name="$2"
  local worktree_path="$3"
  local session_slug="$4"
  local workflow="$5"
  local task_file="$6"
  local repo_root="$7"
  shift 7
  local agents=("$@")

  local total=${#agents[@]}
  local handoff_dir="${worktree_path}/.outputs/claude/handoffs"

  for ((i = 0; i < total; i++)); do
    local current_agent="${agents[$i]}"
    local signal="done-${session_id}-${current_agent}"

    # 現在のエージェントの完了を待機（トークン消費ゼロ）
    tmux wait-for "$signal" 2>/dev/null || true

    # フェーズステータス更新
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [ $i -lt $((total - 1)) ]; then
      # 中間エージェント: ハンドオフ文書の存在チェック
      local next_agent="${agents[$((i + 1))]}"
      local handoff="${handoff_dir}/HANDOFF-${current_agent}-to-${next_agent}.md"

      if [ -f "$handoff" ]; then
        update_manifest "$session_id" \
          ".chain.phases[$i].status = \"complete\" | .chain.phases[$i].completed_at = \"$timestamp\" | .chain.phases[$i].handoff = \"$handoff\" | .chain.current_phase = $((i + 1))"

        # 次のエージェントのプロンプト生成
        local prev_for_next="$current_agent"
        local next_for_next=""
        if [ $((i + 2)) -lt $total ]; then
          next_for_next="${agents[$((i + 2))]}"
        fi

        local next_prompt
        next_prompt=$(generate_agent_prompt "$next_agent" "$((i + 1))" "$total" \
          "$session_id" "$session_slug" "$workflow" "$worktree_path" "$task_file" \
          "$prev_for_next" "$next_for_next")

        # 次のフェーズ開始時刻を記録
        local start_ts
        start_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        update_manifest "$session_id" \
          ".chain.phases[$((i + 1))].status = \"running\" | .chain.phases[$((i + 1))].started_at = \"$start_ts\" | .creation_state = \"running\""

        # 次のエージェント起動
        launch_agent "$resolved_name" "$next_agent" "$worktree_path" "$next_prompt" "$session_id" "$repo_root" "false"
      else
        # ハンドオフ文書がない = エージェントが異常終了
        update_manifest "$session_id" \
          ".chain.phases[$i].status = \"failed\" | .chain.phases[$i].completed_at = \"$timestamp\" | .creation_state = \"failed\""
        return 1
      fi
    else
      # 最後のエージェント: FINAL-REPORT チェック
      local final_report="${handoff_dir}/FINAL-REPORT.md"
      if [ -f "$final_report" ]; then
        update_manifest "$session_id" \
          ".chain.phases[$i].status = \"complete\" | .chain.phases[$i].completed_at = \"$timestamp\" | .chain.phases[$i].handoff = \"$final_report\" | .creation_state = \"complete\""
      else
        update_manifest "$session_id" \
          ".chain.phases[$i].status = \"complete\" | .chain.phases[$i].completed_at = \"$timestamp\" | .creation_state = \"complete\""
      fi
    fi
  done
}

# === サブコマンド: launch ===
cmd_launch() {
  local repo_root="" session_id="" session_name="" session_slug=""
  local task_file="" workflow="" custom_agents="" inherit_size=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --session-id)    session_id="$2"; shift 2 ;;
      --session-name)  session_name="$2"; shift 2 ;;
      --session-slug)  session_slug="$2"; shift 2 ;;
      --task-file)     task_file="$2"; shift 2 ;;
      --workflow)      workflow="$2"; shift 2 ;;
      --agents)        custom_agents="$2"; shift 2 ;;
      --inherit-size)  inherit_size=true; shift ;;
      *)
        if [ -z "$repo_root" ]; then
          repo_root="$1"
        fi
        shift
        ;;
    esac
  done

  # バリデーション
  [ -z "$repo_root" ]    && die "repo-root が指定されていません"
  [ -z "$session_id" ]   && die "--session-id が指定されていません"
  [ -z "$session_name" ] && die "--session-name が指定されていません"
  [ -z "$session_slug" ] && die "--session-slug が指定されていません"
  [ -z "$task_file" ]    && die "--task-file が指定されていません"
  [ -z "$workflow" ]     && die "--workflow が指定されていません"
  [ ! -d "$repo_root" ]  && die "リポジトリが見つかりません: $repo_root"
  [ ! -f "$task_file" ]  && die "タスクファイルが見つかりません: $task_file"

  # tmux セッション外チェック
  if ! tmux display-message -p '#{session_name}' >/dev/null 2>&1; then
    die "tmux セッション外では動作しません"
  fi

  # 1. エージェントチェーン決定
  local agents_str
  agents_str=$(resolve_agent_chain "$workflow" "$custom_agents")
  read -ra agents <<< "$agents_str"
  local total=${#agents[@]}
  local first_agent="${agents[0]}"

  local branch_name="orchestrate/${session_id}/work"

  # 2. マニフェスト初期書き込み (副作用より前)
  write_manifest "$session_id" "$session_name" "$session_slug" "$repo_root" \
    "${repo_root}@orchestrate-${session_id}-work" "$branch_name" \
    "$workflow" "$agents_str" "partial" "false" "false"

  # 3. worktree 作成
  local worktree_path
  worktree_path=$(create_worktree "$repo_root" "$session_id")
  update_manifest "$session_id" '.worktree.created = true'

  # 4. ディレクトリ確保
  mkdir -p "$worktree_path/.outputs/claude/handoffs"

  # 5. tmux セッション名の重複解決
  local resolved_name
  resolved_name=$(resolve_session_name "$session_name")

  # 6. tmux セッション作成 (最初のエージェント名でウィンドウ作成)
  local tmux_opts=(-d -s "$resolved_name" -n "$first_agent" -c "$worktree_path")
  if [ "$inherit_size" = true ]; then
    local w h
    w=$(tmux display-message -p '#{window_width}' 2>/dev/null || echo "200")
    h=$(tmux display-message -p '#{window_height}' 2>/dev/null || echo "50")
    tmux_opts+=(-x "$w" -y "$h")
  fi
  tmux new-session "${tmux_opts[@]}" \
    || die "tmux セッションの作成に失敗しました: $resolved_name"

  # 7. 最初のエージェントのペイン role + pending context
  local pane_id
  pane_id=$(tmux display-message -t "${resolved_name}:${first_agent}" -p '#{pane_id}' 2>/dev/null || echo "")
  local pane_num="${pane_id#%}"

  if [ -n "$pane_num" ]; then
    mkdir -p /tmp/claude-pane-state
    echo "$first_agent" > "/tmp/claude-pane-state/pane_${pane_num}_role"

    mkdir -p "$HOME/.workflow-sessions/pending"
    jq -n \
      --arg wsi "$session_id" \
      --arg role "$first_agent" \
      --arg repo_root "$repo_root" \
      --arg log_dir "docs/dispatch-logs/$session_id" \
      '{"workflow_session_id": $wsi, "role": $role, "repo_root": $repo_root, "log_dir": $log_dir}' \
      > "$HOME/.workflow-sessions/pending/pane-${pane_num}.json"
  fi

  # 8. マニフェスト更新
  update_manifest "$session_id" \
    ".tmux_created = true | .tmux_session = \"$resolved_name\" | .creation_state = \"launched\""

  # 9. 最初のエージェントのプロンプト生成
  local next_agent=""
  if [ "$total" -gt 1 ]; then
    next_agent="${agents[1]}"
  fi

  local first_prompt
  first_prompt=$(generate_agent_prompt "$first_agent" "0" "$total" \
    "$session_id" "$session_slug" "$workflow" "$worktree_path" "$task_file" \
    "" "$next_agent")

  # 10. 最初のフェーズを running に更新
  local start_ts
  start_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  update_manifest "$session_id" \
    ".chain.phases[0].status = \"running\" | .chain.phases[0].started_at = \"$start_ts\" | .creation_state = \"running\""

  # 11. 最初のエージェント起動
  tmux set-option -t "=${resolved_name}:=${first_agent}" allow-rename off
  launch_agent "$resolved_name" "$first_agent" "$worktree_path" "$first_prompt" "$session_id" "$repo_root" "true"

  # 12. advance ループをバックグラウンド起動
  advance_loop "$session_id" "$resolved_name" "$worktree_path" "$session_slug" \
    "$workflow" "$task_file" "$repo_root" "${agents[@]}" &
  local advance_pid=$!
  # tmux run-shell -b から呼ばれた場合、親 bash 終了時に advance_loop が
  # SIGHUP で終了しないよう disown で切り離す
  disown "$advance_pid"
  update_manifest "$session_id" ".advance_pid = $advance_pid"

  # 構造化出力
  echo "STATUS: LAUNCHED"
  echo "SESSION: $resolved_name"
  echo "SESSION_ID: $session_id"
  echo "WORKFLOW: $workflow"
  echo "AGENTS: $agents_str"
  echo "WORKTREE: $worktree_path"
  echo "BRANCH: $branch_name"
  echo "MANIFEST: $ORCHESTRATE_DIR/$session_id/manifest.json"
}

# === サブコマンド: cleanup ===
cmd_cleanup() {
  local target="$1"

  # session-id か session-name かを判定
  local manifest=""
  local session_id=""

  if [[ "$target" =~ -[0-9]{8}-[0-9]{6}$ ]]; then
    session_id="$target"
    manifest="$ORCHESTRATE_DIR/$session_id/manifest.json"
    if [ ! -f "$manifest" ]; then
      die "マニフェストが見つかりません: $manifest"
    fi
  else
    if [ ! -d "$ORCHESTRATE_DIR" ]; then
      die "マニフェストが見つかりません (session-name: $target)"
    fi
    for dir in "$ORCHESTRATE_DIR"/*/; do
      local mf="$dir/manifest.json"
      if [ -f "$mf" ]; then
        local sname
        sname=$(jq -r '.session_name' "$mf" 2>/dev/null || true)
        if [ "$sname" = "$target" ]; then
          manifest="$mf"
          session_id=$(jq -r '.session_id' "$mf")
          break
        fi
      fi
    done
    if [ -z "$manifest" ]; then
      die "マニフェストが見つかりません (session-name: $target)"
    fi
  fi

  # マニフェスト読み込み
  local repo_root tmux_session tmux_created worktree_path worktree_branch session_slug
  repo_root=$(jq -r '.repo_root' "$manifest")
  tmux_session=$(jq -r '.tmux_session' "$manifest")
  tmux_created=$(jq -r '.tmux_created' "$manifest")
  worktree_path=$(jq -r '.worktree.path' "$manifest")
  worktree_branch=$(jq -r '.worktree.branch' "$manifest")
  session_slug=$(jq -r '.session_slug' "$manifest")

  # マニフェスト検証
  local expected_wt_prefix="${repo_root}@orchestrate-${session_id}-"
  local expected_br_prefix="orchestrate/${session_id}/"
  case "$worktree_path" in
    "${expected_wt_prefix}"*) ;;
    *) die "マニフェスト検証失敗: worktree.path が不正 ($worktree_path)" ;;
  esac
  case "$worktree_branch" in
    "${expected_br_prefix}"*) ;;
    *) die "マニフェスト検証失敗: worktree.branch が不正 ($worktree_branch)" ;;
  esac

  local deleted=()

  # 0. advance ループの停止
  local advance_pid
  advance_pid=$(jq -r '.advance_pid // empty' "$manifest")
  if [ -n "$advance_pid" ] && kill -0 "$advance_pid" 2>/dev/null; then
    kill "$advance_pid" 2>/dev/null || true
    deleted+=("advance_loop:$advance_pid")
  fi

  # 1. tmux セッション削除
  if [ "$tmux_created" = "true" ] && tmux has-session -t "=$tmux_session" 2>/dev/null; then
    tmux kill-session -t "=$tmux_session"
    deleted+=("tmux:$tmux_session")
  fi

  # 2. worktree 削除
  if git -C "$repo_root" worktree list --porcelain 2>/dev/null | grep -q "^worktree $worktree_path$"; then
    git -C "$repo_root" worktree remove --force "$worktree_path" 2>/dev/null || true
    deleted+=("worktree:$worktree_path")
  fi

  # 3. ブランチ削除 (session-id スコープのすべてのブランチ)
  local branches
  branches=$(git -C "$repo_root" branch --list "orchestrate/${session_id}/*" 2>/dev/null || true)
  if [ -n "$branches" ]; then
    while IFS= read -r branch; do
      branch=$(echo "$branch" | sed 's/^[* ]*//')
      if [ -n "$branch" ]; then
        git -C "$repo_root" branch -D "$branch" 2>/dev/null || true
        deleted+=("branch:$branch")
      fi
    done <<< "$branches"
  fi

  # 4. 残存ディレクトリ削除
  if [ -d "$worktree_path" ]; then
    rmdir "$worktree_path" 2>/dev/null || true
  fi

  # 5. エージェント別プロンプトファイル削除
  for agent_prompt in "${repo_root}/.outputs/claude/orchestrate-${session_slug}-"*.md; do
    if [ -f "$agent_prompt" ]; then
      rm "$agent_prompt"
      deleted+=("agent-prompt:$(basename "$agent_prompt")")
    fi
  done

  # 6. タスクファイル削除
  local task_file="${repo_root}/.outputs/claude/orchestrate-task-${session_slug}.md"
  if [ -f "$task_file" ]; then
    rm "$task_file"
    deleted+=("task:$task_file")
  fi

  # 7. 計画 YAML 削除
  local plan_yaml="${repo_root}/.outputs/claude/orchestrate-plan-${session_slug}.yaml"
  if [ -f "$plan_yaml" ]; then
    rm "$plan_yaml"
    deleted+=("plan:$plan_yaml")
  fi

  # 8. マニフェストディレクトリ削除
  rm "$manifest"
  rmdir "$ORCHESTRATE_DIR/$session_id" 2>/dev/null || true
  deleted+=("manifest:$session_id")

  # 構造化出力
  echo "STATUS: CLEANED"
  echo "SESSION_ID: $session_id"
  for item in "${deleted[@]}"; do
    echo "DELETED: $item"
  done
}

# === サブコマンド: status ===
cmd_status() {
  local target="$1"
  local manifest=""

  if [[ "$target" =~ -[0-9]{8}-[0-9]{6}$ ]]; then
    manifest="$ORCHESTRATE_DIR/$target/manifest.json"
  else
    if [ -d "$ORCHESTRATE_DIR" ]; then
      for dir in "$ORCHESTRATE_DIR"/*/; do
        local mf="$dir/manifest.json"
        if [ -f "$mf" ]; then
          local sname
          sname=$(jq -r '.session_name' "$mf" 2>/dev/null || true)
          if [ "$sname" = "$target" ]; then
            manifest="$mf"
            break
          fi
        fi
      done
    fi
  fi

  if [ -z "$manifest" ] || [ ! -f "$manifest" ]; then
    die "マニフェストが見つかりません: $target"
  fi

  echo "STATUS: OK"
  cat "$manifest"
}

# === メイン ===
subcommand="${1:-}"
shift || true

case "$subcommand" in
  launch)   cmd_launch "$@" ;;
  cleanup)  cmd_cleanup "${1:-}" ;;
  status)   cmd_status "${1:-}" ;;
  *)        die "Unknown subcommand: $subcommand. Usage: orchestrate.sh {launch|cleanup|status}" ;;
esac
