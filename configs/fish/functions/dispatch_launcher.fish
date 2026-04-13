function dispatch_launcher --description 'dispatch/orchestrate popup ランチャー（2段階フロー）'
    # ADR-056: dispatch/orchestrate popup ランチャー
    # Step 1: リポジトリ選択（fzf）
    # Step 2: タスク記述入力（read） + tab で dispatch/orchestrate 切替

    set -l ghq_root (ghq root)

    # Step 1: リポジトリ選択
    set -l selected (ghq list -p | while read -l repo
        string match -q '*@*' $repo; and continue
        string replace "$ghq_root/" '' $repo
    end | fzf \
        --prompt 'repo > ' \
        --layout=reverse --cycle)

    if test -z "$selected"
        return 0
    end

    # Step 2: タスク記述 + tab でモード切替
    set -g _dl_mode dispatch
    set -g _dl_repo (basename $selected)

    function _dl_prompt
        set_color brblack
        printf '  tab: モード切替  enter: 実行\n'
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
    set -l slug (echo $first_line | string replace -ar '[^a-zA-Z0-9]' '-' | string replace -ar -- '-+' '-' | string trim -c '-' | string sub -l 40 | string lower)
    set -l branch_name "feat/$slug"

    # tmux run-shell で popup 外で実行（popup 終了後も生存する）
    tmux display-message "$mode: $repo_name ... launching"

    if test "$mode" = dispatch
        set -l wt_name (string replace -a '/' '-' $branch_name)
        set -l target_session "$repo_name@$wt_name"
        # prompt を tmpfile 経由で渡す（改行・シングルクォートによるshell injection対策）
        set -l prompt_file (mktemp /tmp/dispatch-prompt-XXXXXX)
        printf '%s' "$prompt_text" > $prompt_file
        tmux run-shell -b "bash ~/.claude/skills/dispatch/dispatch.sh launch '$selected' --prompt-file '$prompt_file' --branch '$branch_name' > /dev/null 2>&1; tmux switch-client -t '=$target_session' 2>/dev/null"
    else
        # orchestrate: orchestrate.sh launch を直接呼び出す
        # worktree + tmux session + claude 起動を一括実行
        set -l prompt_file (mktemp /tmp/dispatch-orch-prompt-XXXXXX)
        printf '%s' "$prompt_text" > $prompt_file

        tmux run-shell -b "bash ~/.claude/skills/orchestrate/_dl_orchestrate_launch.sh '$selected' '$prompt_file'"
    end
end
