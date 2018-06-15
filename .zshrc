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

# プロンプト
case ${UID} in
0)
    PROMPT="%{${fg[red]}%}%n%{${reset_color}%} #"
    RPROMPT="[%~]"
    ;;
*)
    PROMPT="%n $ "
    RPROMPT="[%~]"
    ;;
esac

# curlでno mathes foundと表示されるのを防ぐ
setopt nonomatch

# alias
alias ls='ls --color=auto'
alias la='ls -la --color=auto'
alias ll='ls -l --color=auto'
alias ll='ls -l'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias vi='vim'
alias less='less -NM'
alias ctags='/usr/local/Cellar/ctags/5.8_1/bin/ctags'
alias curl_header='curl -D - -s -o /dev/null'
alias s='ssh $(grep -iE "^host[[:space:]]+[^*]" ~/.ssh/config|peco|awk "{print \$2}")'
alias date='date "+%Y/%m/%d"'

# peco
function select_history() {
  BUFFER=$(\history -n -r 1 | peco --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle clear-screen
}
zle -N select_history
bindkey '^r' select_history

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
