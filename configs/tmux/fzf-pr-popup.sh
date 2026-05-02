#!/usr/bin/env bash
# tmux popup: PR URL (#NNN, gh pr view) と画面上の http(s):// URL を fzf で選択して open
# `wfxr/tmux-fzf-url` が xre 書き直し時に @fzf-url-extra-filter を廃止したため、
# 自前で capture-pane → PR フィルタ + 生 URL 抽出 → fzf --tmux popup を組み立てる。
#
# tmux capture-pane -e は OSC 8 ハイパーリンク (`\e]8;;<URL>\e\\<TEXT>\e]8;;\e\\`) を
# 残すので、CSI だけでなく OSC も strip しないと URL の前後にゴミが残る。
set -euo pipefail

PR_FILTER="$HOME/.local/bin/tmux-fzf-url-pr-filter"

content="$(tmux capture-pane -J -p -e -S -)"

# OSC 8 ハイパーリンク内 URL を別途回収（OSC strip すると URL も消えるため）
osc_urls=$(
    printf '%s' "$content" \
        | perl -ne 'while (/\e\]8;[^;]*;(https?:\/\/[^\e\a]+)/g) { print "$1\n" }' \
        | sort -u || true
)

# 全 ANSI（CSI + OSC）を消した plain text
plain=$(
    printf '%s' "$content" \
        | perl -pe 's/\e\]8;[^;]*;[^\e\a]*(\e\\|\a)//g; s/\e\[[0-9;]*[a-zA-Z]//g'
)

plain_urls=$(
    printf '%s' "$plain" \
        | grep -oE 'https?://[^[:space:]<>"'"'"'(){}]+' \
        | sort -u || true
)

items=$(
    {
        if [[ -x "$PR_FILTER" ]]; then
            printf '%s\n' "$content" | "$PR_FILTER"
        fi
        printf '%s\n' "$osc_urls"
        printf '%s\n' "$plain_urls"
    } | awk '
        {
            stripped = $0
            gsub(/\033\[[0-9;]*[a-zA-Z]/, "", stripped)
            gsub(/\033\]8;[^;]*;[^\033\007]*(\033\\|\007)/, "", stripped)
            n = split(stripped, fields, /[ \t]+/)
            url = fields[n]
            if (url != "" && !seen[url]++) print
        }
    '
)

if [[ -z "$items" ]]; then
    tmux display 'tmux-fzf-pr-popup: no URLs found'
    exit 0
fi

selected=$(printf '%s\n' "$items" | fzf --tmux center,90%,60% --ansi --multi --exit-0 --no-preview || true)

[[ -z "$selected" ]] && exit 0

opener=open
if ! command -v open >/dev/null 2>&1; then
    if command -v xdg-open >/dev/null 2>&1; then
        opener=xdg-open
    else
        tmux display 'tmux-fzf-pr-popup: no opener (open / xdg-open) found'
        exit 1
    fi
fi

while IFS= read -r line; do
    url=$(
        printf '%s' "$line" \
            | perl -pe 's/\e\]8;[^;]*;[^\e\a]*(\e\\|\a)//g; s/\e\[[0-9;]*[a-zA-Z]//g' \
            | awk '{print $NF}'
    )
    [[ -n "$url" ]] && "$opener" "$url"
done <<< "$selected"
