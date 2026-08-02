#!/usr/bin/env bats

# Layer 1: 静的解析テスト
# fish / bash スクリプトの構文チェック

@test "all .fish files pass fish -n syntax check" {
  local failed=()
  while IFS= read -r f; do
    if ! fish -n "$f" 2>/dev/null; then
      failed+=("$f")
    fi
  done < <(find configs/fish -name '*.fish' -type f)

  if [ ${#failed[@]} -gt 0 ]; then
    printf 'syntax error: %s\n' "${failed[@]}"
    return 1
  fi
}

@test "all .sh scripts pass bash -n syntax check" {
  local failed=()
  while IFS= read -r f; do
    # shebang が bash 以外（python 等）のファイルはスキップ
    local shebang
    shebang=$(head -1 "$f")
    case "$shebang" in
      *python*|*ruby*|*perl*|*node*) continue ;;
    esac
    if ! bash -n "$f" 2>/dev/null; then
      failed+=("$f")
    fi
  done < <(find scripts configs -name '*.sh' -type f)

  if [ ${#failed[@]} -gt 0 ]; then
    printf 'syntax error: %s\n' "${failed[@]}"
    return 1
  fi
}
