#!/bin/bash
# dispatch_launcher の orchestrate モード用ランチスクリプト
# orchestrate.sh launch を直接呼び出す（worktree + tmux + claude を一括作成）
#
# 引数: $1=ghq相対パス (github.com/owner/repo), $2=promptファイルパス
set -euo pipefail

GHQ_SELECTED="$1"
PROMPT_FILE="$2"
GHQ_ROOT="$(ghq root 2>/dev/null || echo "$HOME/ghq")"
REPO_ROOT="$GHQ_ROOT/$GHQ_SELECTED"

if [ ! -d "$REPO_ROOT" ]; then
  echo "ERROR: repo not found: $REPO_ROOT" >&2
  rm -f "$PROMPT_FILE"
  exit 1
fi

# session メタデータ生成（orchestrate skill の Step 1 と同等）
# owner/repo 抽出: github.com/owner/repo → owner/repo
OWNER_REPO=$(echo "$GHQ_SELECTED" | sed 's|^github\.com/||')
SESSION_NAME="$OWNER_REPO"
SESSION_SLUG=$(echo "$OWNER_REPO" | tr '/' '-')
SESSION_ID="${SESSION_SLUG}-$(date +%Y%m%d-%H%M%S)"

# タスクファイル作成（orchestrate.sh が期待する形式）
TASK_FILE="$REPO_ROOT/.outputs/claude/orchestrate-task-${SESSION_SLUG}.md"
mkdir -p "$(dirname "$TASK_FILE")"
cat "$PROMPT_FILE" > "$TASK_FILE"
rm -f "$PROMPT_FILE"

# orchestrate.sh launch を呼び出す
SCRIPT_DIR="$HOME/.claude/skills/orchestrate"
bash "$SCRIPT_DIR/orchestrate.sh" launch "$REPO_ROOT" \
  --session-id "$SESSION_ID" \
  --session-name "$SESSION_NAME" \
  --session-slug "$SESSION_SLUG" \
  --workflow feature \
  --task-file "$TASK_FILE" \
  --inherit-size

# 作成された session に切り替え
# resolve_session_name で重複回避された名前を使うため、manifest から取得
MANIFEST_SESSION=$(jq -r '.tmux_session' "$HOME/.orchestrate/$SESSION_ID/manifest.json" 2>/dev/null || echo "$SESSION_NAME")
tmux switch-client -t "=$MANIFEST_SESSION" 2>/dev/null || true
