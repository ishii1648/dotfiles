#!/bin/sh
# prtrack session switch (ADR-049)
# session が存在しなければ作成・prtrack 起動、存在すれば直接 switch-client

SESSION="prtrack"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux new-session -d -s "$SESSION"
    tmux send-keys -t "$SESSION" "prtrack" Enter
fi

tmux switch-client -t "$SESSION"
