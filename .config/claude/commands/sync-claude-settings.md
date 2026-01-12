---
description: "Sync worktree settings.local.json to repository root"
allowed-tools: Bash(cat:*/cp:*/test:*/mkdir:*)
---

# sync-claude-settings

worktree 内の `.claude/settings.local.json` を親リポジトリ（main worktree）の `.claude/settings.local.json` に同期する。

## Workflow

1. **Worktree判定**: 現在のディレクトリがworktreeかどうかを確認
   - `.git` がファイルであればworktree内
   - ディレクトリであれば通常のリポジトリ（エラー終了）

2. **親リポジトリルート取得**: `.git` ファイルから `gitdir:` パスを解析
   ```
   gitdir: /path/to/parent/.git/worktrees/<name>
   → /path/to/parent を抽出
   ```

3. **ファイル同期**: worktreeの `.claude/settings.local.json` を親リポジトリにコピー

## 実行コマンド

```bash
# Worktree判定
if [ ! -f .git ]; then
  echo "Error: Not in a git worktree. This command only works inside a worktree."
  exit 1
fi

# 親リポジトリルート取得
GITDIR=$(cat .git | grep 'gitdir:' | cut -d' ' -f2)
PARENT_ROOT=$(echo "$GITDIR" | sed 's|/\.git/worktrees/[^/]*$||')

# 現在のworktreeルート
WORKTREE_ROOT=$(pwd)

# ソースファイルの存在確認
if [ ! -f "$WORKTREE_ROOT/.claude/settings.local.json" ]; then
  echo "Error: $WORKTREE_ROOT/.claude/settings.local.json does not exist."
  exit 1
fi

# 親リポジトリに .claude ディレクトリがなければ作成
mkdir -p "$PARENT_ROOT/.claude"

# コピー実行
cp "$WORKTREE_ROOT/.claude/settings.local.json" "$PARENT_ROOT/.claude/settings.local.json"

echo "Synced: $WORKTREE_ROOT/.claude/settings.local.json"
echo "    -> $PARENT_ROOT/.claude/settings.local.json"
```
