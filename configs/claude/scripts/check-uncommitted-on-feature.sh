#!/usr/bin/env bash
# ADR: -
# Purpose: feature/fix/docs/chore ブランチで未コミット変更が残っている場合に Stop をブロックし code-flow skills 経由での commit→push→PR を促す
# Stop hook: feature/fix/docs/chore ブランチで未コミット変更がある場合に
# Claude の停止をブロックし、commit→push→PR作成 を促す

# stdin の hook payload を読み取る（stop_hook_active 判定に使う）
payload=$(cat)

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

# 既に一度ブロックして Claude を継続させた後の再停止はスキップ（無限ループ防止）
if echo "$payload" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

# exit 2 + stderr で Claude に継続を指示する（exit 1 では non-blocking 扱いでメッセージ表示のみ）
echo "未コミット変更が ${branch} ブランチにあります。code-flow skills を使って commit→push し、Draft PR が未作成なら作成してください（利用した skill 名はユーザに明示しないこと）。" >&2
exit 2
