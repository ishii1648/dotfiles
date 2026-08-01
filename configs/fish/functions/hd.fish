function hd --description 'herdr セッションを起動/アタッチする（macOS は tmux 外の ghostty ウィンドウで開く）'
    if set -q HERDR_ENV
        echo "hd: already inside a herdr pane" >&2
        return 1
    end

    set -l herdr_bin (command -v herdr)
    if test -z "$herdr_bin"
        echo "hd: herdr not found in PATH" >&2
        return 1
    end

    # ghostty は起動時に必ず tmux へアタッチする（configs/ghostty/ghostty-tmux-init.sh）。
    # herdr を tmux の内側で動かすと prefix (ctrl+space) を tmux に横取りされるため、
    # --command で tmux を経由しない新規ウィンドウを開く（ADR-076 Phase 1: tmux と並走）。
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
