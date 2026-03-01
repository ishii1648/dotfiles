#!/usr/bin/env bats

# Layer 1: Ghostty CSI ↔ tmux user-keys チェーン整合性テスト

setup() {
  GHOSTTY_CONFIG="configs/ghostty/config"
  TMUX_CONFIG="configs/tmux/tmux.conf"
}

# Ghostty config から CSI シーケンスを抽出（\x1b[...形式 → \e[...形式に正規化）
extract_ghostty_csi() {
  grep -oP '\\x1b\[\d+;\d+[u~]' "$GHOSTTY_CONFIG" \
    | sed 's/\\x1b/\\e/g' \
    | sort -u
}

# tmux config から user-keys の CSI シーケンスを抽出
extract_tmux_userkeys() {
  grep -oP 'user-keys\[\d+\]\s+"\K\\e\[\d+;\d+[u~]' "$TMUX_CONFIG" \
    | sort -u
}

@test "all Ghostty CSI sequences for user-keys have corresponding tmux user-keys" {
  local missing=()
  # Ghostty の user-keys 用 CSI（;9A/B および ;9~ パターン）を抽出し \e 形式に正規化
  while IFS= read -r seq; do
    if ! grep -qF "$seq" "$TMUX_CONFIG"; then
      missing+=("$seq")
    fi
  done < <(grep -oP '\\x1b\[\d+;9[A-Z~]' "$GHOSTTY_CONFIG" \
    | sed 's/\\x1b/\\e/g' \
    | sort -u)

  if [ ${#missing[@]} -gt 0 ]; then
    printf 'missing tmux user-key for Ghostty CSI: %s\n' "${missing[@]}"
    return 1
  fi
}

@test "user-keys[0] through user-keys[12] are all defined" {
  local missing=()
  for i in $(seq 0 12); do
    if ! grep -qP "user-keys\[$i\]" "$TMUX_CONFIG"; then
      missing+=("user-keys[$i]")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    printf 'missing: %s\n' "${missing[@]}"
    return 1
  fi
}

@test "each UserN has a corresponding bind-key" {
  local missing=()
  for i in $(seq 0 12); do
    if ! grep -qP "bind-key\s+(-T\s+\S+\s+|-n\s+)User$i\b" "$TMUX_CONFIG"; then
      missing+=("User$i")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    printf 'missing bind-key for: %s\n' "${missing[@]}"
    return 1
  fi
}
