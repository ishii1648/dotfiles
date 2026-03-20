#!/bin/bash
# PreToolUse hook: check-aws-auth-before-terraform.sh
# terraform MCP ツール実行前に AWS 認証（saml プロファイル）を確認する

# stdin から hook イベントを読み込む
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || true)

# terraform / helmfile MCP ツール以外はスキップ
case "$TOOL_NAME" in
  mcp__terraform__*|mcp__helmfile__*)
    ;;
  *)
    exit 0
    ;;
esac

# AWS 認証確認（saml プロファイルで sts:GetCallerIdentity を呼ぶ）
if aws sts get-caller-identity --profile saml > /dev/null 2>&1; then
  # 認証有効 - 通過
  exit 0
fi

# 認証切れまたは未設定 - block して aws-saml-login を促す
REASON="AWS 認証（saml プロファイル）が切れているか未設定です。
先に aws-saml-login skill を実行して認証を更新してから再試行してください。"

if command -v jq &>/dev/null; then
  jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
else
  python3 -c "import sys,json; print(json.dumps({'decision':'block','reason':sys.argv[1]}))" "$REASON"
fi
exit 1
