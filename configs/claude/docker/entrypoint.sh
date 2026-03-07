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
    [ -f /home/claude/.ssh/config ] && chmod 644 /home/claude/.ssh/config
    # Ensure pub keys are readable
    find /home/claude/.ssh -name "*.pub" -exec chmod 644 {} \;
fi

# 2. Fix ownership
[ -d /home/claude/.local ] && chown -R claude:claude /home/claude/.local
if [ -d /home/claude/.claude ]; then
    find /home/claude/.claude -writable -exec chown claude:claude {} +
fi
# 3. Fix workspace directory ownership
if [ -n "$HOST_WORKSPACE" ] && [ -d "$HOST_WORKSPACE" ]; then
    chown -R claude:claude "$HOST_WORKSPACE"
fi

# 4. Drop privileges and exec CMD
exec setpriv --reuid=$CLAUDE_UID --regid=$CLAUDE_GID --init-groups "$@"
