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

@test "__tm_session_name: github.com/org/repo → org_repo" {
  local result
  result=$(fish --no-config -c "source $FUNCTIONS_DIR/__tm_session_name.fish; __tm_session_name 'github.com/org/repo'; or true")
  [ "$result" = "org_repo" ]
}

@test "__tm_session_name: github.com/org/my.repo → org_my-repo" {
  local result
  result=$(fish --no-config -c "source $FUNCTIONS_DIR/__tm_session_name.fish; __tm_session_name 'github.com/org/my.repo'; or true")
  [ "$result" = "org_my-repo" ]
}

@test "__tm_session_name: github.com/org/a/b → org_a_b" {
  local result
  result=$(fish --no-config -c "source $FUNCTIONS_DIR/__tm_session_name.fish; __tm_session_name 'github.com/org/a/b'; or true")
  [ "$result" = "org_a_b" ]
}
