function __tmux_passthrough_on
    if set -q TMUX
        tmux set prefix None \; set key-table off \; set status-style "bg=#444444" \; set status-left '#[fg=#f8f8f2,bold] [PASSTHROUGH] #S #[default]│ ' \; refresh-client -S
    end
end
