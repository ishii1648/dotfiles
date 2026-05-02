#!/bin/bash
# ADR: 063
# Purpose: ADR-063 以前の settings.json から呼び出される下位互換シム（agent-pane-state.sh に転送）
# Backwards-compat shim: translates pre-ADR-063 calls
#   claude-pane-state.sh <state> [source]
# into the new
#   agent-pane-state.sh <state> claude [source]
# Allows Claude Code sessions still running with the pre-sync
# settings.json to keep emitting pane-state without errors.
exec "$(dirname "$0")/agent-pane-state.sh" "${1:-}" "claude" "${2:-}"
