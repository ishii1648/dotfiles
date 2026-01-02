function fish_prompt
    set -l last_status $status
    set -l prompt_char '❯'

    # pwd (青)
    set_color blue
    echo -n (prompt_pwd)
    set_color normal

    # git
    if git rev-parse --git-dir >/dev/null 2>&1
        set -l branch (git branch --show-current 2>/dev/null)
        if test -z "$branch"
            set branch (git rev-parse --short HEAD 2>/dev/null)
        end

        if test -n "$(git status --porcelain 2>/dev/null)"
            set_color yellow
            echo -n " $branch ✗"
        else
            set_color green
            echo -n " $branch ✓"
        end
        set_color normal
    end

    # kubernetes
    if test -f ~/.kube/config
        set -l ctx (kubectl config current-context 2>/dev/null)
        if test -n "$ctx"
            set -l ns (kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
            test -z "$ns" && set ns "default"
            set_color cyan
            echo -n " $ctx/$ns"
            set_color normal
        end
    end

    # newline + character
    echo
    if test $last_status -eq 0
        set_color green
    else
        set_color red
    end
    echo -n "$prompt_char "
    set_color normal
end
