echo 'load ~/.zprofile'

export LANG=ja_JP.UTF-8
export CLICOLOR=1
export LSCOLORS=DxGxcxdxCxegedabagacad
export EDITOR='/usr/bin/vim'
export HOMEBREW_CASK_OPTS="--appdir=/Applications"
export PATH=/usr/local/opt/coreutils/libexec/gnubin:usr/local/bin:${PATH}
export MANPATH=/usr/local/opt/coreutils/libexec/gnuman:usr/local/share/man:${MANPATH}
export WORKPATH=${HOME}/workspace
export SNIPETPATH=${WORKPATH}/snipet

# 補完関数のディレクトリ
if [ -e /usr/local/share/zsh/functions ]; then
  export FPATH=/usr/local/share/zsh/functions:${FPATH}
fi
