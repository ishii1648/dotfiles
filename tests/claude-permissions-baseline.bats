#!/usr/bin/env bats

# ADR-092: permissions ベースライン検査
#
# ADR-034 の追加基準 3「暗黙の契約」と 4「手動検証が困難」に該当する。
# - Claude Code の permission 記法は `Bash(cmd *)` と `Bash(cmd:*)` が等価という
#   ドキュメントの記述に依存しており、正規化が壊れると欠落を誤検出する
# - deny の欠落は動かしても何も起きないため、目視では気づけない（ADR-092 の発端）

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SETUP="$REPO_ROOT/configs/claude/setup.sh"
  BASELINE="$REPO_ROOT/configs/claude/permissions-baseline.json"
  DEST="$BATS_TEST_TMPDIR/settings.json"

  # setup.sh の後続セクション（skills / launchd）が実機の $HOME を触らないようにする
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME/.claude"

  # aqua の shim は $HOME 配下のレジストリを参照するため、差し替えた HOME では jq が動かない。
  # aqua の bin を PATH から外してシステムの jq を使う（該当パスが無い環境では何も変わらない）
  PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v 'aquaproj-aqua' | paste -sd: -)"
  export PATH

  N_REQUIRED=$(jq '.required.deny | length' "$BASELINE")
  N_RECOMMENDED=$(jq '.recommended.allow | length' "$BASELINE")
}

run_setup() {
  # bats の run は関数のため、変数代入プレフィックスではなく export で渡す
  # （bats は各テストを別プロセスで実行するのでテスト間には持ち越さない）
  export HOME="$FAKE_HOME"
  export CLAUDE_SETTINGS_DEST="$DEST"
  export SETUP_PROFILE=full
  run bash "$SETUP" "$@"
}

write_dest() {
  printf '%s\n' "$1" >"$DEST"
}

@test "空の permissions では required deny がすべて欠落として報告される" {
  write_dest '{"permissions":{"deny":[],"allow":[]}}'
  run_setup --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"required deny が $N_REQUIRED 件欠けている"* ]]
  [[ "$output" == *"recommended allow が $N_RECOMMENDED 件未設定"* ]]
}

@test "ベースラインをすべて満たす配布先は OK と報告される" {
  local deny allow
  deny=$(jq -c '.required.deny' "$BASELINE")
  allow=$(jq -c '.recommended.allow' "$BASELINE")
  write_dest "{\"permissions\":{\"deny\":$deny,\"allow\":$allow}}"
  run_setup --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"permissions baseline: ✓ OK"* ]]
  [[ "$output" != *"recommended allow が"* ]]
}

@test "末尾 :* は空白 * と等価に扱われ欠落と誤判定されない" {
  write_dest '{"permissions":{"deny":["Bash(sudo:*)"],"allow":["Bash(git log *)"]}}'
  run_setup --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"required deny が $((N_REQUIRED - 1)) 件欠けている"* ]]
  [[ "$output" == *"recommended allow が $((N_RECOMMENDED - 1)) 件未設定"* ]]
  [[ "$output" != *"Bash(sudo *)"* ]]
  [[ "$output" != *"Bash(git log:*)"* ]]
}

@test "--dry-run は配布先を書き換えない" {
  write_dest '{"permissions":{"deny":[],"allow":[]}}'
  local before
  before=$(cat "$DEST")
  run_setup --dry-run
  [ "$status" -eq 0 ]
  [ "$(cat "$DEST")" = "$before" ]
}

@test "--fix は端末固有のエントリを保持したまま欠落分だけ追加する" {
  write_dest '{"permissions":{"defaultMode":"acceptEdits","deny":["Bash(kubectl *)"],"allow":["Bash(tmux *)"],"ask":["Bash(git push -f *)"],"additionalDirectories":["~/somewhere"]}}'
  run_setup --fix
  [ "$status" -eq 0 ]

  # 端末固有の値が残っている
  [ "$(jq -r '.permissions.defaultMode' "$DEST")" = "acceptEdits" ]
  [ "$(jq '.permissions.deny | index("Bash(kubectl *)") != null' "$DEST")" = "true" ]
  [ "$(jq '.permissions.allow | index("Bash(tmux *)") != null' "$DEST")" = "true" ]
  [ "$(jq '.permissions.ask | length' "$DEST")" -eq 1 ]
  [ "$(jq '.permissions.additionalDirectories | length' "$DEST")" -eq 1 ]

  # ベースラインが追加されている
  [ "$(jq '.permissions.deny | length' "$DEST")" -eq "$((N_REQUIRED + 1))" ]
  [ "$(jq '.permissions.allow | length' "$DEST")" -eq "$((N_RECOMMENDED + 1))" ]
  [ -f "$DEST.bk" ]
}

@test "--fix は冪等で重複を作らない" {
  write_dest '{"permissions":{"deny":[],"allow":[]}}'
  run_setup --fix
  [ "$status" -eq 0 ]
  local deny_first allow_first
  deny_first=$(jq '.permissions.deny | length' "$DEST")
  allow_first=$(jq '.permissions.allow | length' "$DEST")

  run_setup --fix
  [ "$status" -eq 0 ]
  [ "$(jq '.permissions.deny | length' "$DEST")" -eq "$deny_first" ]
  [ "$(jq '.permissions.allow | length' "$DEST")" -eq "$allow_first" ]
  [ "$(jq '.permissions.deny | unique | length' "$DEST")" -eq "$deny_first" ]
}

@test "配布先の permissions は同期対象から外れている" {
  # dotfiles 側が permissions を持たないこと（持つと MERGE_KEYS 経由で配列が置換される）
  run jq -e '.permissions' "$REPO_ROOT/configs/claude/settings.json"
  [ "$status" -ne 0 ]

  # MERGE_KEYS に配列値のキーを入れないこと
  run grep -E '^MERGE_KEYS=' "$SETUP"
  [ "$status" -eq 0 ]
  [[ "$output" != *"permissions"* ]]
}
