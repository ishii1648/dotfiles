#!/bin/bash
set -e

CLAUDE_UID=$(id -u claude)
CLAUDE_GID=$(id -g claude)

# 1. SSH keys: RO mount -> writable copy
if [ -d /home/claude/.ssh-host ]; then
    rm -rf /home/claude/.ssh
    cp -r /home/claude/.ssh-host /home/claude/.ssh
    chown -R claude:claude /home/claude/.ssh
    chmod 700 /home/claude/.ssh
    find /home/claude/.ssh -type f -exec chmod 600 {} \;
    # Ensure known_hosts and config are usable
    [ -f /home/claude/.ssh/known_hosts ] && chmod 644 /home/claude/.ssh/known_hosts
    # Strip macOS-only directives that cause errors on Linux
    if [ -f /home/claude/.ssh/config ]; then
        chmod 644 /home/claude/.ssh/config
        sed -i \
            -e '/^[[:space:]]*UseKeychain/d' \
            -e '/^[[:space:]]*AddKeysToAgent.*apple/Id' \
            /home/claude/.ssh/config
    fi
    # Ensure pub keys are readable
    find /home/claude/.ssh -name "*.pub" -exec chmod 644 {} \;
fi

# 2. .local volume ownership
if [ -d /home/claude/.local ]; then
    chown -R claude:claude /home/claude/.local
fi

# 3. Install Claude Code if not present
if ! su - claude -c "command -v claude" > /dev/null 2>&1; then
    echo "Installing Claude Code..."
    su - claude -c "curl -fsSL https://claude.ai/install.sh | bash"
fi

# 4. Fix ownership of .config/gh and .gitconfig
if [ -d /home/claude/.config/gh ]; then
    chown -R claude:claude /home/claude/.config/gh
fi
if [ -f /home/claude/.gitconfig ]; then
    chown claude:claude /home/claude/.gitconfig
fi

# 5. Fix ownership of .claude directory
if [ -d /home/claude/.claude ]; then
    chown -R claude:claude /home/claude/.claude
fi

# 6. Fix workspace directory ownership
if [ -n "$HOST_WORKSPACE" ] && [ -d "$HOST_WORKSPACE" ]; then
    chown -R claude:claude "$HOST_WORKSPACE"
fi

# 7. Drop privileges and exec CMD
exec setpriv --reuid=$CLAUDE_UID --regid=$CLAUDE_GID --init-groups "$@"
