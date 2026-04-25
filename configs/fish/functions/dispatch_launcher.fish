function dispatch_launcher --description 'dispatch/orchestrate popup ランチャー（claude/codex モード切替）'
    # ADR-056 / ADR-061: トップレベルを claude / codex モードに再構成
    # claude モード（デフォルト）: ghq リポジトリ選択 → Step 2（dispatch/orchestrate 切替 + prompt）
    # codex モード: ghq リポジトリ選択 → 選択リポジトリで session 作成・切替 + codex CLI 起動

    set -l mode_file /tmp/dl-fzf-codex-mode
    rm -f $mode_file
    set -l bold_green (printf '\e[1;92m')
    set -l dim (printf '\e[90m')
    set -l reset (printf '\e[0m')
    set -l init_header (printf '  %stab: switch  %sclaude%s / %scodex%s' $dim $bold_green $reset $dim $reset)
    set -l fzf_output (fish -c __dl_repo_candidates | fzf \
        --ansi \
        --delimiter '\t' --with-nth 2 \
        --prompt '> ' \
        --header "$init_header" \
        --layout=reverse --cycle \
        --bind 'tab:transform(fish -c __dl_fzf_toggle)')
    set -l codex_mode 0
    if test -f $mode_file
        set codex_mode 1
    end
    rm -f $mode_file

    if test -z "$fzf_output"
        return 0
    end

    set -l selected (string split \t $fzf_output)[2]
    set selected (string trim $selected)

    # codex モード: session 作成 + codex 起動 + switch-client
    if test "$codex_mode" = 1
        set -l ghq_root (ghq root)
        set -l repo_path "$ghq_root/$selected"
        set -l session_name (basename $selected)
        if not tmux has-session -t $session_name 2>/dev/null
            set -l win_w (tmux display-message -p '#{window_width}')
            set -l win_h (tmux display-message -p '#{window_height}')
            tmux new-session -d -s $session_name -c $repo_path -x $win_w -y $win_h
        end
        tmux send-keys -t $session_name "codex" Enter
        tmux switch-client -t $session_name
        return 0
    end

    # claude モード: 既存の Step 2（dispatch/orchestrate 切替 + prompt 入力）
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
