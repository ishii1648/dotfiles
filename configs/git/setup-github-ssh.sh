#!/bin/bash
# GitHub SSH 鍵セットアップスクリプト
#
# 環境変数:
#   SETUP_AUTH_KEY  - SSH 認証鍵のパス（例: ~/.ssh/private_ed25519_github）
#   SETUP_SIGN_KEY  - SSH 署名鍵のパス（例: ~/.ssh/private_ed25519_github_sign）
#   SETUP_USER_NAME - Git ユーザー名（例: Your Name）
#   SETUP_USER_EMAIL - Git メールアドレス（例: your_email@example.com）
#   SETUP_GHQ_ROOT  - ghq root パス（例: ~/src）
#
# 使い方:
#   bash setup-github-ssh.sh [--dry-run]

set -uo pipefail

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# SETUP_INTERACTIVE 環境変数を読み取り（デフォルト: true）
SETUP_INTERACTIVE="${SETUP_INTERACTIVE:-true}"

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

ERRORS=0

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

# Step 1: ghq.root を設定
echo -e "  Step 1: ghq.root"
if [[ -n "${SETUP_GHQ_ROOT:-}" ]]; then
    GHQ_ROOT="${SETUP_GHQ_ROOT/#\~/$HOME}"
    if $DRY_RUN; then
        echo -e "    Would run: git config --global ghq.root $GHQ_ROOT"
    else
        if git config --global ghq.root "$GHQ_ROOT"; then
            echo -e "    ${GREEN}✓${NC} ghq.root=$GHQ_ROOT"
        else
            echo -e "    ${RED}FAIL${NC} git config --global ghq.root failed"
            ((ERRORS++))
        fi
    fi
else
    echo -e "    ${YELLOW}SKIP${NC} SETUP_GHQ_ROOT is not set"
fi

# Step 2: Git ユーザー情報を設定
if [[ -n "${SETUP_USER_NAME:-}" && -n "${SETUP_USER_EMAIL:-}" ]]; then
    echo -e "  Step 2: user.name / user.email"
    if $DRY_RUN; then
        echo -e "    Would run: git config --global user.name \"$SETUP_USER_NAME\""
        echo -e "    Would run: git config --global user.email \"$SETUP_USER_EMAIL\""
    else
        if git config --global user.name "$SETUP_USER_NAME" && \
           git config --global user.email "$SETUP_USER_EMAIL"; then
            echo -e "    ${GREEN}✓${NC} user.name=$SETUP_USER_NAME, user.email=$SETUP_USER_EMAIL"
        else
            echo -e "    ${RED}FAIL${NC} git config --global user.name/user.email failed"
            ((ERRORS++))
        fi
    fi
else
    echo -e "  Step 2: user.name / user.email"
    echo -e "    ${YELLOW}SKIP${NC} SETUP_USER_NAME or SETUP_USER_EMAIL is not set"
fi

# Step 3: ~/.ssh/config に GitHub Host 設定を追加
echo -e "  Step 3: ~/.ssh/config"
SSH_CONFIG="$HOME/.ssh/config"
if grep -q "^Host github.com" "$SSH_CONFIG" 2>/dev/null; then
    echo -e "    ${GREEN}✓${NC} Host github.com already configured"
else
    # macOS のみ UseKeychain を追加
    MACOS_LINES=""
    if [[ "$(uname -s)" == "Darwin" ]]; then
        MACOS_LINES=$'\n  UseKeychain yes'
    fi

    if $DRY_RUN; then
        echo -e "    Would add to $SSH_CONFIG:"
        echo "      Host github.com"
        echo "        HostName github.com"
        echo "        IdentityFile $SETUP_AUTH_KEY"
        echo "        User git"
        echo "        AddKeysToAgent yes"
        [[ -n "$MACOS_LINES" ]] && echo "        UseKeychain yes"
    else
        mkdir -p "$HOME/.ssh"
        if cat >> "$SSH_CONFIG" <<EOF

Host github.com
  HostName github.com
  IdentityFile $SETUP_AUTH_KEY
  User git
  AddKeysToAgent yes${MACOS_LINES}
EOF
        then
            chmod 600 "$SSH_CONFIG"
            echo -e "    ${GREEN}✓${NC} Added Host github.com to $SSH_CONFIG"
        else
            echo -e "    ${RED}FAIL${NC} Could not write to $SSH_CONFIG"
            ((ERRORS++))
        fi
    fi
fi

# Step 4: ~/.gitconfig に user.signingkey を設定
echo -e "  Step 4: user.signingkey"
if [[ "$SETUP_SIGN_KEY" == *.pub ]]; then
    SIGN_PUBKEY="$SETUP_SIGN_KEY"
else
    SIGN_PUBKEY="${SETUP_SIGN_KEY}.pub"
fi
if $DRY_RUN; then
    echo -e "    Would run: git config --global user.signingkey $SIGN_PUBKEY"
else
    if git config --global user.signingkey "$SIGN_PUBKEY"; then
        echo -e "    ${GREEN}✓${NC} user.signingkey=$SIGN_PUBKEY"
    else
        echo -e "    ${RED}FAIL${NC} git config --global user.signingkey failed"
        ((ERRORS++))
    fi
fi

# Step 5: 鍵ファイルの存在確認
echo -e "  Step 5: key files"
for key in "$SETUP_AUTH_KEY" "$SETUP_SIGN_KEY"; do
    if [[ -f "$key" ]]; then
        echo -e "    ${GREEN}✓${NC} $key"
    else
        echo -e "    ${RED}FAIL${NC} $key not found"
        ((ERRORS++))
    fi
done
if [[ "$SETUP_INTERACTIVE" == "false" ]]; then
    echo -e "    ${YELLOW}SKIP${NC} ssh-add (non-interactive mode)"
    echo -e "    ${YELLOW}TIP${NC}  初回のみ手動で実行: ssh-add $SETUP_AUTH_KEY && ssh-add $SETUP_SIGN_KEY"
elif ! ssh-add -l &>/dev/null 2>&1; then
    echo -e "    ${YELLOW}NOTE${NC} ssh-agent 未起動のため ssh-add はスキップ"
    echo -e "    ${YELLOW}TIP${NC}  fish conf.d/ssh-agent.fish が agent を自動起動します"
    echo -e "    ${YELLOW}TIP${NC}  初回のみ手動で実行: ssh-add $SETUP_AUTH_KEY && ssh-add $SETUP_SIGN_KEY"
fi

# Step 6: 接続テスト
echo -e "  Step 6: connection test"
if $DRY_RUN; then
    echo -e "    Would run: ssh -T git@github.com"
else
    SSH_OPTS=()
    if [[ "$SETUP_INTERACTIVE" == "false" ]]; then
        SSH_OPTS+=(-o "StrictHostKeyChecking=accept-new")
    fi
    if ssh "${SSH_OPTS[@]}" -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo -e "    ${GREEN}✓${NC} SSH connection to GitHub OK"
    else
        echo -e "    ${YELLOW}WARN${NC} SSH connection test failed (key may not be registered on GitHub yet)"
    fi
fi

# 結果サマリ
if [[ $ERRORS -gt 0 ]]; then
    echo -e "  ${RED}$ERRORS error(s)${NC} in git setup"
    exit 1
fi
