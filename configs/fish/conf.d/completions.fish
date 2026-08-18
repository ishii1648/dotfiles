# Custom completion configurations

complete -f -c gcloud -a '(gcloud_sdk_argcomplete)'

complete -c aws -f -a '(
    begin
        set -lx COMP_SHELL fish
        set -lx COMP_LINE (commandline)
        aws_completer
    end
)'

# git-spice: 公式の `git-spice shell completion fish` はバイナリの絶対パス
# （aqua のバージョン付き実体）を埋め込むため、そのままコミットするとバージョン更新で腐る。
# 中身は同じ動的ディスパッチャを PATH 経由で呼ぶよう書き換えたもの。
function __complete_git_spice
    set -lx COMP_LINE (commandline -cp)
    test -z (commandline -ct)
    and set COMP_LINE "$COMP_LINE "
    git-spice
end

complete -f -c git-spice -a '(__complete_git_spice)'
