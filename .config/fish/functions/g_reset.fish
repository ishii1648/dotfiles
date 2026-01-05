function g_reset -d "Interactive git reset using fzf to select commit from git log"
    # Check if we're in a git repository
    if not git rev-parse --git-dir >/dev/null 2>&1
        echo 'git_reset_fzf: Not in a git repository.' >&2
        return 1
    end

    # Set up git log format for display
    set -f git_log_format '%C(bold blue)%h%C(reset) - %C(cyan)%ad%C(reset) %C(yellow)%d%C(reset) %C(normal)%s%C(reset)  %C(dim normal)[%an]%C(reset)'
    
    # Preview command to show commit details
    set -f preview_cmd 'git show --color=always --stat --patch {1}'
    
    # Add syntax highlighting if available
    if set --query fzf_diff_highlighter
        set preview_cmd "$preview_cmd | $fzf_diff_highlighter"
    end

    # Show git log with fzf for selection
    set -f selected_log_line (
        git log --no-show-signature --color=always --format=format:$git_log_format --date=short | \
        fzf --ansi \
            --no-multi \
            --scheme=history \
            --prompt="Select commit to reset to> " \
            --preview=$preview_cmd \
            --preview-window=right:60%:wrap \
            --header="Enter: select commit, Esc: cancel" \
            --header-first
    )
    
    # Check if user cancelled
    if test $status -ne 0
        echo "Cancelled."
        return 0
    end
    
    # Extract commit hash from selected line
    set -f abbreviated_commit_hash (string split --field 1 " " $selected_log_line)
    set -f full_commit_hash (git rev-parse $abbreviated_commit_hash 2>/dev/null)
    
    if test -z "$full_commit_hash"
        echo "Error: Could not parse commit hash" >&2
        return 1
    end
    
    # Show reset options
    echo "Selected commit: $abbreviated_commit_hash"
    echo "Commit message: "(git log --format=%s -n 1 $full_commit_hash)
    echo ""
    echo "Choose reset mode:"
    echo "1) --soft   (keep changes staged)"
    echo "2) --mixed  (keep changes unstaged) [default]"
    echo "3) --hard   (discard all changes) [DANGEROUS]"
    echo "4) Cancel"
    echo ""
    
    # Get user choice
    read -l -P "Enter choice (1-4): " choice
    
    switch $choice
        case 1
            set -f reset_mode "--soft"
        case 2 ""
            set -f reset_mode "--mixed"
        case 3
            echo ""
            echo "⚠️  WARNING: This will permanently discard all uncommitted changes!"
            read -l -P "Are you sure? Type 'yes' to continue: " confirm
            if test "$confirm" != "yes"
                echo "Cancelled."
                return 0
            end
            set -f reset_mode "--hard"
        case 4
            echo "Cancelled."
            return 0
        case "*"
            echo "Invalid choice. Cancelled."
            return 1
    end
    
    # Perform the reset
    echo ""
    echo "Executing: git reset $reset_mode $full_commit_hash"
    git reset $reset_mode $full_commit_hash
    
    if test $status -eq 0
        echo "✅ Reset completed successfully!"
        echo ""
        echo "Current status:"
        git status --short
    else
        echo "❌ Reset failed!" >&2
        return 1
    end
end
