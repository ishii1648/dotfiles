function __tmux_passthrough_off
    if set -q TMUX
        tmux set -u prefix \; set -u key-table \; set -u status \; set -u status-style \; set -u status-left \; refresh-client -S
    end
end
