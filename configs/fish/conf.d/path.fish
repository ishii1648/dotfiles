# PATH configuration

fish_add_path $GOPATH/bin
fish_add_path $AQUA_ROOT_DIR/bin
fish_add_path $NPM_CONFIG_PREFIX/bin
# --move で必ず先頭に置く。fish_add_path は既に fish_user_paths にある path を並べ替えないため、
# これが無いと永続化済みの順序 (aqua の bin が先) が残り、~/.local/bin/gh の ghtkn ラッパーが
# aqua の gh に負けて機能しない。両ディレクトリで名前が衝突するのは gh だけ。
fish_add_path --move $HOME/.local/bin

# Cargo/Rust
test -f "$HOME/.cargo/env.fish" && source "$HOME/.cargo/env.fish"
