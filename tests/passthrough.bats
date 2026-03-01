#!/usr/bin/env bats

# Layer 2: パススルーモード ON/OFF 状態遷移テスト

SOCK="test-passthrough-$$"

setup() {
  local tmux_conf="$HOME/.tmux.conf"
  [ -f "$tmux_conf" ] || tmux_conf="configs/tmux/tmux.conf"
  tmux -L "$SOCK" -f "$tmux_conf" new-session -d -s passthrough-test
}

teardown() {
  tmux -L "$SOCK" kill-server 2>/dev/null || true
}

@test "passthrough ON: prefix becomes None and key-table becomes off" {
  # パススルーモード ON を直接実行
  tmux -L "$SOCK" set prefix None \; set key-table off \; set status off

  local prefix
  prefix=$(tmux -L "$SOCK" show-option -v prefix)
  [ "$prefix" = "None" ]

  local keytable
  keytable=$(tmux -L "$SOCK" show-option -v key-table)
  [ "$keytable" = "off" ]
}

@test "passthrough OFF: prefix is restored" {
  # ON → OFF の遷移
  tmux -L "$SOCK" set prefix None \; set key-table off \; set status off
  tmux -L "$SOCK" set -u prefix \; set -u key-table \; set -u status \; set -u status-style \; set -u status-left

  local prefix
  prefix=$(tmux -L "$SOCK" show-option -gv prefix)
  [ "$prefix" = "C-Space" ]

  local keytable
  keytable=$(tmux -L "$SOCK" show-option -gv key-table)
  [ "$keytable" = "root" ]
}
