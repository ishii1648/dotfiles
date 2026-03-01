#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="claude-code-sandbox"

# Project directory: argument or current directory
PROJECT_DIR="${1:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

# Build image if not exists
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "Building Docker image: $IMAGE_NAME ..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi

# Compose mount arguments
MOUNTS=(
    -v "$PROJECT_DIR:$PROJECT_DIR"
    -v "claude-code-local:/home/claude/.local"
    -v "$HOME/.claude:/home/claude/.claude"
    -v "$HOME/.ssh:/home/claude/.ssh-host:ro"
)

# Optional mounts (only if exist on host)
if [ -d "$HOME/.config/gh" ]; then
    MOUNTS+=(-v "$HOME/.config/gh:/home/claude/.config/gh")
fi
if [ -f "$HOME/.gitconfig" ]; then
    MOUNTS+=(-v "$HOME/.gitconfig:/home/claude/.gitconfig")
fi

# Run container
exec docker run --rm -it \
    "${MOUNTS[@]}" \
    -e HOST_WORKSPACE="$PROJECT_DIR" \
    -w "$PROJECT_DIR" \
    "$IMAGE_NAME" \
    claude --dangerously-skip-permissions
