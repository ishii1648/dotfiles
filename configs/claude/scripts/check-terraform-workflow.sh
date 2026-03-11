#!/bin/bash
# Stop hook: check-terraform-workflow.sh
# .tf ファイルへの未コミット変更がある場合、terraform workflow の完了を確認する

set -euo pipefail

# 再発火防止: 一度 block したらセッション内では再度 block しない
# Stop hook が block → Claude が対応 → 再度 Stop → 再 block のループを防止する
LOCK_DIR="${TMPDIR:-/tmp}"
LOCK_FILE="${LOCK_DIR}/claude-tf-workflow-check-${CLAUDE_SESSION_ID:-unknown}.lock"

FEEDBACK_MESSAGE="terraform workflowが完了していません。以下を実行してください：

terraform-validate スキルを使って validate / plan / tflint を実行してください：
  「/terraform-validate <ディレクトリ>」

エラーがなければ git commit を実行してください"

# フィードバックを返して終了する関数
feedback() {
  local reason="$1"
  # 既に block 済みならスキップ（ループ防止）
  if [ -f "$LOCK_FILE" ]; then
    exit 0
  fi
  # lock ファイルを作成して再発火を防止
  touch "$LOCK_FILE"
  if command -v jq &>/dev/null; then
    jq -n --arg reason "$reason" '{"decision":"block","reason":$reason}'
  else
    # jq がない場合は改行をエスケープしてJSON文字列を作成
    local escaped
    escaped=$(printf '%s' "$reason" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
    printf '{"decision":"block","reason":%s}\n' "$escaped"
  fi
  exit 1
}

# 1. .tf ファイルへの未コミット変更があるか確認
if ! git status --porcelain 2>/dev/null | grep -q '\.tf$'; then
  exit 0
fi

# 2. validate-result.txt が存在するか確認（必須）
# terraform validate は AWS 認証不要でコードエラーを検出できるため必須
if [ ! -f ".outputs/terraform/validate-result.txt" ]; then
  feedback "terraform validate が実行されていません（必須）。

${FEEDBACK_MESSAGE}"
fi

# 3. validate 結果にエラーがないか確認（必須・例外なし）
# validate エラーはコードの問題のため、認証エラーと異なり例外は設けない
if grep -q "^Error" ".outputs/terraform/validate-result.txt" 2>/dev/null; then
  feedback "terraform validate の結果にエラーがあります。エラーを修正してから再実行してください。

${FEEDBACK_MESSAGE}"
fi

# 4. plan-result.txt が存在するか確認
if [ ! -f ".outputs/terraform/plan-result.txt" ]; then
  feedback "$FEEDBACK_MESSAGE"
fi

# 5. plan 結果のエラーチェック
# 注意: terraform は MCP 経由で実行するため、認証エラー(ExpiredToken等)はブロック対象外
# ただし validate が通過していることが前提（上記 Step 3 で確認済み）
if grep -q "^Error:" ".outputs/terraform/plan-result.txt" 2>/dev/null; then
  # 認証・初期化系エラーは環境問題のためスキップ（validate で代替検証済み）
  if ! grep -qE "^Error: (Failed to initialize Terraform|configuring Terraform|No valid credential)" ".outputs/terraform/plan-result.txt" 2>/dev/null; then
    feedback "terraform plan の結果にコードエラーがあります。エラーを修正してから再実行してください。

${FEEDBACK_MESSAGE}"
  fi
fi

# 6. tflint-result.txt が存在するか確認
if [ ! -f ".outputs/terraform/tflint-result.txt" ]; then
  feedback "$FEEDBACK_MESSAGE"
fi

# 7. tflint 結果にエラーがないか確認
if grep -qE "^(Error|ERROR)" ".outputs/terraform/tflint-result.txt" 2>/dev/null; then
  feedback "tflint の結果にエラーがあります。エラーを修正してから再実行してください。

${FEEDBACK_MESSAGE}"
fi

# 全チェック通過: lock ファイルを削除して次回チェックを有効化
rm -f "$LOCK_FILE"
exit 0
