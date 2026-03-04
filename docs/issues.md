# 課題一覧

開発環境の改善課題を管理する。コンポーネントをまたぐ機能も含めて一元管理する。

## サマリ

| 対応済み | 対応可能 | コンポーネント | サマリ | ADR |
|:---:|:---:|:---|:---|:---|
| ✔ | ○ | tmux | Cmd キーを tmux で使えない — Cmd は OS レベルで処理されるため tmux に到達しない | [ADR-001](adr/001-tmux-cmd-key.md) |
| ✔ | △ | tmux | tmux 内でリンクをクリックできない — `mouse on` がマウスイベントをインターセプトし、Ghostty に届かない | [ADR-002](adr/002-tmux-link-click.md) |
| ✔ | ○ | tmux / claude | 通知クリックで tmux セッションに遷移できない — 通知発行で場所を伝え（ADR-003）、セッションリストの状態バッジで素早く遷移できるよう補完（ADR-007） | [ADR-003](adr/003-tmux-notification-click.md) [ADR-007](adr/007-tmux-claude-pane-state.md) |
| ✔ | ○ | tmux | terminal 上のテキストをコピーできない — `mouse on` がマウス選択をインターセプトし、OS のクリップボードにコピーできない | [ADR-004](adr/004-tmux-text-copy.md) |
| - | × | ~~tmux / ghostty~~ | ~~tmux セッション内外でペイン移動のキーバインドを共有できない — Ghostty は条件分岐付きキーバインドに非対応~~ | ~~[ADR-005](adr/005-tmux-pane-keybind-sharing.md)~~ |
| - | △ | tmux / claude | Claude permission ask 発生時にセッション移動が必要 — 内容閲覧と allow/deny 選択だけならセッション移動なしで対応したい | [ADR-009](adr/009-claude-permission-ask-inline-response.md) |
| ✔ | ○ | tmux / fish / ghostty | 設定変更時に既存機能が壊れる — キーバインドチェーン・関数依存・symlink など変更の影響範囲が広くリグレッションを手動確認している | [ADR-010](adr/010-dotfiles-regression-testing.md) |
| ✔ | ○ | claude | Claude セッションを PR ベースで追跡できない — セッション開始・終了・ツール出力から PR URL を自動収集して JSONL に蓄積したい | [ADR-011](adr/011-claude-session-index.md) |
| ✔ | ○ | fish / tmux / ghostty | 端末固有の設定が dotfiles に混入している — 会社 PC 専用の関数・スクリプトが dotfiles に含まれており、リポジトリの共有性・再利用性が損なわれている | [ADR-012](adr/012-fish-function-symlink-per-repo.md) |
| - | ○ | claude | permission ask で Claude の自律的な作業が中断される — 代替可能な Bash コマンドを生成するたびに承認ダイアログが発生し、観測・対応サイクルが手動になっている | [ADR-013](adr/013-claude-permission-ask-auto-block.md) [ADR-014](adr/014-claude-redirect-rules-auto-expansion.md) |
| ✔ | ○ | claude | Claude Code の settings.json が端末間で再現できない — hooks・permissions 等の共通設定が git 管理されておらず、新端末セットアップ時に手動コピーが必要 | [ADR-015](adr/015-claude-settings-json-base-local-merge.md) |
| ✔ | ○ | tmux / fish | SSH先で dotfiles をセットアップできない — リモート環境では tmux ネスト対応や Ghostty 不要設定など環境別の差異があり、既存の local override パターンで吸収する | [ADR-016](adr/016-dotfiles-remote-profile-support.md) |
| ✔ | ○ | claude | git commit の heredoc パターンで permission ask が発生する — `$()` command substitution が一律で検出され `permissions.allow` では回避不可 | [ADR-017](adr/017-pretooluse-hook-approve-safe-commands.md) |
| ✔ | ○ | fish / tmux / claude / nvim | setup が複数ステップに分散し理想状態の定義がない — 実行順序の依存や検証範囲の不統一があり、コマンド一発でセットアップ・検証できない | [ADR-018](adr/018-unified-setup-command.md) |
| ✔ | ○ | fish / tmux / claude / nvim | setup.sh の e2e テストをクリーン環境で実行できない — macOS 前提のため Docker が使えず、セットアップの完走を自動検証する手段がない | [ADR-019](adr/019-dotfiles-linux-support-and-e2e-testing.md) |
| ✔ | ○ | 複合 | ローカルオーバーライドと端末固有設定の管理が二重化している — 同じ「端末ごとに異なる設定」が gitignore と端末固有リポジトリに分散し手順が煩雑 | [ADR-020](adr/020-unify-local-override-into-terminal-repo.md) |
| ✔ | ○ | fish / tmux | SSH 先・tmux ネスト状態の判別が付きづらい — プロンプトに SSH インジケーターがなく、パススルーモードも背景色の微妙な変化のみで状態が分かりづらい | [ADR-021](adr/021-ssh-visual-indicator.md) |
| ✔ | ○ | fish / tmux | SSH 実行時にリモート先の tmux セッションへ自動で入りたい — `ssh` 実行後に毎回手動で tmux attach する手間を省きたい | [ADR-022](adr/022-ssh-auto-tmux-attach.md) |
| ✔ | ○ | tmux | tmux ネスト構成の採用理由が明文化されていない — ADR-016/021/022 がネスト前提だが設計判断の根拠が暗黙的 | [ADR-023](adr/023-tmux-nested-architecture-decision.md) |
| ✔ | ○ | claude | ADR 運用ルールが未整備で一貫性を保てない — 採用案の表記ぶれ・ADR 間矛盾チェックの欠如・Supersede フロー未定義 | [ADR-025](adr/025-adr-reference-skill.md) |
| ✔ | ○ | tmux / fish | パススルーモードの UI が直感的でない — 表示が実装寄り（`[PASSTHROUGH]`）で操作対象が分かりづらく、ネスト時にステータスバーが重複する | [ADR-026](adr/026-tmux-passthrough-ui-improvement.md) |
| ✔ | ○ | git / claude | 設定ファイル管理が複雑で端末固有リポへの依存が重い — .gitconfig は未配布、settings.json は jq マージ方式でメンテ性が悪い | [ADR-027](adr/027-config-copy-validate-pattern.md) |
| ✔ | ○ | git | SSH 鍵・gitconfig が手動管理で散在している — pub 鍵がリポ管理外、gitconfig が OS 非依存の単一ファイル、SSH セットアップが手動 | [ADR-028](adr/028-git-ssh-key-gitconfig-profile-separation.md) |
| ✔ | ○ | git | SSH 鍵の pub 鍵をリポ管理しているが秘密鍵を配布できない — 端末ごとに鍵ペアを生成すべきで pub 鍵のリポ管理が無意味 | [ADR-029](adr/029-per-terminal-ssh-key-generation.md) |
| ✔ | ○ | claude | lab 環境で Claude Code を安全に自律実行できない — Built-in Sandbox はツールバイパス問題があり、Docker コンテナ隔離 + Cloudflare Gateway が必要 | [ADR-030](adr/030-claude-code-docker-sandbox.md) |
| ✔ | ○ | 複合 | setup.sh に interactive / non-interactive モードがない — 環境によって入力を求められるケースがあり、CI や Docker e2e でのテスタビリティが低い | [ADR-031](adr/031-setup-interactive-mode.md) |
| ✔ | ○ | 複合 | setup.sh が 500 行超で保守・テストが困難 — 関数群が 1 ファイルに密集しユニットテスト不可、機能追加時の衝突リスクが高い | [ADR-032](adr/032-setup-sh-modularization.md) |
| ✔ | ○ | tmux | tmux popup 内でバグが多発するがテストがない — $TMUX 変数ネスティング・switch-client 失敗・ソケット管理等の壊れやすいパターンが未検証 | [ADR-033](adr/033-tmux-popup-regression-testing.md) |
| - | ○ | 複合 | e2e テストの追加基準が未定義 — すべてのエラーにテストを書くのは非限定的で、追加判断の運用ポリシーが必要 | [ADR-034](adr/034-e2e-test-addition-policy.md) |
| ✔ | ○ | claude | Claude Code 起動に 2〜5 秒かかる — SessionStart フックの `gh pr view` がネットワーク API を毎回呼び出しているため | [ADR-035](adr/035-claude-session-index-startup-optimization.md) |
| ✔ | ○ | claude | permission UI が何回表示されたか計測できない — Approve 操作は transcript に記録されず、PreToolUse hook で代替計測できるか不明 | [ADR-036](adr/036-claude-permission-ui-count-via-hook.md) |
| - | ○ | claude | permission UI 回数の絶対数では自律度を評価できない — 作業量が多いほど自然に増えるため、作業量で正規化した指標が必要 | [ADR-037](adr/037-claude-autonomy-rate-per-work-unit.md) |
| ✔ | ○ | claude | ADR 確定前に検証が必要なケースに運用が対応していない — 設計議論だけでは判断できない場合の Spike パターンが未定義 | [ADR-038](adr/038-adr-spike-validation-pattern.md) |
| ✔ | ○ | claude | session-index の pr_urls が空になる — ADR-035 で SessionStart の gh pr view を削除した結果、既存 PR があっても Bash ツールで URL を出力しない限り補完されない | [ADR-039](adr/039-session-index-pr-url-backfill-on-stop.md) |
| ✔ | ○ | claude | Stop フック backfill は過去セッション分を拾えない — ADR-039 の Stop フック方式は現セッション終了時のみ動作し、過去分や複数セッションの重複 API 呼び出しが解消されない | [ADR-040](adr/040-session-index-pr-url-backfill-cron-batch.md) |
| ✔ | ○ | claude | claude-stats が Permission UI 以外の人の介入を計測できない — mid-session メッセージ・AskUserQuestion・セッション数/PR など介入全般を可視化したい | [ADR-041](adr/041-claude-human-intervention-metrics-expansion.md) |

> ○ = 解決可能 / △ = 緩和可能（ワークアラウンド） / × = 対応不可

## 課題詳細

各課題の受け入れ条件（「〜できる」形式）を記載する。ADR の `## 結果` セクションはここを参照して達成状況をチェックする。

---

### ADR-009: Claude permission ask のインライン応答

**コンポーネント**: tmux / claude | **ADR**: [ADR-009](adr/009-claude-permission-ask-inline-response.md)

**受け入れ条件**:

- [ ] Claude permission ask の内容を tmux セッションに移動せずに確認できる
- [ ] allow / deny の選択を tmux セッションに移動せずに実行できる

---

### ADR-010: dotfiles リグレッションテスト

**コンポーネント**: tmux / fish / ghostty | **ADR**: [ADR-010](adr/010-dotfiles-regression-testing.md)

**受け入れ条件**:

- [x] `bats tests/` で全テストが PASS する
- [x] 全 .fish ファイルが `fish -n` で構文エラーなく通過する
- [x] Ghostty CSI シーケンスと tmux user-keys の対応が自動検証される
- [x] `__tm_session_name` の入出力がテストケースで検証される
- [x] tmux.conf の読み込みとキーバインド登録が自動検証される
- [x] パススルーモードの ON/OFF 状態遷移が自動検証される
- [x] CI の push/PR トリガーで全テストが自動実行される

---

### ADR-013 / ADR-014: Claude permission ask の自動ブロックと継続的拡張

**コンポーネント**: claude | **ADR**: [ADR-013](adr/013-claude-permission-ask-auto-block.md) [ADR-014](adr/014-claude-redirect-rules-auto-expansion.md)

**受け入れ条件**:

- [x] 代替可能な Bash コマンド（cat/find/grep/for/while/python -c 等）が permission ask なしに自動ブロックされる（ADR-013）
- [x] ブロック時に具体的な代替手段が Claude に伝わり、自律的にリトライできる（ADR-013）
- [ ] 新しい permission ask が発生した際に、原因コマンドが自動的にログに記録される（ADR-014）
- [ ] ログを元に redirect-to-tools.py へのルール追加が半自動化できる（ADR-014）

---

### ADR-015: Claude Code settings.json の共通・端末固有分離

**コンポーネント**: claude | **ADR**: [ADR-015](adr/015-claude-settings-json-base-local-merge.md)

**受け入れ条件**:

- [x] dotfiles clone 後に `configs/claude/setup.sh` を実行するだけで hooks・permissions が再現される
- [x] `~/.claude/settings.json` に端末固有設定（ANTHROPIC_BASE_URL 等）が含まれた状態で正しく動作する
- [x] dotfiles の `configs/claude/settings.json` に端末固有設定（secrets・プラグイン）が含まれない
- [x] 端末固有リポジトリの `setup.sh` 実行で settings.local.json がマージされる
- [x] `~/.claude/settings.json` が behind（マージ結果の方が新しい）場合、setup.sh が自動上書きする
- [x] `~/.claude/settings.json` にローカル編集（マージ結果にないキー・値）がある場合、setup.sh が差分を出力して `exit 1` で停止する

---

### ADR-012: 端末固有の設定を dotfiles から分離

**コンポーネント**: fish / tmux / ghostty | **ADR**: [ADR-012](adr/012-fish-function-symlink-per-repo.md)

**受け入れ条件**:

- [x] 端末固有の fish functions・conf.d ファイルが dotfiles の `git status` に現れなくなる
- [x] tmux.conf・ghostty/config から社内ツール（prtrack）への参照が除去される
- [x] dotfiles を別端末にクローンしても、端末固有の設定が混入しない
- [x] 既存の共通設定（`tm`, `gw_add`、tmux キーバインド等）が引き続き動作する
- [x] 端末固有リポジトリの setup script で端末固有ファイルを配置できる

---

### ADR-016: SSH先（リモート環境）での dotfiles セットアップ対応

**コンポーネント**: tmux / fish | **ADR**: [ADR-016](adr/016-dotfiles-remote-profile-support.md)

**受け入れ条件**:

- [x] `tms <host>` 実行時にローカル tmux が自動でパススルーモードに切り替わり、リモート tmux を直接操作できる
- [x] SSH 切断時に自動でローカル tmux に復帰する
- [x] F12 で手動でもパススルーモードをトグルできる
- [x] パススルーモード中はステータスバーの外観が変わり、モードが視覚的に判別できる
- [x] `tms <host>` で SSH 先の tmux セッションにアタッチ（なければ新規作成）できる
- [x] `setup-symlinks.sh --profile remote` で tmux の symlink も作成される
- [x] リモート用テンプレート (`tmux.remote.conf.example`) を `~/.tmux.local.conf` にコピーすることでリモート固有設定が適用される

---

### ADR-017: PreToolUse hook による安全なコマンドの自動承認

**コンポーネント**: claude | **ADR**: [ADR-017](adr/017-pretooluse-hook-approve-safe-commands.md)

**受け入れ条件**:

- [x] `git commit -m "$(cat <<'EOF'...EOF)"` パターンで permission ask が発生しない
- [x] approve 専用 hook が `redirect-to-tools.py`（block 専用）と別ファイルで管理されている
- [x] `$(cat <<'EOF'...EOF)` 以外の `$()` は引き続き permission ask が発生する

---

### ADR-018: setup コマンドの一本化と理想状態の宣言的管理

**コンポーネント**: fish / tmux / claude / nvim | **ADR**: [ADR-018](adr/018-unified-setup-command.md)

**受け入れ条件**:

- [x] `bash scripts/setup.sh` の一発実行で全コンポーネントのセットアップが完了する
- [x] `bash scripts/setup.sh --profile remote` でリモート環境用のセットアップが完了する（`.example` テンプレートのコピーを含む）
- [x] `bash scripts/setup.sh --dry-run` で全コンポーネントの状態を一括検証できる（symlink・fish 個別 symlink・Claude settings.json・マニフェスト target 実在チェックを含む）
- [x] `scripts/setup-manifest.yml` にコンポーネントを追加するだけで新コンポーネントのセットアップが組み込まれる
- [x] 既存の `configs/fish/setup.sh` と `configs/claude/setup.sh` がマニフェスト経由で呼び出される（`--dry-run` 伝播を含む）

---

### ADR-019: dotfiles の Linux 対応と Docker ベース e2e テスト

**コンポーネント**: fish / tmux / claude / nvim | **ADR**: [ADR-019](adr/019-dotfiles-linux-support-and-e2e-testing.md)

**受け入れ条件**:

- [x] `scripts/setup.sh --profile linux` がクリーンな Linux 環境（Docker コンテナ）で完走する
- [x] `scripts/setup.sh --dry-run --profile linux` がセットアップ後の環境で全項目 OK を返す
- [x] GitHub Actions の Linux runner で e2e テストが自動実行される

---

### ADR-020: ローカルオーバーライドを端末固有リポジトリに統合

**コンポーネント**: 複合 | **ADR**: [ADR-020](adr/020-unify-local-override-into-terminal-repo.md)

**受け入れ条件**:

- [x] README の「ローカルオーバーライド」セクションが廃止され、「端末固有設定」セクションに全ファイルが一覧化される
- [x] 端末固有リポジトリを持たない環境でも `.example` テンプレートから手動作成できる

---

### ADR-021: SSH 接続先・tmux ネスト状態の視覚的インジケーター

**コンポーネント**: fish / tmux | **ADR**: [ADR-021](adr/021-ssh-visual-indicator.md)

**受け入れ条件**:

- [x] SSH 接続時に fish プロンプトにホスト名が表示される
- [x] ローカル環境では fish プロンプトにホスト名が表示されない
- [x] SSH 接続時に tmux ステータスバーに SSH インジケーター（ホスト名等）が表示される
- [x] ローカル環境では tmux ステータスバーに SSH インジケーターが表示されない
- [x] tmux パススルーモード中にステータスバーにテキストインジケーター（例: `[PASSTHROUGH]`）が表示される
- [x] パススルーモード解除時にテキストインジケーターが消える

---

### ADR-022: SSH 実行時にリモート先の tmux セッションへ自動アタッチ

**コンポーネント**: fish / tmux | **ADR**: [ADR-022](adr/022-ssh-auto-tmux-attach.md)

**受け入れ条件**:

- [x] `ssh <host>` 実行時にリモート先の tmux セッションに自動でアタッチされる
- [x] リモートに既存の tmux セッションがない場合は新規作成される
- [x] 自動アタッチを無効にしたい場合のオプトアウト手段がある（例: `ssh --no-tmux` や環境変数）
- [x] `tms` コマンドとの機能的な重複・棲み分けが整理されている

---

### ADR-023: tmux ネスト構成（ローカル+リモート）の採用理由の明文化

**コンポーネント**: tmux | **ADR**: [ADR-023](adr/023-tmux-nested-architecture-decision.md)

**受け入れ条件**:

- [x] ネスト構成（ローカル tmux + リモート tmux）を採用した理由が ADR に記載されている
- [x] 代替案（ローカルのみ・リモートのみ等）との比較が記載されている
- [x] ネスト構成のコスト（パススルー切替・キーバインド衝突等）が記載されている
- [x] ADR-016/021/022 がこの決定に依拠していることが明記されている

---

### ADR-025: ADR 運用ルール・テンプレートを reference skill として集約する

**コンポーネント**: claude | **ADR**: [ADR-025](adr/025-adr-reference-skill.md)

**受け入れ条件**:

- [x] `adr-reference` skill が存在し、ADR テンプレート・ステータス定義・Supersede フロー・表記ルールが記載されている
- [x] 設計案セクションの構造ルールが定義されている（見出しレベルで独立案を区別、各案に採用/却下ラベル必須）
- [x] ステータスの種類と遷移ルールが定義されている（Draft / 採用済み / 廃止 / 部分廃止 / 却下）
- [x] Supersede 時の双方向リンク記載フローが定義されている
- [x] 関連 ADR フィールド（依存・関連）の記載ルールが定義されている
- [x] `create-adr` スキルが `adr-reference` skill を参照している
- [x] `development.md` の ADR 関連記述が skill への参照に簡略化されている
- [x] 既存の ADR（001〜023）が新テンプレートのフォーマットに書き換えられている
- [x] `adr-ship` の完了処理で `reference.md` の ADR 一覧セクションが自動更新される
- [x] `reference.md` の ADR 一覧が既存の全 ADR（001〜023）を網羅している

---

### ADR-026: tmux パススルーモードの UI 改善

**コンポーネント**: tmux / fish | **ADR**: [ADR-026](adr/026-tmux-passthrough-ui-improvement.md)

**受け入れ条件**:

- [x] パススルーモード ON 時にローカル tmux のステータスバーが非表示になる
- [x] パススルーモード OFF 時にローカル tmux のステータスバーが通常表示に復帰する
- [x] F12 手動トグルで上記の表示切り替えが動作する
- [x] `tms` / `ssh` の自動パススルーで上記の表示切り替えが動作する
- [x] ~~パススルーモード OFF 時のステータスバー表示が操作対象レイヤー（LOCAL）を示す~~ → 不要と判断し削除
- [x] SSH window 以外でパススルーモードを手動有効化する機能（F12）が削除されている
- [x] SSH 接続時に自動でリモート側の tmux が操作対象になる（F12 で LOCAL に切り替え可）

---

### ADR-028: Git SSH 鍵・gitconfig プロファイル分離

**コンポーネント**: git | **ADR**: [ADR-028](adr/028-git-ssh-key-gitconfig-profile-separation.md)

**受け入れ条件**:

- ~~pub 鍵（`private_ed25519_github.pub` / `private_ed25519_github_sign.pub`）が `configs/git/` でリポジトリ管理されている~~ （ADR-029 で廃止）
- [x] `configs/git/gitconfig`（linux 用）に `[credential]` セクションが含まれない
- [x] `configs/git/gitconfig.macos`（full/remote 用）に `[credential] helper = osxkeychain` が含まれる
- [x] `setup.sh --dry-run` で full プロファイル時に `gitconfig.macos` が参照される
- [x] `setup.sh --dry-run --profile linux` で `gitconfig`（linux 版）が参照される
- [x] `scripts/setup-manifest.local.yml.example` が記入例として存在する
- [x] `scripts/setup-manifest.local.yml` が存在する場合、ベースマニフェストと deep merge される
- [x] overlay の `setup_args` の各キーが `SETUP_` prefix + 大文字化で環境変数としてスクリプトに渡される
- [x] `setup-github-ssh.sh` の dry-run で ~/.ssh/config 追加・user.signingkey 設定・ssh-add コマンドが表示される
- [x] `setup-github-ssh.sh` が環境変数未設定時に WARN を出して skip する

---

### ADR-027: 設定ファイルの管理を copy + validate 方式に統一する

**コンポーネント**: git / claude | **ADR**: [ADR-027](adr/027-config-copy-validate-pattern.md)

**受け入れ条件**:

- [x] `.gitconfig` が `configs/git/gitconfig` に移動され、`credential.helper` と `[include]` が除去されている
- [x] `setup-manifest.yml` に git コンポーネントが定義され、`copies: if_missing: true` で `~/.gitconfig` に配布される
- [x] `setup-manifest.yml` の claude コンポーネントに `copies: if_missing: true` で `~/.claude/settings.json` が配布される
- [x] `configs/claude/setup.sh` から jq マージロジックが廃止されている
- [x] `setup.sh` が validate 機能を持ち、gitconfig 型（`git config --file --get`）で共通設定の存在をチェックできる
- [x] `setup.sh` が validate 機能を持ち、json 型（`jq`）で共通キーの存在をチェックできる
- [x] validate 失敗時に WARN を出力して続行する（exit 1 しない）
- [x] `setup.sh --dry-run` で validate チェックが実行される

---

### ADR-029: 端末ごとの SSH 鍵生成方式への移行

**コンポーネント**: git | **ADR**: [ADR-029](adr/029-per-terminal-ssh-key-generation.md)

**受け入れ条件**:

- [x] `configs/git/` から pub 鍵ファイル（`private_ed25519_github.pub` / `private_ed25519_github_sign.pub`）が削除されている
- [x] README に鍵生成 → GitHub 登録 → overlay manifest 設定 → setup.sh 実行のフローが記載されている
- [x] ADR-028 のステータスが `部分廃止（ADR-029 で一部変更）` に更新されている
- [x] ADR-028 の受け入れ条件から pub 鍵リポ管理の項目が除外されている

---

### ADR-030: lab 環境の Claude Code を Docker コンテナで隔離実行する

**コンポーネント**: claude | **ADR**: [ADR-030](adr/030-claude-code-docker-sandbox.md)

**受け入れ条件**:

- [x] `configs/claude/docker/Dockerfile` が存在し、debian:bookworm-slim ベースで Node.js・git・gh CLI・非 root ユーザー `claude` が定義されている
- [x] `configs/claude/docker/entrypoint.sh` が存在し、SSH 鍵の RO → writable コピー、パーミッション修正、claude ユーザーへの権限ドロップ、Claude Code インストールが実装されている
- [x] `configs/claude/docker/run.sh` が存在し、deny-by-default マウント構成（プロジェクトディレクトリ R/W、~/.ssh RO、~/.gitconfig・~/.config/gh は存在時のみ）で `claude --dangerously-skip-permissions` を起動する
- [x] `run.sh` が `~/.claude` マウントで subscription 認証を共有し、API トークンをコンテナ内に永続保存しない
- [x] `docker build` + `run.sh <project-dir>` でコンテナが起動し、Claude Code のヘルプが表示される

---

### ADR-031: setup.sh に interactive / non-interactive モードを追加する

**コンポーネント**: 複合 | **ADR**: [ADR-031](adr/031-setup-interactive-mode.md)

**受け入れ条件**:

- [x] `bash scripts/setup.sh --non-interactive` で確認プロンプトなしにセットアップが完走する
- [x] `bash scripts/setup.sh --interactive` で破壊的操作・パッケージインストール前に確認プロンプトが表示される
- [x] オプション未指定時に TTY 接続の有無で interactive / non-interactive が自動判定される
- [x] `--dry-run` 指定時は常に non-interactive として動作する
- [x] 委譲先の setup.sh に `SETUP_INTERACTIVE` 環境変数でモードが伝播される
- [x] `tests/Dockerfile` で `--non-interactive` が明示的に指定されている

---

### ADR-032: setup.sh のモジュール分割

**コンポーネント**: 複合 | **ADR**: [ADR-032](adr/032-setup-sh-modularization.md)

**受け入れ条件**:

- [x] `scripts/lib/` ディレクトリが存在し、`colors.sh`, `symlink.sh`, `copy.sh`, `validate.sh`, `manifest.sh`, `deps-macos.sh` が配置されている
- [x] `scripts/setup.sh` が `scripts/lib/*.sh` を source して動作する
- [x] `scripts/setup.sh` のメイン部分が約 100 行以下に圧縮されている
- [x] `bash scripts/setup.sh --dry-run` が分割前と同じ出力・終了コードを返す
- [x] `bash scripts/setup.sh --dry-run --profile remote` が分割前と同じ出力・終了コードを返す
- [x] Docker e2e テスト（`docker build -f tests/Dockerfile .`）が分割後も PASS する
- [x] 各 lib ファイルが単独で `bash -n` 構文チェックを通過する

---

### ADR-033: tmux popup リグレッションテスト

**コンポーネント**: tmux | **ADR**: [ADR-033](adr/033-tmux-popup-regression-testing.md)

**受け入れ条件**:

- [x] popup 内で `$TMUX` 変数をクリアして tmux コマンドが正常実行できることが検証される
- [x] `display-popup -E "fish -c '...'"` パターンで Fish 関数が正常に起動・終了することが検証される
- [x] `prtrack-popup.sh` のソケットパス抽出・セッション作成・detach が検証される
- [x] popup の正常終了・強制終了がホスト側 tmux に影響しないことが検証される
- [x] `bats tests/popup.bats` が CI で自動実行される

---

### ADR-035: Claude Code 起動時の session-index.sh ネットワーク呼び出し最適化

**コンポーネント**: claude | **ADR**: [ADR-035](adr/035-claude-session-index-startup-optimization.md)

**受け入れ条件**:

- [x] `configs/claude/scripts/session-index.sh` から `gh pr view` の呼び出しが削除されている
- [x] セッション開始後に `gh pr` コマンドを実行した際、PostToolUse フックが PR URL を JSONL に記録できる
- [x] PR URL なしで記録されたレコードが Stop フックにより PR URL で補完される
- [x] Claude Code の起動時間（SessionStart フック完了まで）が体感で 2 秒以内になる

---

### ADR-036: Notification hook による permission UI 表示回数の計測

**コンポーネント**: claude | **ADR**: [ADR-036](adr/036-claude-permission-ui-count-via-hook.md)

**受け入れ条件**:

- [x] `Notification: permission_prompt` hook が permission UI 表示時に発火することが確認されている
- [x] `permission-log.sh` が `Notification: permission_prompt` hook として登録され、セッションIDとタイムスタンプをログに記録できる
- [x] `~/.claude/logs/permission.log` に permission UI 表示が記録される
- [x] transcript の `[Request interrupted by user for tool use]` と合算せずとも、ログのみで permission UI 表示回数（Approve + Deny 合算）が集計できる
- [x] `permission-ui-server.py` が port 18765 で起動し、`http://localhost:18765` でグラフが表示される
- [x] session-index.jsonl と permission.log を結合して PR ごとの permission UI 表示回数が棒グラフで確認できる

---

### ADR-037: 作業量で正規化した Claude 自律度指標の導入

**コンポーネント**: claude | **ADR**: [ADR-037](adr/037-claude-autonomy-rate-per-work-unit.md)

**受け入れ条件**:

- [ ] permission UI 間の tool_use 数（自律的に動けたストレッチの長さ）が集計できる
- [ ] PR ごとに中央値・平均値が算出され、ダッシュボードに表示される
- [ ] 作業量（絶対数）に依存せず、PR 間で自律度を比較できる

---

### ADR-038: ADR 確定前検証（Spike）パターンの導入

**コンポーネント**: claude | **ADR**: [ADR-038](adr/038-adr-spike-validation-pattern.md)

**受け入れ条件**:

- [x] `adr-reference` skill に `Spike中` ステータスが定義されている
- [x] `Spike中` から `Draft`（設計確定）への遷移ルールが `adr-reference` skill に記載されている
- [x] `development.md` に Spike フロー（`create-adr` → Spike実装 → 検証 → Draft 復帰 → `adr-ship`）が記述されている
- [x] `adr-ship` skill に `Spike中` ステータスの ADR には適用しないガードが明記されている

---

### ADR-039: Stop フックで既存 PR URL を補完する

**コンポーネント**: claude | **ADR**: [ADR-039](adr/039-session-index-pr-url-backfill-on-stop.md)

**受け入れ条件**:

- [x] 既存 PR があるブランチのセッション終了後、`session-index.jsonl` の対象レコードの `pr_urls` に PR URL が記録される
- [x] セッション中に `gh pr view` 等の Bash コマンドを実行しなかった場合でも `pr_urls` が補完される
- [x] `pr_urls` が既に埋まっている場合は `gh pr view` を実行しない（余分な API 呼び出しを避ける）
- [x] Stop フックのタイムアウト（10 秒）内に補完処理が完了する

---

### ADR-040: session-index pr_urls バックフィルを cron バッチ方式に移行する

**コンポーネント**: claude | **ADR**: [ADR-040](adr/040-session-index-pr-url-backfill-cron-batch.md)

**受け入れ条件**:

- [x] `session-index.jsonl` の `pr_urls` が空の全エントリが定期的に `gh pr view` で補完される
- [x] ADR-039 採用以前に記録された過去セッション分の `pr_urls` も補完される
- [x] 同一 branch の複数セッションに対して `gh pr view` は 1 回のみ呼ばれる
- [x] macOS では launchd エージェントが `~/Library/LaunchAgents/` に登録され、毎時・ログイン時に実行される
- [x] `session-index-stop.sh` から backfill ロジック（else ブランチ）が削除されシンプルな形に戻る
- [x] ADR-039 で作成した `session-index-backfill.py` が削除される

---

### ADR-041: claude-stats の人の介入指標を拡張する

**コンポーネント**: claude | **ADR**: [ADR-041](adr/041-claude-human-intervention-metrics-expansion.md)

**受け入れ条件**:

- [x] PR に紐づくセッションの mid-session ユーザーメッセージ数（初回プロンプト・コマンド出力除外）が PR ごとに集計されてダッシュボードに表示される
- [x] PR ごとの Permission UI 発生率（perm_count / tool_use_total）がダッシュボードに表示される
- [x] PR ごとの AskUserQuestion 呼び出し回数がダッシュボードに表示される
- [x] PR ごとのセッション数（同一 PR に対して起動した Claude セッションの数）がダッシュボードに表示される
- [x] PR に紐づかないセッションはすべての指標から除外される

---

### ADR-034: e2e テストの追加基準と運用ポリシー

**コンポーネント**: 複合 | **ADR**: [ADR-034](adr/034-e2e-test-addition-policy.md)

**受け入れ条件**:

- [ ] テスト追加基準（再発実績・チェーン依存・暗黙の契約・手動検証困難）が `docs/development.md` に記載されている
- [ ] テストを追加しないケース（一度きりの typo・外部ツールのバグ・UI の見た目）が `docs/development.md` に記載されている
- [ ] バグ修正時のテスト追加フロー（基準確認 → 修正と同一コミットでテスト追加）が `docs/development.md` に記載されている

