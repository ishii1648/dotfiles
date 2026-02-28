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
| - | ○ | tmux / fish / ghostty | 設定変更時に既存機能が壊れる — キーバインドチェーン・関数依存・symlink など変更の影響範囲が広くリグレッションを手動確認している | [ADR-010](adr/010-dotfiles-regression-testing.md) |
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

- [ ] 設定変更後に主要なキーバインド・関数・symlink が壊れていないことを自動で確認できる
- [ ] リグレッションチェックを CI またはローカルコマンド一発で実行できる

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
