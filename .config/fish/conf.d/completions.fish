# Custom completion configurations

complete -f -c gcloud -a '(gcloud_sdk_argcomplete)'

complete -c aws -f -a '(
    begin
        set -lx COMP_SHELL fish
        set -lx COMP_LINE (commandline)
        aws_completer
    end
)'
