#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PYTHONPATH="$(python3 -c 'import pathlib, yaml; print(pathlib.Path(yaml.__file__).parent.parent)')"
  export HOME="$BATS_TEST_TMPDIR/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export STUB_BIN="$BATS_TEST_TMPDIR/bin"
  export CALLS="$BATS_TEST_TMPDIR/calls"
  mkdir -p "$HOME" "$STUB_BIN"
  export PATH="$STUB_BIN:$PATH"
  printf '#!/bin/sh\nprintf Darwin' > "$STUB_BIN/uname"
  chmod +x "$STUB_BIN/uname"
  unset GHTKN_APP GHTKN_GIT_APP GH_TOKEN GITHUB_TOKEN GHTKN_GITHUB_TOKEN
  cat > "$STUB_BIN/ghtkn" <<'STUB'
#!/bin/bash
[[ -z "${GH_TOKEN:-}${GITHUB_TOKEN:-}${GHTKN_GITHUB_TOKEN:-}" ]] || exit 90
[[ "$GHTKN_BACKEND" == agent ]] || exit 91
printf '%s\n' "$@" >> "$CALLS"
[[ "${FAIL_AUTH:-0}" == 0 ]] || exit 111
[[ "$1 $2" == 'exec -e' ]] || exit 92
shift 4
export GH_TOKEN=synthetic-app-token
exec "$@"
STUB
  cat > "$STUB_BIN/aqua" <<'STUB'
#!/bin/bash
if [[ "$3 $4" == 'which ghtkn' ]]; then
  printf '%s\n' "$STUB_BIN/ghtkn"
  exit
fi
[[ "$3 $4 $5" == 'exec -- gh' ]] || exit 93
printf 'aqua-called\n' >> "$CALLS"
if [[ "${6:-}" != --version ]]; then
  [[ "$GH_TOKEN" == synthetic-app-token ]] || exit 94
fi
printf '%s\n' "$@" >> "$CALLS"
exit "${GH_EXIT:-0}"
STUB
  chmod +x "$STUB_BIN/ghtkn" "$STUB_BIN/aqua"
}

@test "gh uses read by default, replaces inherited credentials, and preserves arguments and status" {
  export GH_TOKEN=legacy GITHUB_TOKEN=legacy GHTKN_GITHUB_TOKEN=legacy GH_EXIT=7
  run "$REPO_ROOT/configs/ghtkn/gh" issue view 'argument with spaces'
  [ "$status" -eq 7 ]
  /usr/bin/grep -Fxq 'GH_TOKEN:read' "$CALLS"
  /usr/bin/grep -Fxq 'argument with spaces' "$CALLS"
}

@test "gh gets a token for every invocation and supports explicit write app" {
  export GHTKN_APP=write
  "$REPO_ROOT/configs/ghtkn/gh" repo view
  "$REPO_ROOT/configs/ghtkn/gh" repo view
  [ "$(/usr/bin/grep -Fxc 'GH_TOKEN:write' "$CALLS")" -eq 2 ]
}

@test "failed token acquisition never starts gh even with legacy tokens" {
  export FAIL_AUTH=1 GH_TOKEN=legacy GITHUB_TOKEN=legacy GHTKN_GITHUB_TOKEN=legacy
  run "$REPO_ROOT/configs/ghtkn/gh" issue list
  [ "$status" -eq 111 ]
  if /usr/bin/grep -Fxq aqua-called "$CALLS"; then return 1; fi
  [ -z "$output" ]
}

@test "loop gh selects loop even when caller selects write" {
  mkdir -p "$HOME/.local/bin"
  ln -s "$REPO_ROOT/configs/ghtkn/gh" "$HOME/.local/bin/gh"
  export GHTKN_APP=write
  run "$REPO_ROOT/configs/ghtkn/loop-bin/gh" issue list
  [ "$status" -eq 0 ]
  /usr/bin/grep -Fxq 'GH_TOKEN:loop' "$CALLS"
}

@test "setup refuses incomplete app configuration before changing authentication" {
  mkdir -p "$XDG_CONFIG_HOME/ghtkn"
  cp "$REPO_ROOT/configs/ghtkn/ghtkn.yaml.example" "$XDG_CONFIG_HOME/ghtkn/ghtkn.yaml"
  run bash "$REPO_ROOT/configs/ghtkn/setup.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *'Client IDs'* ]]
  [ ! -e "$HOME/.local/bin/gh" ]
  [ ! -e "$HOME/.gitconfig" ]
}

@test "setup preserves unrelated git settings and does not restart unchanged agent" {
  mkdir -p "$XDG_CONFIG_HOME/ghtkn"
  sed 's/REPLACE_WITH_READ_APP_CLIENT_ID/test-read/; s/REPLACE_WITH_WRITE_APP_CLIENT_ID/test-write/; s/REPLACE_WITH_LOOP_APP_CLIENT_ID/test-loop/' \
    "$REPO_ROOT/configs/ghtkn/ghtkn.yaml.example" > "$XDG_CONFIG_HOME/ghtkn/ghtkn.yaml"
  cat > "$STUB_BIN/launchctl" <<'STUB'
#!/bin/bash
case "$1" in
  print) [[ -e "$HOME/loaded" ]] ;;
  bootstrap) touch "$HOME/loaded"; echo bootstrap >> "$CALLS" ;;
  bootout) rm "$HOME/loaded"; echo bootout >> "$CALLS" ;;
  *) exit 95 ;;
esac
STUB
  chmod +x "$STUB_BIN/launchctl"
  git config --global user.email example@example.invalid
  git config --global credential.helper osxkeychain
  git config --global 'url.git@github.com:.insteadOf' https://github.com/
  git config --global --add 'url.git@github.com:.insteadOf' https://example.invalid/
  bash "$REPO_ROOT/configs/ghtkn/setup.sh"
  bash "$REPO_ROOT/configs/ghtkn/setup.sh"
  bash "$REPO_ROOT/configs/ghtkn/setup.sh" --dry-run
  [ "$(git config --global user.email)" == example@example.invalid ]
  [ "$(git config --global credential.helper)" == osxkeychain ]
  [ "$(git config --global 'url.git@github.com:.insteadOf')" == https://example.invalid/ ]
  [ "$(/usr/bin/grep -Fxc bootstrap "$CALLS")" -eq 1 ]
  if /usr/bin/grep -Fxq bootout "$CALLS"; then return 1; fi
  python3 - "$HOME/Library/LaunchAgents/com.user.ghtkn-agent.plist" <<'CHECK'
import plistlib, sys
with open(sys.argv[1], 'rb') as f:
    config = plistlib.load(f)
assert config['KeepAlive'] == {'SuccessfulExit': False}
assert config['ProgramArguments'][1:] == ['agent', 'start']
CHECK
  cat > "$STUB_BIN/ghtkn" <<'STUB'
#!/bin/bash
[[ -z "${GHTKN_GITHUB_TOKEN:-}" && "$GHTKN_BACKEND" == agent ]] || exit 96
[[ "$1 $2" == 'git-credential get' ]] || exit 97
printf '%s\n' "$GHTKN_GIT_APP" >> "$CALLS"
printf 'username=test\npassword=synthetic-app-token\n'
STUB
  export GHTKN_GITHUB_TOKEN=legacy
  run bash -c 'printf "protocol=https\nhost=github.com\npath=owner/repo.git\n\n" | git credential fill'
  [ "$status" -eq 0 ]
  /usr/bin/grep -Fxq write "$CALLS"
  run bash -c 'printf "protocol=https\nhost=github.com\npath=owner/repo.git\n\n" | "$1" credential fill' -- "$REPO_ROOT/configs/ghtkn/loop-bin/git"
  [ "$status" -eq 0 ]
  /usr/bin/grep -Fxq loop "$CALLS"
}

@test "version probe works while locked without falling back for API commands" {
  export FAIL_AUTH=1
  run "$REPO_ROOT/configs/ghtkn/gh" --version
  [ "$status" -eq 0 ]
  if /usr/bin/grep -Fq "GH_TOKEN:" "$CALLS"; then return 1; fi
  run "$REPO_ROOT/configs/ghtkn/gh" --version issue list
  [ "$status" -eq 111 ]
}
