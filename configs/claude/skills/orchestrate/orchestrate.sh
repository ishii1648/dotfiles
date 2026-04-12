#!/usr/bin/env bash
set -euo pipefail

# orchestrate.sh - worktree 作成・tmux セッション起動・cleanup を担う
#
# サブコマンド:
#   launch <repo-root> --session-id <id> --session-name <name> --prompt-file <path>
#          [--plan-yaml <path>] [--inherit-size]
#   cleanup <session-id>
#   status <session-id>

ORCHESTRATE_DIR="$HOME/.orchestrate"

die() {
  echo "STATUS: ERROR"
  echo "MESSAGE: $1"
  exit 1
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
    # remote HEAD が未設定の場合は現在のブランチを使用
    default_branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  fi

  # worktree 作成
  git -C "$repo_root" worktree add "$worktree_path" -b "$branch_name" "$default_branch" >&2 \
    || die "worktree の作成に失敗しました: $worktree_path"

  # .claude/settings.local.json をコピー (dispatch.sh と同じ)
  local main_worktree
  main_worktree=$(git -C "$repo_root" worktree list --porcelain | head -n1 | sed 's/^worktree //')
  if [ -n "$main_worktree" ] && [ -f "$main_worktree/.claude/settings.local.json" ]; then
    mkdir -p "$worktree_path/.claude"
    cp "$main_worktree/.claude/settings.local.json" "$worktree_path/.claude/settings.local.json"
  fi

  echo "$worktree_path"
}

# --- マニフェスト書き込み ---
write_manifest() {
  local session_id="$1"
  local session_name="$2"
  local session_slug="$3"
  local repo_root="$4"
  local worktree_path="$5"
  local branch_name="$6"
  local creation_state="${7:-partial}"
  local tmux_created="${8:-false}"
  local worktree_created="${9:-false}"

  local manifest_dir="$ORCHESTRATE_DIR/$session_id"
  mkdir -p "$manifest_dir"

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq -n \
    --arg sid "$session_id" \
    --arg sname "$session_name" \
    --arg sslug "$session_slug" \
    --arg rroot "$repo_root" \
    --arg ts "$timestamp" \
    --arg cstate "$creation_state" \
    --arg wpath "$worktree_path" \
    --arg wbranch "$branch_name" \
    --argjson wcreated "$worktree_created" \
    --arg tsess "$session_name" \
    --argjson tcreated "$tmux_created" \
    '{
      session_id: $sid,
      session_name: $sname,
      session_slug: $sslug,
      repo_root: $rroot,
      created_at: $ts,
      creation_state: $cstate,
      worktree: {
        name: "work",
        path: $wpath,
        branch: $wbranch,
        created: $wcreated
      },
      tmux_session: $tsess,
      tmux_created: $tcreated
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

  # 残り引数を jq フィルタとして適用
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

# === サブコマンド: launch ===
cmd_launch() {
  local repo_root="" session_id="" session_name="" session_slug=""
  local prompt_file="" plan_yaml="" inherit_size=false

  while [ $# -gt 0 ]; do
    case "$1" in
      --session-id)    session_id="$2"; shift 2 ;;
      --session-name)  session_name="$2"; shift 2 ;;
      --session-slug)  session_slug="$2"; shift 2 ;;
      --prompt-file)   prompt_file="$2"; shift 2 ;;
      --plan-yaml)     plan_yaml="$2"; shift 2 ;;
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
  [ -z "$prompt_file" ]  && die "--prompt-file が指定されていません"
  [ ! -d "$repo_root" ]  && die "リポジトリが見つかりません: $repo_root"
  [ ! -f "$prompt_file" ] && die "プロンプトファイルが見つかりません: $prompt_file"

  # tmux セッション外チェック
  if ! tmux display-message -p '#{session_name}' >/dev/null 2>&1; then
    die "tmux セッション外では動作しません"
  fi

  local branch_name="orchestrate/${session_id}/work"

  # 1. マニフェスト初期書き込み (副作用より前)
  write_manifest "$session_id" "$session_name" "$session_slug" "$repo_root" \
    "${repo_root}@orchestrate-${session_id}-work" "$branch_name" "partial" "false" "false"

  # 2. worktree 作成
  local worktree_path
  worktree_path=$(create_worktree "$repo_root" "$session_id")
  update_manifest "$session_id" '.worktree.created = true'

  # 3. .outputs/claude/ ディレクトリ確保
  mkdir -p "$worktree_path/.outputs/claude"

  # 4. tmux セッション名の重複解決
  local resolved_name
  resolved_name=$(resolve_session_name "$session_name")

  # 5. tmux セッション作成 (ウィンドウサイズ継承)
  local tmux_opts=(-d -s "$resolved_name" -n work -c "$worktree_path")
  if [ "$inherit_size" = true ]; then
    local w h
    w=$(tmux display-message -p '#{window_width}' 2>/dev/null || echo "200")
    h=$(tmux display-message -p '#{window_height}' 2>/dev/null || echo "50")
    tmux_opts+=(-x "$w" -y "$h")
  fi
  tmux new-session "${tmux_opts[@]}" \
    || die "tmux セッションの作成に失敗しました: $resolved_name"

  # 6. ペイン role + pending context (dispatch-new-worker-window と同等)
  local pane_id
  pane_id=$(tmux display-message -t "${resolved_name}:work" -p '#{pane_id}' 2>/dev/null || echo "")
  local pane_num="${pane_id#%}"

  if [ -n "$pane_num" ]; then
    mkdir -p /tmp/claude-pane-state
    echo "work" > "/tmp/claude-pane-state/pane_${pane_num}_role"

    mkdir -p "$HOME/.workflow-sessions/pending"
    jq -n \
      --arg wsi "$session_id" \
      --arg role "work" \
      --arg repo_root "$repo_root" \
      --arg log_dir "docs/dispatch-logs/$session_id" \
      '{"workflow_session_id": $wsi, "role": $role, "repo_root": $repo_root, "log_dir": $log_dir}' \
      > "$HOME/.workflow-sessions/pending/pane-${pane_num}.json"
  fi

  # 7. マニフェスト更新
  update_manifest "$session_id" \
    ".tmux_created = true | .tmux_session = \"$resolved_name\" | .creation_state = \"launched\""

  # 8. Claude 起動 (stdin redirect で確実に prompt 注入)
  tmux set-option -t "=${resolved_name}:=work" allow-rename off
  sleep 0.5
  tmux send-keys -t "${resolved_name}:work" "claude < '${prompt_file}'" Enter

  # 構造化出力
  echo "STATUS: LAUNCHED"
  echo "SESSION: $resolved_name"
  echo "SESSION_ID: $session_id"
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

  # session-id 形式: <slug>-YYYYMMDD-HHMMSS
  if [[ "$target" =~ -[0-9]{8}-[0-9]{6}$ ]]; then
    session_id="$target"
    manifest="$ORCHESTRATE_DIR/$session_id/manifest.json"
    if [ ! -f "$manifest" ]; then
      die "マニフェストが見つかりません: $manifest"
    fi
  else
    # session-name で走査
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

  # 5. 計画 YAML 削除
  local plan_yaml="${repo_root}/.outputs/claude/orchestrate-plan-${session_slug}.yaml"
  if [ -f "$plan_yaml" ]; then
    rm "$plan_yaml"
    deleted+=("plan:$plan_yaml")
  fi

  # 6. タスクプロンプト削除
  local task_prompt="${repo_root}/.outputs/claude/orchestrate-task-${session_slug}.md"
  if [ -f "$task_prompt" ]; then
    rm "$task_prompt"
    deleted+=("prompt:$task_prompt")
  fi

  # 7. マニフェストディレクトリ削除
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

  # session-id 形式
  if [[ "$target" =~ -[0-9]{8}-[0-9]{6}$ ]]; then
    manifest="$ORCHESTRATE_DIR/$target/manifest.json"
  else
    # session-name で走査
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
