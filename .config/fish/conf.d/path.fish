# PATH configuration

fish_add_path $GOPATH/bin
fish_add_path $AQUA_ROOT_DIR/bin
fish_add_path $NPM_CONFIG_PREFIX/bin
fish_add_path $HOME/.local/bin

# Cargo/Rust
test -f "$HOME/.cargo/env.fish" && source "$HOME/.cargo/env.fish"
