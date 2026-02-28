# Environment variables for development tools

# Go configuration
set -gx GOPATH $HOME/go
set -gx GO111MODULE on

# Editor configuration
set -gx EDITOR vim
set -gx KUBE_EDITOR vim

# Package managers
set -gx AQUA_GLOBAL_CONFIG $HOME/.config/aquaproj-aqua/aqua.yaml
set -gx AQUA_PROGRESS_BAR true
if command -q aqua
    set -gx AQUA_ROOT_DIR (aqua root-dir)
else
    set -gx AQUA_ROOT_DIR $HOME/.local/share/aquaproj-aqua
end
set -gx NPM_CONFIG_PREFIX $HOME/.local/share/npm-global

