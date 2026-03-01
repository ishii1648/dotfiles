#!/usr/bin/env bats

# Layer 2: tmux popup リグレッションテスト
# $TMUX 変数ネスト・ソケット管理・Fish 関数実行など壊れやすいパターンを検証
#
# NOTE: display-popup は接続済みクライアントが必要なため、CI（ヘッドレス環境）では
# popup 内部で実行されるコマンドパターンを直接再現してテストする。

SOCK="test-popup-$$"

setup() {
  local tmux_conf="$HOME/.tmux.conf"
  [ -f "$tmux_conf" ] || tmux_conf="configs/tmux/tmux.conf"
  tmux -L "$SOCK" -f "$tmux_conf" new-session -d -s popup-test
}

teardown() {
  tmux -L "$SOCK" kill-server 2>/dev/null || true
}

@test "TMUX variable clear allows nested tmux command execution" {
  # popup 相当の環境: $TMUX が設定済みでも TMUX= で tmux コマンドが成功する
  local sock_path
  sock_path=$(tmux -L "$SOCK" display-message -p '#{socket_path}')

  # TMUX 変数を設定した状態で TMUX= クリアパターンが動作する
  TMUX="${sock_path},12345,0" TMUX= tmux -S "$sock_path" list-sessions

  # prtrack-popup.sh の ${TMUX%%,*} パターンでソケットパス抽出を検証
  local fake_tmux="${sock_path},12345,0"
  local extracted="${fake_tmux%%,*}"
  [ "$extracted" = "$sock_path" ]
}

@test "fish command execution in popup context" {
  # popup 内で実行される Fish コマンドパターンを再現
  # display-popup -E は内部的に TMUX= でシェルを起動するため、同等のパターンをテスト
  local sock_path
  sock_path=$(tmux -L "$SOCK" display-message -p '#{socket_path}')

  run fish -c 'echo popup-ok'
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "popup-ok"

  # popup 内から TMUX= で tmux コマンドを呼ぶパターン（prtrack-popup.sh と同じ）
  run env TMUX= tmux -S "$sock_path" list-sessions
  [ "$status" -eq 0 ]
}

@test "prtrack-popup.sh socket extraction and session creation" {
  # ソケットパスを取得
  local sock_path
  sock_path=$(tmux -L "$SOCK" display-message -p '#{socket_path}')

  # ${TMUX%%,*} パターンの検証
  local fake_tmux="${sock_path},12345,0"
  local extracted="${fake_tmux%%,*}"
  [ "$extracted" = "$sock_path" ]

  # prtrack-popup.sh のセッション作成フローを再現
  # has-session が失敗 → new-session で作成
  if ! TMUX= tmux -S "$sock_path" has-session -t prtrack-test 2>/dev/null; then
    TMUX= tmux -S "$sock_path" new-session -d -s prtrack-test 'sleep 10'
  fi
  TMUX= tmux -S "$sock_path" has-session -t prtrack-test
}

@test "popup exit does not affect host session" {
  # popup は別セッション/ウィンドウで動作する。正常・異常終了後もホスト側が生存することを検証
  local sock_path
  sock_path=$(tmux -L "$SOCK" display-message -p '#{socket_path}')

  # popup 相当の別セッションを作成して正常終了
  TMUX= tmux -S "$sock_path" new-session -d -s popup-child-ok 'exit 0'
  # 子セッションは即終了するが、ホスト側セッションは生存
  tmux -L "$SOCK" has-session -t popup-test

  # popup 相当の別セッションを作成して異常終了
  TMUX= tmux -S "$sock_path" new-session -d -s popup-child-fail 'exit 1'
  # 子セッションが異常終了しても、ホスト側セッションは生存
  tmux -L "$SOCK" has-session -t popup-test
}
