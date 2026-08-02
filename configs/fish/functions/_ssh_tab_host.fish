function _ssh_tab_host --description 'ssh の引数から接続先ホスト名を取り出す（ADR-078）'
    set -l skip_next false
    for arg in $argv
        if test "$skip_next" = true
            set skip_next false
            continue
        end
        switch $arg
            case -p -i -l -L -R -D -o -J -F -W -b -c -e -m -O -Q -S -w -E -B
                # 値を取るオプション。次の引数はホスト名ではない
                set skip_next true
            case '-*'
                # フラグ、および -p2222 / -oPort=22 のような結合形式は読み飛ばす
            case '*'
                # 最初の非オプション引数が接続先。表示上のノイズになる user@ は落とす
                string replace -r '^[^@]*@' '' -- $arg
                return 0
        end
    end
    return 1
end
