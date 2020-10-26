# 読み込まれたことが分かるようにする
echo 'load ~/.zshrc'

# 色を使用出来るようにする
autoload -Uz colors
colors

# emacs キーマップを選択
bindkey -e

# historyの設定
HISTFILE=~/.zsh_history
HISTSIZE=1000000
SAVEHIST=1000000
setopt hist_ignore_dups
setopt share_history 

# historyに関するショートカットの設定
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^b" history-beginning-search-backward-end
bindkey "^f" history-beginning-search-forward-end

# 直前のコマンドの重複を削除
setopt hist_ignore_dups
# 同じコマンドをヒストリに残さない
setopt hist_ignore_all_dups
# 同時に起動したzshの間でヒストリを共有
setopt share_history

# 補完機能を有効にする
autoload -Uz compinit
compinit -u

# 補完メッセージを読みやすくする
zstyle ':completion:*' verbose yes
zstyle ':completion:*' format '%B%d%b'
zstyle ':completion:*:warnings' format 'No matches for: %d'
zstyle ':completion:*' group-name ''

# 補完で小文字でも大文字にマッチさせる
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# 補完候補を詰めて表示
setopt list_packed
# 補完候補一覧をカラー表示
zstyle ':completion:*' list-colors ''

# cdを自動補完
setopt auto_cd

# 移動したディレクトリを一覧表示
setopt auto_pushd

# コマンドのスペルを訂正
setopt correct
# ビープ音を鳴らさない
setopt no_beep
setopt nolistbeep
# プロンプトが表示されるたびにプロンプト文字列を評価、置換する
setopt prompt_subst

# プロンプト
case ${UID} in
0)
    PROMPT="%{${fg[red]}%}%n%{${reset_color}%} #"
    RPROMPT="[%~]"
    ;;
*)
    PROMPT='%F{cyan}sho@Desktop%f$(git-current-branch) $ '
    RPROMPT="[%~]"
    ;;
esac

# curlでno mathes foundと表示されるのを防ぐ
setopt nonomatch

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
alias as='aws-shell'
alias g='git'
alias k='kubectl'
alias d='docker'
#alias d='docker -H tcp://${DOCKER_PUBLIC_IP}:2376'
alias t='terraform'
alias c="powered_cd"
alias v="vagrant"
alias sk='select_kube_api_server'
alias sb='select_branch'
alias ske='select_kubectl_exec'
alias e='etcdctl --endpoints http://192.168.35.101:2379'
#alias cat='bat'

# peco
function select_history() {
  BUFFER=$(\history -n -r 1 | peco --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle clear-screen
}
zle -N select_history
bindkey '^r' select_history

function select_branch() {
  local branches branch
  branches=$(git branch -vv) &&
  branch=$(echo "$branches" | fzf +m) &&
  git checkout $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
}

function p_kill() {
  for pid in `ps aux | peco | awk '{ print $2 }'`
  do
    kill $pid
    echo "Killed ${pid}"
  done
}

function p_git_add() {
    for file in `git status -s | grep -v '^[A|M]' | peco | awk '{print $NF}'`
    do
        git add $file
        echo "git added ${file}"
    done
}

function ch_py_version() {
    for version in `pyenv versions | peco`
    do
        pyenv global ${version}
        echo "Current Python version is ${version}"
    done
}

function select_snipet() {
  BUFFER=$(cat ~/workspace/snipet/* | grep -v '^-' | fzf -e --query "$LBUFFER" | awk -F'[*]' '{print $4}' | sed -e 's/^[ \t]*//g')
  CURSOR=$#BUFFER
}
zle -N select_snipet
bindkey '^z' select_snipet

function start_ec2() {
  aws ec2 start-instances --instance-id \
  $(aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{Name: Tags[?Key==`Name`].Value|[0], InstanceId: InstanceId, Status: State.Name}' \
  --output text | fzf | awk "{print \$1}")
}

function stop_ec2() {
  aws ec2 stop-instances --instance-id \
  $(aws ec2 describe-instances \
  --query 'Reservations[].Instances[].{Name: Tags[?Key==`Name`].Value|[0], InstanceId: InstanceId, Status: State.Name}' \
  --output text | fzf | awk "{print \$1}")
}

function select_kube_api_server() {
  config_name=`ll ~/.kube/ | grep config | fzf | awk '{print $NF}'`
  \cp -f $HOME/.kube/${config_name} $HOME/.kube/config
}

function select_kubectl_exec() {
  pod_name=`kubectl get po | awk '{print $1}' | grep -v NAME | fzf`
  kubectl exec -it $pod_name -- bash
}


# ブランチ名を色付きで表示させるメソッド
function git-current-branch {
  local branch_name st branch_status

  if git rev-parse 2> /dev/null; then 
    branch_name=`git rev-parse --abbrev-ref HEAD 2> /dev/null`
    st=`git status 2> /dev/null`
    if [[ -n `echo "$st" | grep "^nothing to"` ]]; then
      # 全てcommitされてクリーンな状態
      branch_status="%F{green}"
    elif [[ -n `echo "$st" | grep "^Untracked files"` ]]; then
      # gitに管理されていないファイルがある状態
      branch_status="%F{red}?"
    elif [[ -n `echo "$st" | grep "^Changes not staged for commit"` ]]; then
      # git addされていないファイルがある状態
      branch_status="%F{red}+"
    elif [[ -n `echo "$st" | grep "^Changes to be committed"` ]]; then
      # git commitされていないファイルがある状態 
      branch_status="%F{yellow}!"
    elif [[ -n `echo "$st" | grep "^rebase in progress"` ]]; then
      # コンフリクトが起こった状態
      echo "%F{red}!(no branch)"
      return
    else
      # 上記以外の状態の場合は青色で表示させる
      branch_status="%F{blue}"
    fi
    # ブランチ名を色付きで表示する
    echo " ${branch_status}($branch_name)%f"
  fi
}

function chpwd() {
  powered_cd_add_log
}

function powered_cd_add_log() {
  local i=0
  cat ~/.powered_cd.log | while read line; do
    (( i++ ))
    if [ i = 30 ]; then
      sed -i -e "30,30d" ~/.powered_cd.log
    elif [ "$line" = "$PWD" ]; then
      sed -i -e "${i},${i}d" ~/.powered_cd.log
    fi
  done
  echo "$PWD" >> ~/.powered_cd.log
}

function powered_cd() {
  if [ $# = 0 ]; then
    cd $(gtac ~/.powered_cd.log | fzf)
  elif [ $# = 1 ]; then
    cd $1
  else
    echo "powered_cd: too many arguments"
  fi
}

_powered_cd() {
  _files -/
}

compdef _powered_cd powered_cd

[ -e ~/.powered_cd.log ] || touch ~/.powered_cd.log

source <(kubectl completion zsh)

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/local/Cellar/tfenv/1.0.2/versions/0.12.20/terraform terraform
complete -C '/usr/local/bin/aws2_completer' aws2

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/ishiishou/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/ishiishou/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/ishiishou/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/ishiishou/google-cloud-sdk/completion.zsh.inc'; fi
