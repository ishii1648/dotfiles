# ssh-agent 自動起動（SSH セッション・Linux 環境向け）
# macOS GUI ログイン時は launchd の agent をそのまま使う

# 既存の agent が動作中ならそのまま使う
if ssh-add -l &>/dev/null; or test $status -eq 1
    return
end

# 固定ソケットで agent を共有（ペイン間で増殖しない）
set -gx SSH_AUTH_SOCK "$HOME/.ssh/agent.sock"

# 固定ソケットの agent が生きていればそのまま使う
if ssh-add -l &>/dev/null; or test $status -eq 1
    return
end

# 非対話 shell（Codex sandbox 等）では agent を起動しない。
# sandbox は socket の unlink / bind を拒否するため、eval に不完全な出力が渡って parse error が連鎖する。
# SSH_AUTH_SOCK の固定 socket への差し替えは上で済んでいるので、ここで抜けても署名は通る。
if not status is-interactive
    return
end

# agent を新規起動
rm -f $SSH_AUTH_SOCK
eval (ssh-agent -c -a $SSH_AUTH_SOCK) >/dev/null

# 起動直後の agent は鍵を 1 本も持たないため、Keychain から読み込んでおく。
# これが無いと git の SSH 署名が「鍵なし」で失敗する（~/.ssh/config は UseKeychain yes）。
ssh-add --apple-load-keychain &>/dev/null
