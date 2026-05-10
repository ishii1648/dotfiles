# Manual override for aqua's broken vendor fish completion.
# aqua 2.58.x ships a completion script with unrendered Go format
# verbs (e.g. `__%!_(string=aqua)perform_completion`) that fish cannot parse.
# Track upstream: https://github.com/aquaproj/aqua / urfave/cli fish template.

function __aqua_perform_completion
    set -l args (commandline -opc)
    set -l lastArg (commandline -ct)

    set -l results ($args[1] $args[2..-1] $lastArg --generate-shell-completion 2>/dev/null)

    for line in $results[-1..1]
        if test (string trim -- $line) = ""
            set results $results[1..-2]
        else
            break
        end
    end

    for line in $results
        set -l parts (string split -m 1 ":" -- "$line")
        if test (count $parts) -eq 2
            printf "%s\t%s\n" "$parts[1]" "$parts[2]"
        else
            printf "%s\n" "$line"
        end
    end
end

complete -c aqua -e
complete -c aqua -f -a '(__aqua_perform_completion)'
