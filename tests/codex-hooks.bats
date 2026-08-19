#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CODEX_SETUP="$REPO_ROOT/configs/codex/setup.sh"
  HERDR_SETUP="$REPO_ROOT/configs/herdr/setup.sh"
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$FAKE_HOME/.codex" "$FAKE_HOME/.claude" "$STUB_BIN"

  printf '#!/bin/sh\nexit 0\n' >"$STUB_BIN/codex"
  printf '#!/bin/sh\nprintf "Linux\\n"\n' >"$STUB_BIN/uname"
  cat >"$STUB_BIN/herdr" <<'EOF'
#!/bin/sh
if [ "$1 $2" = "integration status" ]; then
  printf 'claude: current (v1)\ncodex: current (v1)\n'
fi
exit 0
EOF
  chmod +x "$STUB_BIN/codex" "$STUB_BIN/uname" "$STUB_BIN/herdr"
  TEST_PATH="$STUB_BIN:/usr/bin:/bin"
}

write_legacy_config() {
  cat >"$1" <<'EOF'
approval_policy = "on-request"

[[hooks.UserPromptSubmit]]
[[hooks.UserPromptSubmit.hooks]]
type = "command"
command = "~/.claude/scripts/agent-pane-state.sh running codex"

[[hooks.SessionEnd]]
[[hooks.SessionEnd.hooks]]
type = "command"
command = "/usr/bin/true"

[hooks.state]
[hooks.state."trusted"]
trusted_hash = "sha256:keep-me"
EOF
}

write_stale_herdr_hooks() {
  cat >"$1" <<'EOF'
{
  "hooks": {
    "SessionStart": [
      {"hooks":[{"command":"bash '/Users/old/.codex/herdr-agent-state.sh' session","timeout":10,"type":"command"}]},
      {"hooks":[{"command":"/usr/bin/true","type":"command"}]},
      {"hooks":[{"command":"bash '/Users/other/.codex/herdr-agent-state.sh' session","timeout":10,"type":"command"}]}
    ]
  }
}
EOF
}

@test "tracked Codex hook is a single portable herdr command" {
  local hooks="$REPO_ROOT/configs/codex/hooks.json"
  run jq -e '
    [.hooks.SessionStart[]?.hooks[]? | select((.command // "") | contains("herdr-agent-state.sh"))]
    | length == 1 and .[0].command == "~/.codex/herdr-agent-state.sh session"
  ' "$hooks"
  [ "$status" -eq 0 ]
  [[ "$(cat "$hooks")" != *"/Users/"* ]]
}

@test "codex setup removes only obsolete inline hook groups" {
  local config="$FAKE_HOME/.codex/config.toml"
  write_legacy_config "$config"

  run env HOME="$FAKE_HOME" PATH="$TEST_PATH" CODEX_CONFIG_DEST="$config" \
    CODEX_HOOKS_DEST="$FAKE_HOME/.codex/hooks.json" bash "$CODEX_SETUP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed obsolete agent-pane-state.sh hooks"* ]]
  ! grep -q 'agent-pane-state.sh' "$config"
  grep -q 'approval_policy = "on-request"' "$config"
  grep -q 'command = "/usr/bin/true"' "$config"
  grep -q 'trusted_hash = "sha256:keep-me"' "$config"
}

@test "codex setup dry-run reports obsolete hooks without writing" {
  local config="$FAKE_HOME/.codex/config.toml" before
  write_legacy_config "$config"
  before="$(cat "$config")"

  run env HOME="$FAKE_HOME" PATH="$TEST_PATH" CODEX_CONFIG_DEST="$config" \
    CODEX_HOOKS_DEST="$FAKE_HOME/.codex/hooks.json" bash "$CODEX_SETUP" --dry-run
  [ "$status" -eq 1 ]
  [[ "$output" == *"obsolete agent-pane-state.sh hooks found"* ]]
  [ "$(cat "$config")" = "$before" ]
}

@test "herdr setup normalizes stale Codex paths and preserves the symlink" {
  local source="$BATS_TEST_TMPDIR/hooks.json"
  write_stale_herdr_hooks "$source"
  ln -s "$source" "$FAKE_HOME/.codex/hooks.json"
  printf '{"hooks":{"SessionStart":[{"hooks":[{"command":"~/.claude/hooks/herdr-agent-state.sh session"}]}]}}\n' \
    >"$FAKE_HOME/.claude/settings.json"

  run env HOME="$FAKE_HOME" PATH="$TEST_PATH" \
    CODEX_HOOKS_FILE="$FAKE_HOME/.codex/hooks.json" bash "$HERDR_SETUP"
  [ "$status" -eq 0 ]
  [[ "$output" == *"normalized portable hook wiring"* ]]
  [ -L "$FAKE_HOME/.codex/hooks.json" ]
  run jq -e '
    [.hooks.SessionStart[]?.hooks[]? | select((.command // "") | contains("herdr-agent-state.sh"))]
    | length == 1 and .[0].command == "~/.codex/herdr-agent-state.sh session"
  ' "$source"
  [ "$status" -eq 0 ]
  run jq -e '[.hooks.SessionStart[]?.hooks[]? | select(.command == "/usr/bin/true")] | length == 1' "$source"
  [ "$status" -eq 0 ]
}
