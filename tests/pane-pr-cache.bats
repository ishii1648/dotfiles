#!/usr/bin/env bats

# Layer 2: 統合テスト
# pane ごとの PR キャッシュ（/tmp/gh-pr-pane-<pane_id>）の書き手（configs/claude/statusline.js）と
# 読み手（configs/herdr/open-pr.sh）の契約を守る。ADR-034 の追加基準 2（チェーン依存）・
# 3（暗黙の契約: 1 行目 = 現在の PR / 2 行目以降 = 履歴、というファイル形式）に該当する。

setup() {
  PANE="bats_pane_${BATS_TEST_NUMBER}"
  CACHE="/tmp/gh-pr-pane-${PANE}"
  STUB_DIR="$BATS_TEST_TMPDIR/stub"
  # open-pr.sh は $HOME/.local/bin を PATH の先頭に前置するため、HOME ごと差し替えて
  # スタブを本物の fzf / herdr より先に解決させる。
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  FAKE_BIN="$FAKE_HOME/.local/bin"
  mkdir -p "$STUB_DIR" "$FAKE_BIN"

  # statusline.js の getPrInfo が叩く gh
  cat >"$STUB_DIR/gh" <<'EOS'
#!/bin/sh
[ -n "${STUB_PR_NUMBER:-}" ] || exit 1
printf '%s\n%s\nfalse\n' "$STUB_PR_NUMBER" "$STUB_PR_URL"
EOS
  # fzf は候補をファイルに落として 130（キャンセル）で抜ける
  cat >"$FAKE_BIN/fzf" <<EOS
#!/bin/sh
cat >"$BATS_TEST_TMPDIR/fzf-input"
exit 130
EOS
  # スクロールバックは空にして pane キャッシュ由来だけを見る
  printf '#!/bin/sh\nexit 0\n' >"$FAKE_BIN/herdr"
  chmod +x "$STUB_DIR/gh" "$FAKE_BIN/fzf" "$FAKE_BIN/herdr"

  rm -f "$CACHE"
}

teardown() {
  rm -f "$CACHE"
}

# statusline.js を 1 回分実行する: run_statusline <cwd> <pr-number|""> <pr-url>
run_statusline() {
  # getPrInfo の (cwd, branch) キャッシュを跨がないよう、呼び出しごとに別の cwd を使う。
  mkdir -p "$1"
  STUB_PR_NUMBER="$2" STUB_PR_URL="${3:-}" \
  HERDR_PANE_ID="$PANE" \
  PATH="$STUB_DIR:$PATH" \
    node configs/claude/statusline.js \
      <<<"{\"model\":{\"display_name\":\"t\",\"id\":\"x\"},\"workspace\":{\"current_dir\":\"$1\"},\"session_id\":\"batstest\"}" \
      >/dev/null 2>&1
}

# open-pr.sh を 1 回分実行し、fzf に渡った候補を ANSI 除去して返す
run_openpr_candidates() {
  HOME="$FAKE_HOME" HERDR_BIN_PATH="$FAKE_BIN/herdr" HERDR_ACTIVE_PANE_ID="$PANE" \
    bash configs/herdr/open-pr.sh >/dev/null 2>&1
  sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$BATS_TEST_TMPDIR/fzf-input"
}

@test "statusline.js: 表示中の PR が変わると前の PR が履歴に降りる" {
  command -v node >/dev/null || skip "node not installed"

  run_statusline "$BATS_TEST_TMPDIR/a" 1071 https://github.com/o/r/pull/1071
  [ "$(cat "$CACHE")" = "1071 https://github.com/o/r/pull/1071" ]

  run_statusline "$BATS_TEST_TMPDIR/b" 1073 https://github.com/o/r/pull/1073
  [ "$(cat "$CACHE")" = "1073 https://github.com/o/r/pull/1073
1071 https://github.com/o/r/pull/1071" ]

  # 同じ PR を続けて表示しても履歴は増えない
  run_statusline "$BATS_TEST_TMPDIR/b2" 1073 https://github.com/o/r/pull/1073
  [ "$(cat "$CACHE")" = "1073 https://github.com/o/r/pull/1073
1071 https://github.com/o/r/pull/1071" ]
}

@test "statusline.js: PR の無いブランチへ移っても履歴は消えない" {
  command -v node >/dev/null || skip "node not installed"

  run_statusline "$BATS_TEST_TMPDIR/a" 1073 https://github.com/o/r/pull/1073
  run_statusline "$BATS_TEST_TMPDIR/b" '' ''

  # 1 行目（現在）が空行になるだけで、履歴はそのまま残る
  [ "$(cat "$CACHE")" = "
1073 https://github.com/o/r/pull/1073" ]
}

@test "statusline.js: 履歴は 20 件でトリムされる" {
  command -v node >/dev/null || skip "node not installed"

  for n in $(seq 1 23); do
    run_statusline "$BATS_TEST_TMPDIR/n$n" "$n" "https://github.com/o/r/pull/$n"
  done

  [ "$(grep -c . "$CACHE")" -eq 21 ] # 現在 1 + 履歴 20
  [ "$(head -1 "$CACHE")" = "23 https://github.com/o/r/pull/23" ]
  [ "$(tail -1 "$CACHE")" = "3 https://github.com/o/r/pull/3" ]
}

@test "open-pr.sh: 1 行目だけ ★ を付け、履歴も候補に含める" {
  printf '1073 https://github.com/o/r/pull/1073\n1071 https://github.com/o/r/pull/1071\n' >"$CACHE"

  run run_openpr_candidates
  [ "$output" = "★ 現在のPR  https://github.com/o/r/pull/1073
  https://github.com/o/r/pull/1071" ]
}

@test "open-pr.sh: 現在の PR が無くても履歴だけで候補が出る" {
  printf '\n1073 https://github.com/o/r/pull/1073\n1071 https://github.com/o/r/pull/1071\n' >"$CACHE"

  run run_openpr_candidates
  [ "$output" = "  https://github.com/o/r/pull/1073
  https://github.com/o/r/pull/1071" ]
}

@test "open-pr.sh: 履歴化以前の形式（改行なしの 1 行）でも壊れない" {
  printf '1073 https://github.com/o/r/pull/1073' >"$CACHE"

  run run_openpr_candidates
  [ "$output" = "★ 現在のPR  https://github.com/o/r/pull/1073" ]
}

@test "契約: statusline.js が書いたファイルを open-pr.sh がそのまま読める" {
  command -v node >/dev/null || skip "node not installed"

  run_statusline "$BATS_TEST_TMPDIR/a" 1071 https://github.com/o/r/pull/1071
  run_statusline "$BATS_TEST_TMPDIR/b" 1073 https://github.com/o/r/pull/1073

  run run_openpr_candidates
  [ "$output" = "★ 現在のPR  https://github.com/o/r/pull/1073
  https://github.com/o/r/pull/1071" ]
}
