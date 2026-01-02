function fish_right_prompt
    if test -n "$__fish_kube_prompt_cache"
        # 逆三角: 前景=緑(次の背景), 背景=なし
        set_color green
        printf '\ue0b2'
        # kube内容: 背景=緑, 前景=黒
        set_color -b green black
        echo -n $__fish_kube_prompt_cache
        set_color normal
    end
end
