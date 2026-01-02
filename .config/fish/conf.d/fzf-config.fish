# FZF custom configuration

if status is-interactive
    set fzf_fd_opts --hidden --max-depth 5
    fzf_configure_bindings --directory=\cf --git_log=\cl
end
