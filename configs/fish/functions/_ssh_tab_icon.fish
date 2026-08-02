function _ssh_tab_icon --description 'ホスト名から色付きアイコンを決める（ADR-078）'
    # herdr のタブバーは ANSI エスケープを解釈せず生の制御文字として崩れる。
    # 色を出す手段が絵文字しかないため、ホスト名のチェックサムで色を割り当てて
    # 「同じホストは常に同じ色 / 別ホストは別の色になりやすい」状態を作る。
    set -l icons 🔴 🟠 🟡 🟢 🔵 🟣
    set -l sum (printf '%s' "$argv[1]" | cksum | string split ' ')
    echo $icons[(math "$sum[1] % "(count $icons)" + 1")]
end
