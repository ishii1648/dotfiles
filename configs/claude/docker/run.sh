#!/bin/bash
set -e

IMAGE_NAME="claude-code-sandbox"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Project directory: argument or current directory
PROJECT_DIR="${1:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Snapshot ~/.claude.json to avoid race condition: host Claude may write this file
# while the container reads it via bind mount, causing invalid JSON errors.
CLAUDE_JSON_COPY="$HOME/.claude.json.sandbox-copy"
cp "$HOME/.claude.json" "$CLAUDE_JSON_COPY"

# Compose mount arguments
MOUNTS=(
    -v "$PROJECT_DIR:$PROJECT_DIR"
    -v "claude-code-local:/home/claude/.local"
    -v "$HOME/.claude:/home/claude/.claude"
    -v "$SCRIPT_DIR/sandbox-settings.json:/home/claude/.claude/settings.json:ro"
    -v "$HOME/.claude/scripts:/home/claude/.claude/scripts:ro"
    -v "$HOME/.ssh:/home/claude/.ssh-host:ro"
    -v "$CLAUDE_JSON_COPY:/home/claude/.claude.json"
)

# Optional mounts (only if exist on host)
if [ -d "$HOME/.config/gh" ]; then
    MOUNTS+=(-v "$HOME/.config/gh:/home/claude/.config/gh:ro")
fi
if [ -f "$HOME/.gitconfig" ]; then
    MOUNTS+=(-v "$HOME/.gitconfig:/home/claude/.gitconfig:ro")
fi

# Run container interactively inside the colima VM via SSH with forced PTY (-t).
#
# Background:
#   docker run -it via the colima socket relay doesn't propagate raw mode,
#   so Claude's TUI freezes (can render but can't receive keystrokes).
#   colima ssh (= limactl shell) doesn't allocate a PTY for command execution,
#   so docker inside the VM also can't receive keystrokes.
#
# Fix: use ssh -t directly against colima's SSH endpoint to force PTY
#   allocation in the VM. This gives docker a real PTY that properly handles
#   raw mode input even when the caller is already inside an SSH session.
#
# Serialize all args with printf %q so they survive the SSH shell round-trip.
COLIMA_SSH_CONFIG="$HOME/.colima/ssh_config"
DOCKER_CMD=$(printf '%q ' \
    docker run --rm -it \
    -e "TERM=${TERM:-xterm-256color}" \
    "${MOUNTS[@]}" \
    -e "HOST_WORKSPACE=$PROJECT_DIR" \
    -w "$PROJECT_DIR" \
    "$IMAGE_NAME" \
    claude --dangerously-skip-permissions)
ssh -t -o BatchMode=no -F "$COLIMA_SSH_CONFIG" colima "exec $DOCKER_CMD"
rm -f "$CLAUDE_JSON_COPY"
