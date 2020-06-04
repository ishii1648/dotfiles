alias s='ssh $(grep -iE "^host[[:space:]]+[^*]" ~/.ssh/config|peco|awk "{print \$2}")'
alias ls='ls --color=auto'
alias la='ls -la --color=auto'
alias ll='ls -l --color=auto'
alias rm='rm -i'
alias fc="find_cd"
alias g='git'
alias wp='docker run -it --rm --volumes-from wordpress --network container:wordpress wordpress:cli'
