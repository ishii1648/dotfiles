if status is-interactive
    # conf.d/ の設定ファイルが自動的に読み込まれます
    stty -ixon
    command -q zoxide && zoxide init fish | source
end

# opencode
fish_add_path /Users/sho/.opencode/bin

