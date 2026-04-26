function __tm_agent_badge --description 'agent ペイン状態をバッジ文字列として生成 (claude=purple / codex=cyan)'
    set -l session $argv[1]
    set -l win_idx $argv[2]

    set -l cs_raw (__tm_agent_state $session $win_idx)
    test -z "$cs_raw"; and return

    set -l cs_parts (string split \t $cs_raw)
    set -l state $cs_parts[1]
    set -l elapsed ''
    set -l agent ''
    if set -q cs_parts[2]
        set elapsed $cs_parts[2]
    end
    if set -q cs_parts[3]
        set agent $cs_parts[3]
    end

    set -l purple (printf '\e[35m')
    set -l cyan (printf '\e[36m')
    set -l red (printf '\e[31m')
    set -l dim (printf '\e[2m')
    set -l reset (printf '\e[0m')

    set -l running_color $purple
    if test "$agent" = codex
        set running_color $cyan
    end

    switch $state
        case running
            if test -n "$elapsed" -a "$elapsed" != "-"
                printf ' %s[running(%sm)]%s' $running_color $elapsed $reset
            else
                printf ' %s[running]%s' $running_color $reset
            end
        case permission
            printf ' %s[perm]%s' $red $reset
        case ask
            printf ' %s[ask]%s' $red $reset
        case idle
            printf ' %s[idle]%s' $dim $reset
    end
end
