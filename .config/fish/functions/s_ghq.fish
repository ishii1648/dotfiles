function s_ghq --description 'ghqリポジトリをfzfで選択して移動'
    set selected_dir (ghq list -p | fzf)
    if test -n "$selected_dir"
        cd $selected_dir
    end
end
