if status is-interactive
    # conf.d/ の設定ファイルが自動的に読み込まれます
end

set -x GPG_TTY (tty)
if not pgrep -x gpg-agent > /dev/null
    gpg-agent --daemon --enable-ssh-support
end

