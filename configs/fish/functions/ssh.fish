function ssh --wraps ssh --description 'SSH 接続中は herdr のタブラベルを接続先ホストにする（ADR-078）'
    # herdr の外（remote プロファイルの fish 等）では素の ssh と同じ挙動
    set -l host
    if set -q HERDR_TAB_ID
        set host (_ssh_tab_host $argv)
    end

    if test -n "$host"
        # 同一コマンドラインの 2 本目以降は元ラベルを上書きしない（`ssh a; ssh b`）
        if not set -q __herdr_ssh_prev_tab_label
            set -l prev (herdr tab get $HERDR_TAB_ID 2>/dev/null | jq -r '.result.tab.label // empty' 2>/dev/null)
            # tab rename に --clear は無く、空文字にしても自動採番には戻らない。
            # 元ラベルを控えられない場合は戻せなくなるのでリネーム自体を諦める
            if test -n "$prev"
                set -g __herdr_ssh_prev_tab_label $prev
            end
        end
        if set -q __herdr_ssh_prev_tab_label
            herdr tab rename $HERDR_TAB_ID "⇢ $host" >/dev/null 2>&1
        end
    end

    # 書き戻しは conf.d/herdr-ssh-tab.fish の fish_prompt ハンドラが行う
    # （Ctrl-C で ssh が死ぬと、この関数の残りは実行されないため）
    command ssh $argv
end
