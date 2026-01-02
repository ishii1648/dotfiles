function fish_prompt
    set -l last_status $status

    # pwd
    set_color blue
    echo -n (prompt_pwd)
    set_color normal

    # git (ディレクトリ変更時のみ更新)
    set -l current_pwd (pwd)
    if test "$current_pwd" != "$__fish_prompt_pwd_cache"
        set -g __fish_prompt_pwd_cache $current_pwd
        __fish_prompt_update_git
    end

    if set -q __fish_git_prompt_cache
        echo -n $__fish_git_prompt_cache
    end

    # kubernetes
    if set -q __fish_kube_prompt_cache
        echo -n $__fish_kube_prompt_cache
    end

    # newline + character
    echo
    if test $last_status -eq 0
        set_color green
    else
        set_color red
    end
    echo -n "❯ "
    set_color normal
end

function __fish_prompt_update_git
    set -g __fish_git_prompt_cache ""

    if git rev-parse --git-dir >/dev/null 2>&1
        set -l branch (git branch --show-current 2>/dev/null)
        test -z "$branch" && set branch (git rev-parse --short HEAD 2>/dev/null)
        set -g __fish_git_prompt_cache (set_color magenta)" $branch"(set_color normal)
    end
end

function __fish_prompt_update_kube
    set -g __fish_kube_prompt_cache ""

    if test -f ~/.kube/config
        set -l ctx (kubectl config current-context 2>/dev/null)
        if test -n "$ctx"
            set -l ns (kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
            test -z "$ns" && set ns "default"
            set -g __fish_kube_prompt_cache (set_color cyan)" $ctx/$ns"(set_color normal)
        end
    end
end

# kubectx/aws 実行後にk8s context更新
function __fish_prompt_postexec --on-event fish_postexec
    set -l cmd (string split ' ' $argv[1])[1]
    if contains $cmd kubectx kubens aws
        __fish_prompt_update_kube
    end
end

# シェル起動時に1回だけk8s context取得
if not set -q __fish_kube_prompt_cache
    __fish_prompt_update_kube
end
