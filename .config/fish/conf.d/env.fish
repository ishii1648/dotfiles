# Environment variables for development tools

# Go configuration
set -gx GOPATH $HOME/go
set -gx GOOS darwin
set -gx GOARCH amd64
set -gx GO111MODULE on

# Editor configuration
set -gx EDITOR vim
set -gx KUBE_EDITOR vim

# Package managers
set -gx AQUA_PROGRESS_BAR true
set -gx AQUA_ROOT_DIR (aqua root-dir)
set -gx NPM_CONFIG_PREFIX $HOME/.local/share/npm-global
