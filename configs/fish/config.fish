if status is-interactive
    # conf.d/ の設定ファイルが自動的に読み込まれます
    stty -ixon
    zoxide init fish | source
end
