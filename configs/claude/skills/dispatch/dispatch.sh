#!/usr/bin/env bash
set -euo pipefail

# dispatch.sh - 別リポジトリで tmux window を作り launcher（claude / codex）を起動する軽量ツール
#
# サブコマンド:
#   launch <repo> "<prompt>" [--launcher claude|codex] [--session <name>] [--window <name>] [--branch <name>] [--no-worktree] [--no-prompt] [--prompt-file <path>]
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
  tmux display-message -d 600000 "dispatch: $1" 2>/dev/null || true
}

# repo パス解決: フルパス or ghq 短縮名（your-org/your-sandbox）
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

  local wt_add_ok=true
  if [ -n "$remote_branch_exists" ]; then
    git -C "$repo_path" fetch origin "$branch_name":"$branch_name" 2>/dev/null || true
    git -C "$repo_path" worktree add "$worktree_path" "$branch_name" >&2 \
      || wt_add_ok=false
  else
    git -C "$repo_path" worktree add "$worktree_path" -b "$branch_name" "origin/${default_branch}" >&2 \
      || wt_add_ok=false
  fi

  # worktree add 失敗時: ブランチが別ディレクトリ名の worktree で既にチェックアウトされている可能性
  if [ "$wt_add_ok" = false ]; then
    local existing_path
    existing_path=$(git -C "$repo_path" worktree list --porcelain \
      | awk -v b="$branch_name" '/^worktree /{sub(/^worktree /,""); p=$0} /^branch refs\/heads\//{sub(/^branch /,""); if($0=="refs/heads/"b) print p}')
    if [ -n "$existing_path" ] && [ -d "$existing_path" ]; then
      echo "$existing_path" >&2
      echo "warn: ブランチ '$branch_name' は別名の worktree に存在します: $existing_path" >&2
      echo "$existing_path"
      return
    fi
    die "worktree の作成に失敗しました: $worktree_path"
  fi

  # .claude/settings.local.json をコピー（gw_add と同じ）
  if [ -f "$main_worktree/.claude/settings.local.json" ]; then
    mkdir -p "$worktree_path/.claude"
    cp "$main_worktree/.claude/settings.local.json" "$worktree_path/.claude/settings.local.json"
  fi

  echo "$worktree_path"
}

# メインworktree のパスを返し、作業ツリーが clean ならデフォルトブランチに checkout する。
# no-worktree-repos 設定によるトリガー時のみ呼ばれる（明示 --no-worktree のみの場合は呼ばれない）。
checkout_default_branch() {
  local repo_path="$1"

  local main_worktree
  main_worktree=$(git -C "$repo_path" worktree list --porcelain 2>/dev/null | head -n1 | sed 's/^worktree //')
  if [ -z "$main_worktree" ] || [ ! -d "$main_worktree" ]; then
    echo "$repo_path"
    return
  fi

  # デフォルトブランチを特定（origin/HEAD → main → master の順）
  local default_branch
  default_branch=$(git -C "$main_worktree" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
  if [ -z "$default_branch" ]; then
    if git -C "$main_worktree" show-ref --verify --quiet refs/heads/main 2>/dev/null; then
      default_branch="main"
    elif git -C "$main_worktree" show-ref --verify --quiet refs/heads/master 2>/dev/null; then
      default_branch="master"
    fi
  fi

  if [ -n "$default_branch" ]; then
    local current_branch
    current_branch=$(git -C "$main_worktree" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    if [ "$current_branch" != "$default_branch" ]; then
      if git -C "$main_worktree" diff --quiet 2>/dev/null && git -C "$main_worktree" diff --cached --quiet 2>/dev/null; then
        if ! git -C "$main_worktree" checkout "$default_branch" >/dev/null 2>&1; then
          tmux display-message -d 5000 "dispatch: warn: failed to checkout $default_branch" 2>/dev/null || true
        fi
      else
        tmux display-message -d 5000 "dispatch: dirty working tree, staying on $current_branch" 2>/dev/null || true
      fi
    fi
  fi

  echo "$main_worktree"
}

# --- サブコマンド: list-repos ---
cmd_list_repos() {
  ghq list 2>/dev/null || die "ghq が利用できません"
}

# --- サブコマンド: launch ---
cmd_launch() {
  local repo="" prompt="" prompt_file_arg="" session_name="" window_name="" branch_name="" no_worktree=false no_prompt=false launcher="claude"

  # 引数パース
  while [ $# -gt 0 ]; do
    case "$1" in
      --launcher)
        launcher="$2"
        shift 2
        ;;
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
      --no-prompt)
        no_prompt=true
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
  # 失敗時にプロンプト消失を防ぐため、削除は launcher 起動成功後まで遅延する
  if [ -n "$prompt_file_arg" ]; then
    if [ ! -f "$prompt_file_arg" ]; then
      die "prompt-file が見つかりません: $prompt_file_arg"
    fi
    prompt=$(cat "$prompt_file_arg")
  fi

  # バリデーション
  if [ -z "$repo" ]; then
    die "repo が指定されていません"
  fi
  if [ "$no_prompt" = false ] && [ -z "$prompt" ]; then
    die "prompt が指定されていません"
  fi
  case "$launcher" in
    claude|codex) ;;
    *) die "--launcher は claude または codex のみ対応です: $launcher" ;;
  esac

  # repo パス解決
  local repo_path
  repo_path=$(resolve_repo "$repo") || die "リポジトリが見つかりません: $repo"

  # no-worktree 設定ファイルによる自動判定
  # ~/.config/dispatch/no-worktree-repos に "owner/repo" 形式で列挙されたリポジトリは worktree を作成しない
  local no_worktree_config="$HOME/.config/dispatch/no-worktree-repos"
  local config_match=false
  if [ -f "$no_worktree_config" ]; then
    local repo_short
    repo_short=$(echo "$repo_path" | sed "s|$GHQ_ROOT/||")
    if grep -qxF "$repo_short" "$no_worktree_config" 2>/dev/null; then
      config_match=true
      if [ "$no_worktree" = false ]; then
        no_worktree=true
      fi
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
    notify "creating worktree: $branch_name"
    work_dir=$(create_worktree "$repo_path" "$branch_name")
  elif [ "$config_match" = true ]; then
    # no-worktree-repos 設定によるトリガー: メインworktreeに移動しデフォルトブランチで開く
    work_dir=$(checkout_default_branch "$repo_path")
  fi

  # prompt を一時ファイルに書き出し（worktree 側に配置）
  local prompt_file=""
  if [ "$no_prompt" = false ]; then
    local output_dir="$work_dir/.outputs/claude"
    mkdir -p "$output_dir"
    prompt_file=$(mktemp "$output_dir/dispatch-prompt-XXXXXX")
    printf '%s' "$prompt" > "$prompt_file"
  fi

  # tmux session/window 作成
  # session 名が未指定の場合、worktree のディレクトリ名をセッション名にする
  if [ -z "$session_name" ]; then
    session_name="$(basename "$work_dir")"
  fi

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
    # trailing colon を付けないと tmux が target を window index と解釈して
    # base-index 衝突（"index 1 in use"）で失敗するため "=$session_name:" を使う
    tmux new-window -t "=$session_name:" -n "$window_name" -c "$work_dir" \
      || die "tmux window の作成に失敗しました"
  fi

  # 作成直後の window の active pane id を取得し、以降の操作はすべてこれを target にする。
  # window target だと sidebar 等の hook で auto-split された pane に send-keys が
  # 飛ぶ可能性があるため、pane id で固定する。
  local target_pane_id
  target_pane_id=$(tmux display-message -t "=$session_name:=$window_name" -p '#{pane_id}')

  # claude がターミナルタイトルを変更して window 名を上書きするのを防止
  tmux set-option -t "=$session_name:=$window_name" allow-rename off

  # pane タイトル設定
  tmux select-pane -t "$target_pane_id" -T "$window_name"

  # window index を取得
  local window_index
  window_index=$(tmux display-message -t "$target_pane_id" -p '#{window_index}' 2>/dev/null || echo "unknown")
  local pane_id="$target_pane_id"

  # pane のシェルが起動するのを待ってから launcher を send-keys で起動
  sleep 0.5

  # codex は起動時に OSC 11 で背景色 query を送るが、tmux 3.4+ は attached client
  # にしか query を passthrough しない。dispatch は detached session で起動する
  # ため、attach 前に codex を起こすと入力エリアの背景色が描画されないモードで
  # 初期化されてしまう。attached client が来るまで待ってから send-keys する。
  # 関連: ADR-065, openai/codex#4744
  if [ "$launcher" = codex ]; then
    local wait_iter=0
    while [ "$(tmux list-clients -t "=$session_name" 2>/dev/null | wc -l | tr -d ' ')" -eq 0 ]; do
      if [ "$wait_iter" -ge 600 ]; then
        break
      fi
      sleep 0.5
      wait_iter=$((wait_iter + 1))
    done
  fi

  if [ "$no_prompt" = true ]; then
    # launcher 名のみ送る（claude も codex も同様）
    tmux send-keys -t "$target_pane_id" "cd '$work_dir'; $launcher" Enter
  else
    case "$launcher" in
      claude)
        tmux send-keys -t "$target_pane_id" "cd '$work_dir'; claude < '$prompt_file'" Enter
        ;;
      codex)
        # codex の TUI は stdin redirect 不可のため、位置引数で prompt を渡す
        # 改行を含む prompt は $(/bin/cat ...) でそのまま読ませる（shell quote で injection 対策）
        # 絶対パス指定で fish の abbreviation/alias（例: cat → nyan）を確実に回避する
        tmux send-keys -t "$target_pane_id" "cd '$work_dir'; codex -C '$work_dir' \"\$(/bin/cat '$prompt_file')\"" Enter
        ;;
    esac
  fi

  # launcher 起動まで成功したので、ここで初めて元の prompt-file を削除する
  if [ -n "$prompt_file_arg" ] && [ -f "$prompt_file_arg" ]; then
    rm -f "$prompt_file_arg"
  fi

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
