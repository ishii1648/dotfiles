function tms --description "SSH先のtmuxセッションに接続"
    if test (count $argv) -lt 1
        echo "Usage: tms <host> [session-name]" >&2
        return 1
    end
    set -l host $argv[1]
    set -l session (test (count $argv) -ge 2; and echo $argv[2]; or echo "work")

    # tmux 内であればパススルーモードに切り替え
    if set -q TMUX
        tmux set prefix None \; set key-table off \; set status-style "bg=#444444" \; refresh-client -S
    end

    ssh $host -t "tmux new-session -A -s $session"

    # SSH 終了後にパススルーモードを解除
    if set -q TMUX
        tmux set -u prefix \; set -u key-table \; set -u status-style \; refresh-client -S
    end
end
