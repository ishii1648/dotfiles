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

function ch_py_version() {
    for version in `pyenv versions | peco`
    do
        pyenv global ${version}
        echo "Current Python version is ${version}"
    done
}

function find_cd() {
    cd "$(find . -type d | peco)"
}

