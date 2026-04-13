#!/usr/bin/env bash
# Stop hook: feature/fix/docs/chore ブランチで未コミット変更がある場合に
# Claude の停止をブロックし、commit→push→PR作成 を促す

# stdin を消費（hook がパイプで渡す JSON を読み捨てる）
cat > /dev/null

# git リポジトリでなければスキップ
git rev-parse --is-inside-work-tree &>/dev/null || exit 0

branch=$(git branch --show-current 2>/dev/null)

# feature/fix/docs/chore ブランチでなければスキップ
if ! echo "$branch" | grep -qE '^(feature|fix|docs|chore)/'; then
  exit 0
fi

# 未コミット変更がなければスキップ
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  exit 0
fi

echo "未コミット変更が ${branch} ブランチにあります。commit→push し、Draft PR が未作成なら作成してください。" >&2
exit 1
