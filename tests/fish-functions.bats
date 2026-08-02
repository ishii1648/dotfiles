#!/usr/bin/env bats

# Layer 2: fish 関数のロードと単体テスト

FUNCTIONS_DIR="configs/fish/functions"

@test "all fish functions load successfully" {
  local failed=()
  while IFS= read -r f; do
    local name
    name=$(basename "$f" .fish)
    if ! fish --no-config -c "source $f; functions -q $name" 2>/dev/null; then
      failed+=("$name")
    fi
  done < <(find "$FUNCTIONS_DIR" -name '*.fish' -type f \
    ! -name 'fish_right_prompt.fish')

  if [ ${#failed[@]} -gt 0 ]; then
    printf 'failed to load: %s\n' "${failed[@]}"
    return 1
  fi
}

# ADR-078: ssh ラッパがタブラベルに出すホスト名の抽出
ssh_tab_host() {
  fish --no-config -c "source $FUNCTIONS_DIR/_ssh_tab_host.fish; _ssh_tab_host $*; or true"
}

@test "_ssh_tab_host: host" {
  [ "$(ssh_tab_host example.com)" = "example.com" ]
}

@test "_ssh_tab_host: user@host strips user" {
  [ "$(ssh_tab_host root@example.com)" = "example.com" ]
}

@test "_ssh_tab_host: -p 2222 host skips option value" {
  [ "$(ssh_tab_host -p 2222 example.com)" = "example.com" ]
}

@test "_ssh_tab_host: -oPort=22 host handles attached option" {
  [ "$(ssh_tab_host -oPort=22 example.com)" = "example.com" ]
}

@test "_ssh_tab_host: host cmd ignores remote command" {
  [ "$(ssh_tab_host example.com uptime)" = "example.com" ]
}

@test "_ssh_tab_host: no host yields empty" {
  [ -z "$(ssh_tab_host -V)" ]
}
