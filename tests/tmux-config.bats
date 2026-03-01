#!/usr/bin/env bats

# Layer 2: tmux 設定テスト（テスト専用ソケットで server 起動）

SOCK="test-sock-$$"

setup() {
  local tmux_conf="$HOME/.tmux.conf"
  [ -f "$tmux_conf" ] || tmux_conf="configs/tmux/tmux.conf"
  tmux -L "$SOCK" -f "$tmux_conf" new-session -d -s test-session
}

teardown() {
  tmux -L "$SOCK" kill-server 2>/dev/null || true
}

@test "prefix is C-Space" {
  local prefix
  prefix=$(tmux -L "$SOCK" show-option -gv prefix)
  [ "$prefix" = "C-Space" ]
}

@test "user-keys[0] through user-keys[12] are all set" {
  local missing=()
  for i in $(seq 0 12); do
    if ! tmux -L "$SOCK" show-option -sv "user-keys[$i]" >/dev/null 2>&1; then
      missing+=("user-keys[$i]")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    printf 'missing: %s\n' "${missing[@]}"
    return 1
  fi
}

@test "C-Tab and C-BTab window switch bindings exist" {
  local bindings
  bindings=$(tmux -L "$SOCK" list-keys)
  echo "$bindings" | grep -q "C-Tab"
  echo "$bindings" | grep -q "C-BTab"
}
