if status is-interactive
    # Commands to run in interactive sessions can go here
end

#source /usr/local/opt/asdf/libexec/asdf.fish

set -Ux GOPATH $HOME/go
set -Ux GOOS darwin
set -Ux GOARCH amd64
set -Ux GO111MODULE on
set -Ux KUBE_EDITOR vim
set -Ux AQUA_PROGRESS_BAR true
set -Ux NPM_CONFIG_PREFIX $HOME/.local/share/npm-global
set -Ux EDITOR vim

set -Ux AQUA_ROOT_DIR $(aqua root-dir)
#set -Ux AQUA_CONFIG .aqua-me.yaml

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
