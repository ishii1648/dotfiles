source <(kubectl completion zsh)

# alias
alias ls='ls --color=auto'
alias la='ls -la --color=auto'
alias ll='exa -bghHliS'
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
alias g='git'
alias gc='gcloud'
alias k='kubectl'
alias d='docker'
alias t='terraform'
alias ts='terraform state'
alias sed='gsed'
alias base64='gbase64'
alias date='gdate'

function s_history() {
  BUFFER=$(\history -n -r 1 | peco --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle clear-screen
}
zle -N s_history
bindkey '^r' s_history

function s_ghq() {
  local selected_dir=$(ghq list -p | fzf)
  if [ -n "$selected_dir" ]; then
    cd ${selected_dir}
  fi
}

function s_project() {
  local project_id=$(gcloud projects list  | grep -v sys- | grep -v PROJECT_ID | fzf | awk '{print $1}')
  gcloud config set project ${project_id}
}

function s_terraform() {
  local version=$(tfenv list | fzf)
  tfenv use $version
}

function list_projects() {
  gcloud projects list  | grep -v sys- | grep -v PROJECT_ID
}

function get_gke_auth() {
  local id_location=$(gcloud container clusters list | grep -v NAME | fzf | awk '{print $1,$2}')
  local id_location_arr=(`echo $id_location`)
  gcloud container clusters get-credentials ${id_location_arr[1]} --region ${id_location_arr[2]}
}

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/s_ishii/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/s_ishii/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/s_ishii/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/s_ishii/google-cloud-sdk/completion.zsh.inc'; fi
lias v="vagrant"