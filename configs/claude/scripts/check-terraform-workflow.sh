#!/bin/bash
# Stop hook: check-terraform-workflow.sh
# .tf ファイルへの未コミット変更がある場合、terraform workflow の完了を確認する

set -euo pipefail

FEEDBACK_MESSAGE="terraform workflowが完了していません。以下を順番に実行してください：

1. mkdir -p .outputs/terraform && terraform plan 2>&1 | tee .outputs/terraform/plan-result.txt
2. tflint 2>&1 | tee .outputs/terraform/tflint-result.txt
3. エラーがなければ git commit を実行してください"

# フィードバックを返して終了する関数
feedback() {
  local reason="$1"
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

# 2. plan-result.txt が存在するか確認
if [ ! -f ".outputs/terraform/plan-result.txt" ]; then
  feedback "$FEEDBACK_MESSAGE"
fi

# 3. plan 結果にエラーがないか確認
if grep -q "^Error:" ".outputs/terraform/plan-result.txt" 2>/dev/null; then
  feedback "terraform plan の結果にエラーがあります。エラーを修正してから再実行してください。

${FEEDBACK_MESSAGE}"
fi

# 4. tflint-result.txt が存在するか確認
if [ ! -f ".outputs/terraform/tflint-result.txt" ]; then
  feedback "$FEEDBACK_MESSAGE"
fi

# 5. tflint 結果にエラーがないか確認
if grep -qE "^(Error|ERROR)" ".outputs/terraform/tflint-result.txt" 2>/dev/null; then
  feedback "tflint の結果にエラーがあります。エラーを修正してから再実行してください。

${FEEDBACK_MESSAGE}"
fi

# 全チェック通過
exit 0
