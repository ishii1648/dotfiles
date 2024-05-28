if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -Ux GOPATH $HOME/go
set -Ux GOOS darwin
set -Ux GOARCH amd64
set -Ux GO111MODULE on

set -Ux AQUA_ROOT_DIR $(aqua root-dir)

# about https://github.com/PatrickF1/fzf.fish
set fzf_fd_opts --hidden --max-depth 5
fzf_configure_bindings --directory=\cf --git_log=\cl

alias cat=nyan
alias g=git
alias k=kubectl
alias d=docker

fish_add_path $GOPATH/bin
fish_add_path $AQUA_ROOT_DIR/bin


function s_ghq
  set selected_dir $(ghq list -p | fzf)
  if [ $selected_dir ]
    cd $selected_dir
  end
end
