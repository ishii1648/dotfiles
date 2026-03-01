#!/bin/sh
# tmux copy-pipe 用 OSC 52 クリップボードコピースクリプト
# tmux クライアントの TTY に直接 OSC 52 を送信する
buf=$(base64 | tr -d '\n')
tty=$(tmux display-message -p '#{client_tty}')
printf '\033]52;c;%s\a' "$buf" > "$tty"
