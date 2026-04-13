#!/usr/bin/env bash
set -euo pipefail

# dispatch.sh - 別リポジトリで tmux window を作り claude を起動する軽量ツール
#
# サブコマンド:
#   launch <repo> "<prompt>" [--session <name>] [--window <name>] [--branch <name>] [--no-worktree]
#   list-repos

GHQ_ROOT="$(ghq root 2>/dev/null || echo "$HOME/ghq")"

die() {
  echo "STATUS: ERROR"
  echo "MESSAGE: $1"
  tmux display-message -d 5000 "dispatch: ERROR: $1" 2>/dev/null || true
  exit 1
}

notify() {
  echo "STATUS: $1"
  tmux display-message -d 0 "dispatch: $1" 2>/dev/null || true
}

# repo パス解決: フルパス or ghq 短縮名（C-FO/sandbox-ishii1648）
resolve_repo() {
  local repo="$1"
  if [ -d "$repo" ]; then
    echo "$repo"
    return
  fi
  # ghq 短縮名を試す（github.com/ を補完）
  local candidates=("$GHQ_ROOT/github.com/$repo" "$GHQ_ROOT/$repo")
  for candidate in "${candidates[@]}"; do
    if [ -d "$candidate" ]; then
      echo "$candidate"
      return
    fi
  done
  return 1
}

# git worktree 作成: gw_add と同じ命名規則 (<main_worktree>@<branch_dir_name>)
create_worktree() {
  local repo_path="$1"
  local branch_name="$2"

  local main_worktree
  main_worktree=$(git -C "$repo_path" worktree list --porcelain | head -n1 | sed 's/^worktree //')
  if [ -z "$main_worktree" ]; then
    die "メインworktreeのパスを取得できません: $repo_path"
  fi

  local worktree_dir_name
  worktree_dir_name=$(echo "$branch_name" | tr '/' '-')
  local worktree_path="$main_worktree@$worktree_dir_name"

  # 既存 worktree があればそのまま使う
  if [ -d "$worktree_path" ]; then
    echo "$worktree_path"
    return
  fi

  # リモートの最新を取得
  git -C "$repo_path" fetch origin 2>/dev/null || true

  # デフォルトブランチを特定
  local default_branch
  default_branch=$(git -C "$repo_path" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  if [ -z "$default_branch" ]; then
    default_branch="main"
  fi

  # リモートブランチの存在確認
  local remote_branch_exists
  remote_branch_exists=$(git -C "$repo_path" ls-remote --heads origin "$branch_name" 2>/dev/null || true)

  if [ -n "$remote_branch_exists" ]; then
    git -C "$repo_path" fetch origin "$branch_name":"$branch_name" 2>/dev/null || true
    git -C "$repo_path" worktree add "$worktree_path" "$branch_name" >&2 \
      || die "worktree の作成に失敗しました: $worktree_path"
  else
    git -C "$repo_path" worktree add "$worktree_path" -b "$branch_name" "origin/${default_branch}" >&2 \
      || die "worktree の作成に失敗しました: $worktree_path"
  fi

  # .claude/settings.local.json をコピー（gw_add と同じ）
  if [ -f "$main_worktree/.claude/settings.local.json" ]; then
    mkdir -p "$worktree_path/.claude"
    cp "$main_worktree/.claude/settings.local.json" "$worktree_path/.claude/settings.local.json"
  fi

  echo "$worktree_path"
}

# --- サブコマンド: list-repos ---
cmd_list_repos() {
  ghq list 2>/dev/null || die "ghq が利用できません"
}

# --- サブコマンド: launch ---
cmd_launch() {
  local repo="" prompt="" prompt_file_arg="" session_name="" window_name="" branch_name="" no_worktree=false

  # 引数パース
  while [ $# -gt 0 ]; do
    case "$1" in
      --session)
        session_name="$2"
        shift 2
        ;;
      --window)
        window_name="$2"
        shift 2
        ;;
      --branch)
        branch_name="$2"
        shift 2
        ;;
      --no-worktree)
        no_worktree=true
        shift
        ;;
      --prompt-file)
        prompt_file_arg="$2"
        shift 2
        ;;
      *)
        if [ -z "$repo" ]; then
          repo="$1"
        elif [ -z "$prompt" ]; then
          prompt="$1"
        fi
        shift
        ;;
    esac
  done

  # --prompt-file があればそちらを優先して読み込む
  if [ -n "$prompt_file_arg" ]; then
    if [ ! -f "$prompt_file_arg" ]; then
      die "prompt-file が見つかりません: $prompt_file_arg"
    fi
    prompt=$(cat "$prompt_file_arg")
    rm -f "$prompt_file_arg"
  fi

  # バリデーション
  if [ -z "$repo" ]; then
    die "repo が指定されていません"
  fi
  if [ -z "$prompt" ]; then
    die "prompt が指定されていません"
  fi

  # repo パス解決
  local repo_path
  repo_path=$(resolve_repo "$repo") || die "リポジトリが見つかりません: $repo"

  # no-worktree 設定ファイルによる自動判定
  # ~/.config/dispatch/no-worktree-repos に "owner/repo" 形式で列挙されたリポジトリは worktree を作成しない
  local no_worktree_config="$HOME/.config/dispatch/no-worktree-repos"
  if [ "$no_worktree" = false ] && [ -f "$no_worktree_config" ]; then
    local repo_short
    repo_short=$(echo "$repo_path" | sed "s|$GHQ_ROOT/||")
    if grep -qxF "$repo_short" "$no_worktree_config" 2>/dev/null; then
      no_worktree=true
    fi
  fi

  # デフォルト window 名
  if [ -z "$window_name" ]; then
    window_name="$(basename "$repo_path")"
  fi

  # worktree 作成（--no-worktree でない場合）
  local work_dir="$repo_path"
  if [ "$no_worktree" = false ]; then
    if [ -z "$branch_name" ]; then
      die "--branch が指定されていません（--no-worktree でない場合は必須）"
    fi
    notify "[1/3] creating worktree: $branch_name"
    work_dir=$(create_worktree "$repo_path" "$branch_name")
  fi

  # prompt を一時ファイルに書き出し（worktree 側に配置）
  local output_dir="$work_dir/.outputs/claude"
  mkdir -p "$output_dir"
  local prompt_file
  prompt_file=$(mktemp "$output_dir/dispatch-prompt-XXXXXX")
  printf '%s' "$prompt" > "$prompt_file"

  # tmux session/window 作成
  # session 名が未指定の場合、worktree のディレクトリ名をセッション名にする
  if [ -z "$session_name" ]; then
    session_name="$(basename "$work_dir")"
  fi

  local step_prefix
  if [ "$no_worktree" = true ]; then
    step_prefix="[1/2]"
  else
    step_prefix="[2/3]"
  fi

  notify "$step_prefix creating tmux session: $session_name"
  if ! tmux has-session -t "=$session_name" 2>/dev/null; then
    # session が存在しない → 新規作成（最初の window として window_name を使う）
    # 現在のターミナルサイズを渡す（デタッチ作成後の比例拡大による sidebar 幅崩れを防止）
    local cur_width cur_height
    cur_width=$(tmux display-message -p '#{window_width}' 2>/dev/null || echo 200)
    cur_height=$(tmux display-message -p '#{window_height}' 2>/dev/null || echo 50)
    tmux new-session -d -s "$session_name" -n "$window_name" -c "$work_dir" \
      -x "$cur_width" -y "$cur_height" \
      || die "tmux session の作成に失敗しました: $session_name"
  else
    # session が存在する → window 追加
    tmux new-window -t "=$session_name" -n "$window_name" -c "$work_dir" \
      || die "tmux window の作成に失敗しました"
  fi

  # claude がターミナルタイトルを変更して window 名を上書きするのを防止
  tmux set-option -t "=$session_name:=$window_name" allow-rename off

  # pane タイトル設定
  tmux select-pane -t "=$session_name:=$window_name" -T "$window_name"

  # window index と pane id を取得
  local window_index pane_id
  window_index=$(tmux display-message -t "=$session_name:=$window_name" -p '#{window_index}' 2>/dev/null || echo "unknown")
  pane_id=$(tmux display-message -t "=$session_name:=$window_name" -p '#{pane_id}' 2>/dev/null || echo "unknown")

  # pane のシェルが起動するのを待ってから claude を send-keys で起動
  local launch_step
  if [ "$no_worktree" = true ]; then
    launch_step="[2/2]"
  else
    launch_step="[3/3]"
  fi
  notify "$launch_step launching claude in: $session_name"
  sleep 0.5
  tmux send-keys -t "=$session_name:=$window_name" "cd '$work_dir'; claude < '$prompt_file'" Enter

  # 構造化出力
  echo "STATUS: LAUNCHED"
  echo "SESSION: $session_name"
  echo "WINDOW: $window_index"
  echo "PANE_ID: $pane_id"
  echo "REPO: $repo_path"
  echo "WORK_DIR: $work_dir"

  tmux display-message -d 5000 "dispatch: launched [$session_name]" 2>/dev/null || true
}

# --- メイン ---
subcommand="${1:-}"
shift || true

case "$subcommand" in
  launch)
    cmd_launch "$@"
    ;;
  list-repos)
    cmd_list_repos
    ;;
  *)
    die "Unknown subcommand: $subcommand. Usage: dispatch.sh {launch|list-repos}"
    ;;
esac
