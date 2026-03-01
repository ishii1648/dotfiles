function __tmux_passthrough_on
    if set -q TMUX
        tmux set prefix None \; set key-table off \; set status off \; refresh-client -S
    end
end
