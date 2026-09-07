#!/bin/bash
set -euo pipefail

DRY_RUN=false
case "${1:-}" in
    --dry-run) DRY_RUN=true ;;
    "") ;;
    *) echo "Usage: $0 [--dry-run]" >&2; exit 1 ;;
esac
[[ $# -le 1 ]] || exit 1
if [[ "$(uname)" != Darwin ]]; then
    echo "ghtkn agent setup requires macOS"
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/ghtkn/ghtkn.yaml"
if [[ ! -f "$CONFIG" ]]; then
    echo "Copy $SCRIPT_DIR/ghtkn.yaml.example to $CONFIG and fill in the three GitHub App Client IDs." >&2
    exit 1
fi
python3 - "$CONFIG" <<'PYTHON'
import sys
import yaml
with open(sys.argv[1]) as f:
    config = yaml.safe_load(f)
apps = config.get("apps", [])
if config.get("backend", {}).get("type") != "agent":
    sys.exit("ghtkn backend must be agent")
if {app.get("name") for app in apps} != {"read", "write", "loop"} or len(apps) != 3:
    sys.exit("ghtkn requires read, write, and loop apps")
ids = [app.get("client_id", "") for app in apps]
if any(not value or value.startswith("REPLACE_") for value in ids) or len(set(ids)) != 3:
    sys.exit("Set three distinct GitHub App Client IDs before activating ghtkn")
if any(app.get("git_owner") or app.get("git_owners") for app in apps):
    sys.exit("Use GHTKN_GIT_APP to select write/loop; git_owner overrides that selection")
PYTHON

GHTKN_BIN="$(aqua -c "$SCRIPT_DIR/../../aqua.yaml" which ghtkn)"
PLIST="$HOME/Library/LaunchAgents/com.user.ghtkn-agent.plist"
EXPECTED="$(mktemp)"
trap 'rm -f "$EXPECTED"' EXIT
python3 - "$GHTKN_BIN" "$EXPECTED" <<'PYTHON'
import os
import plistlib
import sys
with open(sys.argv[2], "wb") as f:
    plistlib.dump({
        "Label": "com.user.ghtkn-agent",
        "ProgramArguments": [sys.argv[1], "agent", "start"],
        "RunAtLoad": True,
        "KeepAlive": {"SuccessfulExit": False},
        "EnvironmentVariables": {"HOME": os.environ["HOME"], **{
            key: os.environ[key] for key in ("XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME", "XDG_RUNTIME_DIR")
            if key in os.environ}},
    }, f)
PYTHON

HELPER='!env -u GHTKN_GITHUB_TOKEN GHTKN_BACKEND=agent GHTKN_GIT_APP=${GHTKN_GIT_APP:-${GHTKN_APP:-write}} ghtkn git-credential'
if $DRY_RUN; then
    cmp -s "$EXPECTED" "$PLIST"
    [[ "$(readlink "$HOME/.local/bin/gh")" == "$SCRIPT_DIR/gh" ]]
    for cmd in gh git; do
        [[ "$(readlink "$HOME/.local/libexec/ghtkn-loop/$cmd")" == "$SCRIPT_DIR/loop-bin/$cmd" ]]
    done
    [[ "$(git config --global --get-all credential.https://github.com.helper)" == "
$HELPER" ]]
    [[ "$(git config --global --get credential.https://github.com.useHttpPath)" == true ]]
    if git config --global --get-all 'url.git@github.com:.insteadOf' | /usr/bin/grep -Fxq 'https://github.com/'; then
        exit 1
    fi
    launchctl print "gui/$(id -u)/com.user.ghtkn-agent" >/dev/null
    echo "ghtkn configuration: OK (authentication is checked separately with ghtkn info)"
    exit 0
fi

mkdir -p "$HOME/.local/bin" "$HOME/.local/libexec/ghtkn-loop" "$HOME/Library/LaunchAgents"
if [[ -e "$HOME/.local/bin/gh" && ! -L "$HOME/.local/bin/gh" ]]; then
    echo "Refusing to replace existing $HOME/.local/bin/gh" >&2
    exit 1
fi
ln -sfn "$SCRIPT_DIR/gh" "$HOME/.local/bin/gh"
for cmd in gh git; do
    ln -sfn "$SCRIPT_DIR/loop-bin/$cmd" "$HOME/.local/libexec/ghtkn-loop/$cmd"
done
git config --global --replace-all credential.https://github.com.helper ''
git config --global --add credential.https://github.com.helper "$HELPER"
git config --global credential.https://github.com.useHttpPath true
if git config --global --get-all 'url.git@github.com:.insteadOf' | /usr/bin/grep -Fxq 'https://github.com/'; then
    git config --global --unset-all 'url.git@github.com:.insteadOf' '^https://github[.]com/$'
fi
if ! cmp -s "$EXPECTED" "$PLIST"; then
    if launchctl print "gui/$(id -u)/com.user.ghtkn-agent" >/dev/null 2>&1; then
        launchctl bootout "gui/$(id -u)/com.user.ghtkn-agent"
    fi
    cp "$EXPECTED" "$PLIST"
fi
if ! launchctl print "gui/$(id -u)/com.user.ghtkn-agent" >/dev/null 2>&1; then
    launchctl bootstrap "gui/$(id -u)" "$PLIST"
fi
echo "Run ghtkn agent unlock --enable-refresh, then ghtkn auth read / write / loop as needed."
echo "Register loop repositories with $HOME/.local/libexec/ghtkn-loop first on PATH."
