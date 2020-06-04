echo 'load ~/.zprofile'

export LANG=ja_JP.UTF-8
export CLICOLOR=1
export LSCOLORS=exfxcxdxbxegedabagacad
export EDITOR='/usr/bin/vim'
export HOMEBREW_CASK_OPTS="--appdir=/Applications"

# for go
export GOROOT=/usr/local/go

export PATH=$GOROOT/bin:$HOME/go/bin:$HOME/.pyenv/shims:/usr/local/opt/coreutils/libexec/gnubin:/usr/local/bin:~/.local/bin:${PATH}

export MANPATH=/usr/local/opt/coreutils/libexec/gnuman:usr/local/share/man:${MANPATH}
export GOPATH=$(go env GOPATH)
export GO111MODULE=on
export LDFLAGS="-L/usr/local/opt/zlib/lib"
export CPPFLAGS="-I/usr/local/opt/zlib/include"

# for mysql on docker
#export DB_HOST=localhost
export MYSQL_PASSWORD=Latona2019!
#export DB_ADMIN_USERNAME=root

# for aion-gateway
export JWT_SECRET=thQFW5fwIfpQiHSKkZfjblb0A9TP8dUP

# for linux x86_64 compile
#export GOOS=linux
#export GOARCH=amd64

# for linux arm compile
export GOOS=darwin
export GOARCH=amd64

# for k8s
#export KUBECONFIG=$HOME/.kube/config-nike
#export KUBECONFIG=$HOME/.kube/config-sirius


# 補完関数のディレクトリ
if [ -e /usr/local/share/zsh/functions ]; then
  export FPATH=/usr/local/share/zsh/functions:${FPATH}
fi

#export PATH="$HOME/.cargo/bin:/usr/local/go/bin:$PATH"
