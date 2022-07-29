export LANG=ja_JP.UTF-8
export CLICOLOR=1
export LSCOLORS=exfxcxdxbxegedabagacad
export EDITOR='/usr/bin/vim'

# terraform
export TF_CLI_ARGS_plan="--parallelism=80"
export TF_CLI_ARGS_apply="--parallelism=80"
#export TF_LOG=1
#export TF_LOG_PATH='./terraform.log'

# for go
export GO111MODULE=auto


export MANPATH=/usr/local/opt/coreutils/libexec/gnuman:usr/local/share/man:${MANPATH}
export GOPATH=$HOME/go
export LDFLAGS="-L/usr/local/opt/zlib/lib"
export CPPFLAGS="-I/usr/local/opt/zlib/include"
export FLAGS_GETOPT_CMD="$(brew --prefix gnu-getopt)/bin/getopt"
export DOCKER_BUILDKIT=1
export GOOS=darwin
export GOARCH=amd64

export PATH=/usr/local/opt/coreutils/libexec/gnubin:$HOME/go/bin:$HOME/.pyenv/shims:/usr/local/bin:~/.local/bin:${PATH}
