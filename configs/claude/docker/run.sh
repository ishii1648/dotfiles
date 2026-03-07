#!/bin/bash
set -e

IMAGE_NAME="claude-code-sandbox"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Project directory: argument or current directory
PROJECT_DIR="${1:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Compose mount arguments
MOUNTS=(
    -v "$PROJECT_DIR:$PROJECT_DIR"
    -v "claude-code-local:/home/claude/.local"
    -v "$HOME/.claude:/home/claude/.claude"
    -v "$SCRIPT_DIR/sandbox-settings.json:/home/claude/.claude/settings.json:ro"
    -v "$HOME/.claude/scripts:/home/claude/.claude/scripts:ro"
    -v "$HOME/.ssh:/home/claude/.ssh-host:ro"
    -v "$HOME/.claude.json:/home/claude/.claude.json:ro"
)

# Optional mounts (only if exist on host)
if [ -d "$HOME/.config/gh" ]; then
    MOUNTS+=(-v "$HOME/.config/gh:/home/claude/.config/gh:ro")
fi
if [ -f "$HOME/.gitconfig" ]; then
    MOUNTS+=(-v "$HOME/.gitconfig:/home/claude/.gitconfig:ro")
fi

# Run container interactively
# entrypoint.sh drops privileges to claude user via setpriv before running claude
exec docker run --rm -it \
    -e TERM="${TERM:-xterm-256color}" \
    "${MOUNTS[@]}" \
    -e HOST_WORKSPACE="$PROJECT_DIR" \
    -w "$PROJECT_DIR" \
    "$IMAGE_NAME" \
    claude
