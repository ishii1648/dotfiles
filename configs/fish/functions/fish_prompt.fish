function fish_prompt
    set -l last_status $status

    # OSC 133;A - プロンプト開始
    printf '\e]133;A\a'

    # SSH indicator
    if set -q SSH_CONNECTION
        set_color -b ff5555 white
        echo -n " "(hostname -s)" "
        set_color -b 535d7f ff5555
        printf '\ue0b0'
    end

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
        # worktree状態で背景色を決定: worktree有効=緑, 通常=灰色
        set -l git_bg 9a9a9a
        test "$__fish_git_is_worktree" = "1" && set git_bg green
        # pwd→git 遷移三角: 前景=灰色(前の背景), 背景=git_bg
        set_color -b $git_bg 535d7f
        printf '\ue0b0'
        # git内容: 背景=git_bg, 前景=黒
        set_color -b $git_bg black
        echo -n "$__fish_git_prompt_cache "
        # git終端三角: 前景=git_bg(前の背景), 背景=なし
        set_color -b normal $git_bg
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
    set -g __fish_git_is_worktree "0"

    if git rev-parse --git-dir >/dev/null 2>&1
        set -l branch (git branch --show-current 2>/dev/null)
        test -z "$branch" && set branch (git rev-parse --short HEAD 2>/dev/null)
        set -g __fish_git_prompt_cache " $branch"

        # worktree判定: worktreeが2つ以上あれば有効
        set -l worktree_count (git worktree list 2>/dev/null | count)
        if test $worktree_count -gt 1
            set -g __fish_git_is_worktree "1"
        end
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

# OSC 133;D - コマンド終了 + git/kubectx/aws後の更新
function __fish_osc133_postexec --on-event fish_postexec
    printf '\e]133;D;%s\a' $status

    # git コマンド実行後にキャッシュ無効化（次のプロンプトで更新）
    if string match -qr '^(git|g|gw_)' -- "$argv[1]"
        set -g __fish_prompt_pwd_cache ""
    end
    # kubectx/aws 実行後にk8s context更新
    if string match -qr '^(kubectx|kubens|aws)( |$)' -- "$argv[1]"
        __fish_prompt_update_kube
    end
end

# シェル起動時に1回だけk8s context取得
if not set -q __fish_kube_prompt_cache
    __fish_prompt_update_kube
end
