if status is-interactive
    # Commands to run in interactive sessions can go here
end

#source /usr/local/opt/asdf/libexec/asdf.fish

set -gx GOPATH $HOME/go
set -gx GOOS darwin
set -gx GOARCH amd64
set -gx GO111MODULE on
set -gx KUBE_EDITOR vim
set -gx AQUA_PROGRESS_BAR true
set -gx NPM_CONFIG_PREFIX $HOME/.local/share/npm-global
set -gx EDITOR vim

set -gx AQUA_ROOT_DIR $(aqua root-dir)

# about https://github.com/PatrickF1/fzf.fish
set fzf_fd_opts --hidden --max-depth 5
fzf_configure_bindings --directory=\cf --git_log=\cl

alias cat=nyan
alias g=git
alias k=kubectl
alias d=docker
alias t=terraform
alias gc=gcloud
alias a=aws
alias e=eksctl
alias python=python3
alias cc=claude
#alias vi=nvim

fish_add_path $GOPATH/bin
fish_add_path $AQUA_ROOT_DIR/bin
fish_add_path $NPM_CONFIG_PREFIX/bin
fish_add_path $HOME/.local/bin

function s_ghq
  set selected_dir $(ghq list -p | fzf)
  if [ $selected_dir ]
    cd $selected_dir
  end
end

complete -f -c gcloud -a '(gcloud_sdk_argcomplete)'

complete -c aws -f -a '(
    begin
        set -lx COMP_SHELL fish
        set -lx COMP_LINE (commandline)
        aws_completer
    end
)'


source "$HOME/.cargo/env.fish"


