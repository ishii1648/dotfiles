# 色を使用出来るようにする
autoload -Uz colors
colors

# vimライクなキーバインドを設定する
#bindkey -v

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
bindkey "^P" history-beginning-search-backward-end
bindkey "^N" history-beginning-search-forward-end

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

# 補完関数のディレクトリ
if [ -e /usr/local/share/zsh/functions ]; then
  fpath=(/usr/local/share/zsh/functions $fpath)
fi

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

# 先方予測を有効 
#autoload predict-on
#predict-on

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
alias ls='ls -aF'
alias ll='ls -l'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias vi='vim'
alias less='less -NM'
#alias ssh='~/bin/ssh-iterm-setting.sh'
alias ctags='/usr/local/Cellar/ctags/5.8_1/bin/ctags'
alias pskill='ps aux | fzf | sed 's/  */ /g' | cut -d ' ' -f2 | xargs kill -9'
alias curl_header='curl -D - -s -o /dev/null'

# 環境変数
export LANG=ja_JP.UTF-8
export CLICOLOR=1
export LSCOLORS=DxGxcxdxCxegedabagacad
