function hd --description 'herdr セッションを新規 ghostty ウィンドウで起動する（引数で --session 等を指定可能）'
    if set -q HERDR_ENV
        echo "hd: already inside a herdr pane" >&2
        return 1
    end

    set -l herdr_bin (command -v herdr)
    if test -z "$herdr_bin"
        echo "hd: herdr not found in PATH" >&2
        return 1
    end

    # ghostty の command は herdr（ADR-076 Phase 3）。新規ウィンドウは Cmd+N でも
    # herdr が起動するが、--session 等の引数付きで別ウィンドウを開きたい場合に使う。
    if test (uname) = Darwin; and test -d /Applications/Ghostty.app
        set -l cmd $herdr_bin
        if test (count $argv) -gt 0
            set cmd "$herdr_bin "(string join ' ' -- $argv)
        end
        open -na Ghostty --args --command=$cmd
    else
        command $herdr_bin $argv
    end
end
