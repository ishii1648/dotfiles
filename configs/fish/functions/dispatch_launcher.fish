function dispatch_launcher --description 'dispatch/orchestrate popup ランチャー（2段階フロー）'
    # ADR-056: dispatch/orchestrate popup ランチャー
    # Step 1: リポジトリ選択（fzf）
    # Step 2: タスク記述入力（read） + tab で dispatch/orchestrate 切替

    # Step 1: リポジトリ選択（Tab で PR worktree 切り替え）
    rm -f /tmp/dl-fzf-pr-mode
    set -l bold_green (printf '\e[1;92m')
    set -l dim (printf '\e[90m')
    set -l reset (printf '\e[0m')
    set -l init_header (printf '  %stab: switch  %srepos%s / %sPRs%s' $dim $bold_green $reset $dim $reset)
    set -l fzf_output (fish -c __dl_repo_candidates | fzf \
        --ansi \
        --delimiter '\t' --with-nth 2 \
        --prompt '> ' \
        --header "$init_header" \
        --layout=reverse --cycle \
        --bind 'tab:transform(fish -c __dl_fzf_toggle)')
    rm -f /tmp/dl-fzf-pr-mode

    if test -z "$fzf_output"
        return 0
    end

    set -l key (string split \t $fzf_output)[1]
    set -l selected (string split \t $fzf_output)[2]

    # PR worktree 選択 → セッション切り替え + Claude 起動
    if string match -q '/*' -- $key
        set -l session_name (basename $key)
        if not tmux has-session -t $session_name 2>/dev/null
            set -l win_w (tmux display-message -p '#{window_width}')
            set -l win_h (tmux display-message -p '#{window_height}')
            tmux new-session -d -s $session_name -c $key -x $win_w -y $win_h
        end
        tmux send-keys -t $session_name "claude" Enter
        tmux switch-client -t $session_name
        return 0
    end

    # repos 選択 → selected を string trim して従来フローへ
    set selected (string trim $selected)

    # Step 2: タスク記述 + tab でモード切替
    set -g _dl_mode dispatch
    set -g _dl_repo (basename $selected)

    function _dl_prompt
        set_color brblack
        printf '  tab: モード切替  enter: 実行  `:<branch>` で既存 remote branch を checkout\n'
        set_color normal
        printf '  '
        if test "$_dl_mode" = dispatch
            set_color --bold brgreen
            printf 'dispatch'
            set_color normal brblack
            printf ' / orchestrate'
        else
            set_color normal brblack
            printf 'dispatch / '
            set_color --bold brmagenta
            printf 'orchestrate'
        end
        set_color normal
        printf '  %s\n' $_dl_repo
        set_color brblack
        printf '  ─────────────────────────────\n'
        set_color normal
        printf '  > '
    end

    function _dl_toggle
        if test "$_dl_mode" = dispatch
            set -g _dl_mode orchestrate
        else
            set -g _dl_mode dispatch
        end
        commandline -f repaint
    end

    bind \t _dl_toggle
    read -p _dl_prompt prompt_text
    bind -e \t

    set -l mode $_dl_mode
    set -e _dl_mode _dl_repo
    functions -e _dl_prompt _dl_toggle

    if test -z "$prompt_text"
        return 0
    end

    set -l repo_name (basename $selected)
    # 改行を含むペーストに対応: 最初の1行のみをslug生成に使用
    set -l first_line (string split \n -- $prompt_text)[1]

    # `:<branch>` プレフィックス → 既存 remote branch を checkout するモード（dispatch のみ）
    set -l checkout_mode false
    set -l branch_name
    if string match -q ':*' -- $first_line
        if test "$mode" != dispatch
            tmux display-message "dispatch: ':' branch checkout は dispatch モード専用です"
            return 1
        end
        set branch_name (string sub -s 2 -- $first_line | string trim)
        if test -z "$branch_name"
            tmux display-message "dispatch: branch 名が空です"
            return 1
        end
        set checkout_mode true
    else
        set -l slug (echo $first_line | string replace -ar '[^a-zA-Z0-9]' '-' | string replace -ar -- '-+' '-' | string trim -c '-' | string sub -l 40 | string lower)
        set branch_name "feat/$slug"
    end

    # tmux run-shell で popup 外で実行（popup 終了後も生存する）
    tmux display-message "$mode: $repo_name ... launching"

    if test "$mode" = dispatch
        # no-worktree 設定ファイルによる自動判定（$selected は ghq root 除去済みの短縮パス）
        set -l no_worktree_config "$HOME/.config/dispatch/no-worktree-repos"
        set -l use_worktree true
        if test -f "$no_worktree_config"
            if grep -qxF "$selected" "$no_worktree_config" 2>/dev/null
                set use_worktree false
            end
        end

        if test "$checkout_mode" = true
            # checkout モード: prompt なしで worktree 作成 + claude idle 起動
            tmux run-shell -b "bash ~/.claude/skills/dispatch/dispatch.sh launch '$selected' --branch '$branch_name' --no-prompt > /dev/null 2>&1"
        else
            # 通常モード: prompt を tmpfile 経由で渡す（改行・シングルクォートによるshell injection対策）
            set -l prompt_file (mktemp /tmp/dispatch-prompt-XXXXXX)
            printf '%s' "$prompt_text" > $prompt_file

            if test "$use_worktree" = true
                set -l wt_name (string replace -a '/' '-' $branch_name)
                set -l target_session "$repo_name@$wt_name"
                tmux run-shell -b "bash ~/.claude/skills/dispatch/dispatch.sh launch '$selected' --prompt-file '$prompt_file' --branch '$branch_name' > /dev/null 2>&1"
            else
                set -l target_session "$repo_name"
                tmux run-shell -b "bash ~/.claude/skills/dispatch/dispatch.sh launch '$selected' --prompt-file '$prompt_file' --no-worktree > /dev/null 2>&1"
            end
        end
    else
        # orchestrate: orchestrate.sh launch を直接呼び出す
        # worktree + tmux session + claude 起動を一括実行
        set -l prompt_file (mktemp /tmp/dispatch-orch-prompt-XXXXXX)
        printf '%s' "$prompt_text" > $prompt_file

        tmux run-shell -b "bash ~/.claude/skills/orchestrate/_dl_orchestrate_launch.sh '$selected' '$prompt_file'"
    end
end
