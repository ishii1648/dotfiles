function ssh --description "SSH接続（インタラクティブ時はリモートtmuxに自動アタッチ）" --wraps ssh
    # --no-tmux フラグの検出と除去
    set -l no_tmux false
    set -l ssh_args
    for arg in $argv
        if test "$arg" = --no-tmux
            set no_tmux true
        else
            set -a ssh_args $arg
        end
    end

    # 非インタラクティブ or --no-tmux → 素の ssh
    if test "$no_tmux" = true; or not isatty stdin
        command ssh $ssh_args
        return $status
    end

    # リモートコマンドが指定されているか判定
    # ssh のオプション引数（値を取るもの）をスキップしてホスト名以降を解析
    set -l has_remote_cmd false
    set -l skip_next false
    set -l found_host false
    for arg in $ssh_args
        if test "$skip_next" = true
            set skip_next false
            continue
        end
        # 値を取るオプション
        switch $arg
            case -p -i -l -L -R -D -o -J -F -W -b -c -e -m -O -Q -S -w -E -B
                set skip_next true
                continue
            case '-*'
                continue
        end
        if test "$found_host" = true
            # ホスト名の後に引数がある → リモートコマンド
            set has_remote_cmd true
            break
        end
        set found_host true
    end

    # リモートコマンドありまたは -t 指定済み → 素の ssh
    if test "$has_remote_cmd" = true
        command ssh $ssh_args
        return $status
    end

    # インタラクティブ SSH: パススルーモード + tmux 自動アタッチ
    # リモートに tmux がなければ通常の ssh にフォールバック
    __tmux_passthrough_on
    command ssh $ssh_args -t "/bin/sh -lc 'tmux new-session -A -s main 2>/dev/null || exec \$SHELL -l'"
    set -l ssh_status $status
    __tmux_passthrough_off
    return $ssh_status
end
