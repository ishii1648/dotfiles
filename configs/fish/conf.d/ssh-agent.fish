# ssh-agent 自動起動（SSH セッション・Linux 環境向け）
# macOS GUI ログイン時は launchd の agent をそのまま使う

# 既存の agent が動作中ならそのまま使う
if ssh-add -l &>/dev/null; or test $status -eq 1
    return
end

# 固定ソケットで agent を共有（tmux ペイン間で増殖しない）
set -gx SSH_AUTH_SOCK "$HOME/.ssh/agent.sock"

# 固定ソケットの agent が生きていればそのまま使う
if ssh-add -l &>/dev/null; or test $status -eq 1
    return
end

# agent を新規起動
rm -f $SSH_AUTH_SOCK
eval (ssh-agent -c -a $SSH_AUTH_SOCK) >/dev/null
