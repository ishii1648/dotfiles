function fish_prompt
    set -l last_status $status

    # OSC 133;A - プロンプト開始
    printf '\e]133;A\a'

    # pwd
    set_color -b 535d7f white
    echo -n (string replace $HOME '~' $PWD)" "

    # git (ディレクトリ変更時のみ更新)
    set -l current_pwd (pwd)
    if test "$current_pwd" != "$__fish_prompt_pwd_cache"
        set -g __fish_prompt_pwd_cache $current_pwd
        __fish_prompt_update_git
    end

    if test -n "$__fish_git_prompt_cache"
        # pwd→git 遷移三角: 前景=灰色(前の背景), 背景=緑(次の背景)
        set_color -b green 535d7f
        printf '\ue0b0'
        # git内容: 背景=緑, 前景=黒
        set_color -b green black
        echo -n "$__fish_git_prompt_cache "
        # git終端三角: 前景=緑(前の背景), 背景=なし
        set_color -b normal green
        printf '\ue0b0'
    else
        # pwd終端三角: 前景=灰色(前の背景), 背景=なし
        set_color -b normal 535d7f
        printf '\ue0b0'
    end
    set_color normal

    # newline + character
    echo
    if test $last_status -eq 0
        set_color green
    else
        set_color red
    end
    echo -n "❯ "
    set_color normal

    # OSC 133;B - プロンプト終了
    printf '\e]133;B\a'
end

function __fish_prompt_update_git
    set -g __fish_git_prompt_cache ""

    if git rev-parse --git-dir >/dev/null 2>&1
        set -l branch (git branch --show-current 2>/dev/null)
        test -z "$branch" && set branch (git rev-parse --short HEAD 2>/dev/null)
        set -g __fish_git_prompt_cache " $branch"
    end
end

function __fish_prompt_update_kube
    set -g __fish_kube_prompt_cache ""

    if test -f ~/.kube/config
        set -l ctx (kubectl config current-context 2>/dev/null)
        if test -n "$ctx"
            set -l ns (kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
            test -z "$ns" && set ns "default"
            set -g __fish_kube_prompt_cache " $ctx/$ns"
        end
    end
end

# OSC 133;C - コマンド実行開始
function __fish_osc133_preexec --on-event fish_preexec
    printf '\e]133;C\a'
end

# OSC 133;D - コマンド終了 + kubectx/aws後のk8s更新
function __fish_osc133_postexec --on-event fish_postexec
    printf '\e]133;D;%s\a' $status

    # kubectx/aws 実行後にk8s context更新
    set -l cmd (string split ' ' $argv[1])[1]
    if contains $cmd kubectx kubens aws
        __fish_prompt_update_kube
    end
end

# シェル起動時に1回だけk8s context取得
if not set -q __fish_kube_prompt_cache
    __fish_prompt_update_kube
end
