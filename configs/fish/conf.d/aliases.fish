# Command aliases

abbr -a cat nyan
abbr -a g git
abbr -a k kubectl
abbr -a d docker
abbr -a t terraform
abbr -a gc gcloud
abbr -a a aws
abbr -a e eksctl
abbr -a python python3
abbr -a ic istioctl
abbr -a grep ggrep
abbr -a rgrep "grep -r"
abbr -a date gdate
abbr -a sed gsed
abbr -a n "nvim ."
abbr -a cc claude

# claude session 中に tmux window 名がバージョン番号になるのを防ぐ
function claude --wraps claude
    if set -q TMUX
        tmux set-option -w automatic-rename off
        tmux rename-window claude
    end
    command claude $argv
    if set -q TMUX
        tmux set-option -w automatic-rename on
    end
end
