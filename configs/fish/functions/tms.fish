function tms --description "SSH先のtmuxセッションに接続"
    if test (count $argv) -lt 1
        echo "Usage: tms <host> [session-name]" >&2
        return 1
    end
    set -l host $argv[1]
    set -l session (test (count $argv) -ge 2; and echo $argv[2]; or echo "work")
    ssh $host -t "tmux new-session -A -s $session"
end
