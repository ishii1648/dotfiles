#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...
for config_file ($HOME/.yadr/zsh/*.zsh) source $config_file

autoload -Uz promptinit
promptinit
prompt paradox

# alias
alias ls='ls --color=auto'
alias la='ls -la --color=auto'
alias ll='exa -bghHliS'
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
alias vi='vim'
alias less='less -NM'
alias ctags='/usr/local/Cellar/ctags/5.8_1/bin/ctags'
alias curl_header='curl -D - -s -o /dev/null'
alias s='ssh $(grep -iE "^host[[:space:]]+[^*]" ~/.ssh/config|peco|awk "{print \$2}")'
alias sm='aws ssm start-session --target $(cat ~/.ssm/config|fzf|awk "{print \$1}")'
alias a='aws2'
alias aws='aws2'
alias g='git'
alias k='kubectl'
alias d='docker'
alias t='terraform'
alias c="powered_cd"
alias v="vagrant"
alias sk='select_kube_api_server'
alias sb='select_branch'
alias ske='select_kubectl_exec'
alias e='etcdctl --endpoints http://192.168.35.101:2379'

function s_history() {
  BUFFER=$(\history -n -r 1 | peco --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle clear-screen
}
zle -N s_history
bindkey '^r' s_history

function s_kube_api_server() {
  config_name=`ll ~/.kube/ | grep config | fzf | awk '{print $NF}'`
  \cp -f $HOME/.kube/${config_name} $HOME/.kube/config
}

source <(kubectl completion zsh)

function s_src() {
  local selected_dir=$(ghq list -p | fzf)
  if [ -n "$selected_dir" ]; then
    cd ${selected_dir}
  fi
}
