#!/bin/bash
# GitHub SSH 鍵セットアップスクリプト
#
# 環境変数:
#   SETUP_AUTH_KEY  - SSH 認証鍵のパス（例: ~/.ssh/private_ed25519_github）
#   SETUP_SIGN_KEY  - SSH 署名鍵のパス（例: ~/.ssh/private_ed25519_github_sign）
#   SETUP_USER_NAME - Git ユーザー名（例: Your Name）
#   SETUP_USER_EMAIL - Git メールアドレス（例: your_email@example.com）
#
# 使い方:
#   bash setup-github-ssh.sh [--dry-run]

set -euo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# ~ を $HOME に展開
SETUP_AUTH_KEY="${SETUP_AUTH_KEY:-}"
SETUP_AUTH_KEY="${SETUP_AUTH_KEY/#\~/$HOME}"
SETUP_SIGN_KEY="${SETUP_SIGN_KEY:-}"
SETUP_SIGN_KEY="${SETUP_SIGN_KEY/#\~/$HOME}"

# 環境変数チェック
if [[ -z "${SETUP_AUTH_KEY:-}" ]]; then
    echo -e "  ${YELLOW}WARN${NC}: SETUP_AUTH_KEY is not set, skipping SSH setup"
    exit 0
fi

if [[ -z "${SETUP_SIGN_KEY:-}" ]]; then
    echo -e "  ${YELLOW}WARN${NC}: SETUP_SIGN_KEY is not set, skipping SSH setup"
    exit 0
fi

# Step 0: Git ユーザー情報を設定
if [[ -n "${SETUP_USER_NAME:-}" && -n "${SETUP_USER_EMAIL:-}" ]]; then
    echo -e "  ${GREEN}Step 0${NC}: user.name / user.email"
    if $DRY_RUN; then
        echo -e "  Would run: git config --global user.name \"$SETUP_USER_NAME\""
        echo -e "  Would run: git config --global user.email \"$SETUP_USER_EMAIL\""
    else
        git config --global user.name "$SETUP_USER_NAME"
        git config --global user.email "$SETUP_USER_EMAIL"
        echo -e "  ${GREEN}✓${NC} Set user.name=$SETUP_USER_NAME, user.email=$SETUP_USER_EMAIL"
    fi
fi

# Step 1: ~/.ssh/config に GitHub Host 設定を追加
echo -e "  ${GREEN}Step 1${NC}: ~/.ssh/config"
SSH_CONFIG="$HOME/.ssh/config"
if grep -q "^Host github.com" "$SSH_CONFIG" 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Host github.com already configured"
else
    if $DRY_RUN; then
        echo -e "  Would add to $SSH_CONFIG:"
        echo "    Host github.com"
        echo "      HostName github.com"
        echo "      IdentityFile $SETUP_AUTH_KEY"
        echo "      User git"
        echo "      AddKeysToAgent yes"
        echo "      UseKeychain yes"
    else
        mkdir -p "$HOME/.ssh"
        cat >> "$SSH_CONFIG" <<EOF

Host github.com
  HostName github.com
  IdentityFile $SETUP_AUTH_KEY
  User git
  AddKeysToAgent yes
  UseKeychain yes
EOF
        chmod 600 "$SSH_CONFIG"
        echo -e "  ${GREEN}✓${NC} Added Host github.com to $SSH_CONFIG"
    fi
fi

# Step 2: ~/.gitconfig に user.signingkey を設定
echo -e "  ${GREEN}Step 2${NC}: user.signingkey"
if $DRY_RUN; then
    echo -e "  Would run: git config --global user.signingkey ${SETUP_SIGN_KEY}.pub"
else
    git config --global user.signingkey "${SETUP_SIGN_KEY}.pub"
    echo -e "  ${GREEN}✓${NC} Set user.signingkey to ${SETUP_SIGN_KEY}.pub"
fi

# Step 3: ssh-agent + Keychain に鍵を登録
echo -e "  ${GREEN}Step 3${NC}: ssh-add"
if $DRY_RUN; then
    echo -e "  Would run: ssh-add --apple-use-keychain $SETUP_AUTH_KEY"
    echo -e "  Would run: ssh-add --apple-use-keychain $SETUP_SIGN_KEY"
else
    if [[ -f "$SETUP_AUTH_KEY" ]]; then
        ssh-add --apple-use-keychain "$SETUP_AUTH_KEY"
        echo -e "  ${GREEN}✓${NC} Added $SETUP_AUTH_KEY to keychain"
    else
        echo -e "  ${YELLOW}WARN${NC}: $SETUP_AUTH_KEY not found, skipping ssh-add"
    fi
    if [[ -f "$SETUP_SIGN_KEY" ]]; then
        ssh-add --apple-use-keychain "$SETUP_SIGN_KEY"
        echo -e "  ${GREEN}✓${NC} Added $SETUP_SIGN_KEY to keychain"
    else
        echo -e "  ${YELLOW}WARN${NC}: $SETUP_SIGN_KEY not found, skipping ssh-add"
    fi
fi

# Step 4: 接続テスト
echo -e "  ${GREEN}Step 4${NC}: connection test"
if $DRY_RUN; then
    echo -e "  Would run: ssh -T git@github.com"
else
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo -e "  ${GREEN}✓${NC} SSH connection to GitHub OK"
    else
        echo -e "  ${YELLOW}WARN${NC}: SSH connection test returned non-zero (this is normal if key is not yet registered on GitHub)"
    fi
fi
