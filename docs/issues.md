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
| ✔ | ○ | claude | ADR 確定前に検証が必要なケースに運用が対応していない — 設計議論だけでは判断できない場合の Spike パターンが未定義 | [ADR-035](adr/035-adr-spike-validation-pattern.md) |
| ✔ | ○ | claude | ADR-040 採用後も hook が他人の PR URL を session-index に混入させる — PostToolUse/Stop hook の正規表現スキャンがバッチの正確な補完を妨害しバグが永続する | [ADR-036](adr/036-remove-obsolete-pr-url-hooks.md) |
| ✔ | ○ | claude | .claude/ サブディレクトリへのファイル操作で permission UI が発生する — スキル・エージェント定義の Write/Edit が毎回中断され自律作業が妨げられる | [ADR-037](adr/037-pretooluse-hook-approve-claude-subdir-file-ops.md) |
| ✔ | ○ | claude | .claude/ サブディレクトリへの Read 操作で permission UI が発生する — ADR-037 で Write/Edit の hook 不呼び出しが判明したが、Read は通常の permission system を経由する可能性があり検証が必要 | [ADR-038](adr/038-pretooluse-hook-approve-claude-subdir-read.md) |
| ✔ | ○ | claude | hooks で参照されるスクリプトが実在しなくても validate が検出できない — if_missing: true コピー後に dotfiles 側で hook を削除しても dest の古いエントリが残り hook error が発生する | [ADR-039](adr/039-validate-hooks-script-existence.md) |
| ✔ | ○ | claude | Spike ADR のライフサイクルが未定義で adr-ship が誤って採用済みにする — Spike ADR を `Spike完了` で終了させ adr-ship 対象外とする運用ルールが必要 | [ADR-040](adr/040-spike-adr-lifecycle.md) |
| ✔ | ○ | claude | settings.json の dotfiles 管理キー変更がデプロイ先に反映されない — `if_missing: true` で初回のみコピーされるため hooks 等の変更が伝播しない | [ADR-041](adr/041-settings-json-managed-keys-sync.md) |
| - | ○ | claude | hook の複雑性が増すにつれ settings.json の肥大化・重複エントリ・変更理由の喪失が発生する — ディスパッチャ方式または責務統合で構造的に対処したい | [ADR-042](adr/042-hook-scalability-architecture.md) |
| - | ○ | claude | Docker サンドボックスのネットワーク egress が無制限 — deny ルール単体では根本的な対策にならず、ネットワーク層での制御が必要 | [ADR-043](adr/043-docker-sandbox-network-egress-control.md) |
| ✔ | ○ | tmux / fish | tmw_pick のデフォルトが worktree 強制で煩雑 — 大多数のリポジトリはメインで直接開くのが望ましいが、都度 conf に追記が必要 | [ADR-044](adr/044-tmw-default-direct-session-instead-of-worktree.md) |
| - | △ | tmux / ghostty | 複数 Claude セッションを常時俯瞰できない — prefix+s の都度 popup のみで、ブラウザのタブに相当する常時表示・即時切り替え UI がない | [ADR-045](adr/045-claude-session-always-on-display-ui.md) |
| ✔ | ○ | tmux / fish | ADR-045 で追加した Claude セッション statusbar 表示が過剰 — 常時表示の恩恵1点に対し表示・操作領域の増加コストが大きく、popup で充分 | [ADR-046](adr/046-statusbar-popup-role-separation.md) |
| - | △ | ghostty / tmux | Ghostty AppleScript で Claude セッション常時俯瞰サイドバーを実現できるか未検証 — tmux レイヤー内では switch-client で消えるが Ghostty レベルの分割なら不変なはず | [ADR-047](adr/047-ghostty-applescript-claude-sidebar.md) |
| ✔ | ○ | claude | 1M context モデルで auto-compaction 閾値が高すぎ推論品質が劣化する — デフォルト 80%+ では MRCR 17pt 低下、推論の捏造・修正無視が発生 | [ADR-048](adr/048-claude-autocompact-threshold-override.md) |
| ✔ | ○ | tmux / ghostty | prtrack popup の状態が毎回リセットされ操作モデルが非対称 — display-popup はスクロール履歴を失い、他 session と異なる操作感 | [ADR-049](adr/049-prtrack-permanent-session-instead-of-popup.md) |
| - | ○ | claude | Skill ツールの呼び出し回数が把握できない — どのスキルが頻繁に使われているか分からず、改善優先度の判断ができない | — |
| ✔ | ○ | tmux / claude | dispatch/orchestrate の起動に毎回ターミナルで手入力が必要 — popup ランチャーでリポジトリ選択・モード切替・prompt 入力を一箇所に集約する | [ADR-056](adr/056-dispatch-orchestrate-popup-launcher.md) |
| - | ○ | fish / tmux | dispatch 後にフォーカスが自動遷移する — `dispatch_launcher.fish` の `run-shell -b` 内 `switch-client` が popup 閉幕後にワーカーセッションへ強制移動する | — |
| ✔ | ○ | claude | orchestrate がフェーズ分離を構造的に強制できない — v2.0/v3.0 の簡素化で dispatch と実質同じになり、エージェントチェーンとハンドオフ文書が失われている | [ADR-060](adr/060-orchestrate-v4-agent-chain-restoration.md) |
| ✔ | ○ | tmux / fish / claude | popup ランチャーのトップレベルが repos/PRs で利用頻度が偏る — claude/codex の二値モードに整理し、codex 起動を素早くできるようにする | [ADR-061](adr/061-popup-launcher-claude-codex-modes.md) |
| ✔ | ○ | tmux / fish / claude | popup ランチャーの codex モードが起動のみで dispatch 挙動を伴わない — claude モードと同等の worktree 作成 + 初期プロンプト投入を `--launcher` フラグで共通化する | [ADR-062](adr/062-popup-launcher-codex-dispatch-phase2.md) |
| - | ○ | tmux / fish / claude / codex | tmux セッションリストで codex 起動中ペインの状態が分からない — Claude 用の pane_state 機構を汎用化し codex hooks で同等に扱う | [ADR-063](adr/063-tmux-codex-pane-state.md) |
| ✔ | ○ | tmux / fish / claude | popup ランチャーで `no-worktree-repos` 対象を開くと直前のブランチで起動する — メインworktreeのデフォルトブランチに揃えたい | [ADR-064](adr/064-dispatch-no-worktree-default-branch.md) |
| ✔ | ○ | tmux / fish / claude / codex | popup 経由の codex 起動で入力エリアの背景色が描画されない — codex は OSC 11 で背景色 query するが detached session には tmux が応答を返さないため、attached client が来るまで起動を遅延させる | [ADR-065](adr/065-dispatch-codex-wait-for-attached-client.md) |
| ✔ | ○ | claude / codex | dotfiles 管理 skill が Codex CLI から利用できない — Claude 用に作った dispatch/orchestrate/session-log を Codex セッションでも使いたい | [ADR-066](adr/066-codex-skill-symlink-distribution.md) |
| ✔ | ○ | claude / codex | dotfiles 外の skill（個人/プラグイン）を Codex CLI に伝播する手段がない — manifest 化できない skill を任意のタイミングで同期する skill が必要 | [ADR-067](adr/067-codex-sync-skill.md) |

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

### ADR-034: e2e テストの追加基準と運用ポリシー

**コンポーネント**: 複合 | **ADR**: [ADR-034](adr/034-e2e-test-addition-policy.md)

**受け入れ条件**:

- [ ] テスト追加基準（再発実績・チェーン依存・暗黙の契約・手動検証困難）が `docs/development.md` に記載されている
- [ ] テストを追加しないケース（一度きりの typo・外部ツールのバグ・UI の見た目）が `docs/development.md` に記載されている
- [ ] バグ修正時のテスト追加フロー（基準確認 → 修正と同一コミットでテスト追加）が `docs/development.md` に記載されている

---

### ADR-035: ADR 確定前検証（Spike）パターンの導入

**コンポーネント**: claude | **ADR**: [ADR-035](adr/035-adr-spike-validation-pattern.md)

**受け入れ条件**:

- [x] `adr-reference` skill に `Spike中` ステータスが定義されている
- [x] `Spike中` から `Draft`（設計確定）への遷移ルールが `adr-reference` skill に記載されている
- [x] `development.md` に Spike フロー（`create-adr` → Spike実装 → 検証 → Draft 復帰 → `adr-ship`）が記述されている
- [x] `adr-ship` skill に `Spike中` ステータスの ADR には適用しないガードが明記されている

---

### ADR-036: ADR-040 採用後に意味を失った PR URL 収集 hook を削除する

**コンポーネント**: claude | **ADR**: [ADR-036](adr/036-remove-obsolete-pr-url-hooks.md)

**受け入れ条件**:

- [x] `session-index-post-tool.sh` が削除される（`git rm`）
- [x] `configs/claude/settings.json` の PostToolUse/Bash マッチャーから `session-index-post-tool.sh` のエントリが削除される
- [x] `session-index-stop.sh` が削除される（`git rm`）
- [x] `configs/claude/settings.json` の Stop hook から `session-index-stop.sh` のエントリが削除される
- [x] 削除後、`claude-pane-state.sh idle` の Stop hook は引き続き動作する
- [x] 削除後、`session-index-backfill-batch.py` が `pr_urls` を正確に補完し続ける

---

### ADR-037: PreToolUse hook による .claude/ サブディレクトリへのファイル操作自動承認

**コンポーネント**: claude | **ADR**: [ADR-037](adr/037-pretooluse-hook-approve-claude-subdir-file-ops.md)

**受け入れ条件**:

- [x] `.claude/skills/` 以下のファイルへの Write/Edit が permission UI なしに実行される
- [x] `.claude/agents/` 以下のファイルへの Write/Edit が permission UI なしに実行される
- [x] `.claude/commands/` 以下のファイルへの Write/Edit が permission UI なしに実行される
- [x] `.claude/settings.json` への Write/Edit は通常の permission UI が表示される
- [x] `.claude/CLAUDE.md` への Write/Edit は通常の permission UI が表示される
- [x] 通常のプロジェクトファイル（`.claude/` を含まないパス）への Write/Edit は動作が変化しない
- [x] `approve-safe-file-ops.py` が `approve-safe-commands.py`（Bash 専用）とは別ファイルで管理されている

---

### ADR-038: PreToolUse hook による .claude/ サブディレクトリへの Read 操作自動承認

**コンポーネント**: claude | **ADR**: [ADR-038](adr/038-pretooluse-hook-approve-claude-subdir-read.md)

**受け入れ条件**:

- [x] `.claude/skills/` 以下のファイルへの Read が permission UI なしに実行される
- [x] `.claude/agents/` 以下のファイルへの Read が permission UI なしに実行される
- [x] `.claude/commands/` 以下のファイルへの Read が permission UI なしに実行される
- [x] `.claude/settings.json` への Read は通常の permission UI が表示される
- [x] `.claude/CLAUDE.md` への Read は通常の permission UI が表示される
- [x] 通常のプロジェクトファイル（`.claude/` を含まないパス）への Read は動作が変化しない
- [x] `approve-safe-file-ops.py` が `approve-safe-commands.py`（Bash 専用）とは別ファイルで管理されている

---

### ADR-039: setup validate でフックスクリプトの存在チェックを追加する

**コンポーネント**: claude | **ADR**: [ADR-039](adr/039-validate-hooks-script-existence.md)

**受け入れ条件**:

- [x] `setup.sh --dry-run` 実行時に `~/.claude/settings.json` の hooks が参照するスクリプトが存在しない場合 WARN が出力される
- [x] `~/.claude/scripts/` 以外を参照するコマンド（例: `coderabbit`）はチェック対象外になる
- [x] `type: prompt` のフックエントリはチェック対象外になる
- [x] スクリプトが存在する正常なフック設定の場合は WARN が出ない

---

### ADR-040: Spike ADR ライフサイクルの明文化

**コンポーネント**: claude | **ADR**: [ADR-040](adr/040-spike-adr-lifecycle.md)

**受け入れ条件**:

- [x] adr-reference の ステータステーブルに `Spike完了` が存在する
- [x] adr-reference の遷移ルールに `Spike中 → Spike完了` が存在し、`Spike中 → Draft` が存在しない
- [x] adr-ship が `Spike完了` ステータスの ADR を拒否するよう記述されている
- [x] create-adr が Spike 指定時に `Spike中` ステータスで ADR を作成するよう記述されている
- [x] development.md の Spikeフローが `Spike完了` で終了するよう更新されている

---

### ADR-041: settings.json の dotfiles 管理キーを setup.sh で自動同期する

**コンポーネント**: claude | **ADR**: [ADR-041](adr/041-settings-json-managed-keys-sync.md)

**受け入れ条件**:

- [x] `configs/claude/setup.sh` が非 dry-run 時に `hooks` と `statusLine` キーをソースからデストへ同期する
- [x] 同期後もデスト側のローカル固有キー（`env`, `language`, `effortLevel`, `attribution`）が保持される
- [x] `setup.sh --dry-run` 時に dotfiles 管理キーの差分が検出された場合 WARN が表示される
- [x] `scripts/lib/validate.sh` の hooks スクリプト存在チェックが `~/.claude/claudedog/` パスも対象にする
- [x] `configs/claude/settings.json` の hooks パスを変更後に `setup.sh` を実行すると `~/.claude/settings.json` の hooks が自動更新される

---

### ADR-042: Claude Code フック設計のスケーラビリティ改善

**コンポーネント**: claude | **ADR**: [ADR-042](adr/042-hook-scalability-architecture.md)

**受け入れ条件**:

- [ ] `approve-safe-file-ops.py` の Read/Write/Edit/NotebookEdit 重複 4 エントリが 1 エントリに統合される
- [ ] `approve-safe-file-ops.py` を全 PreToolUse に対して適用しても、Read/Write/Edit/NotebookEdit 以外のツールへの動作が変化しない
- [ ] settings.json のフック構造設計（案A/案B）が決定され ADR に記録される
- [ ] 決定した設計方針に基づいてフック追加手順が `docs/development.md` に記載される

---

### ADR-043: Docker サンドボックスのネットワーク egress 制御

**コンポーネント**: claude | **ADR**: [ADR-043](adr/043-docker-sandbox-network-egress-control.md)

**受け入れ条件**:

- [ ] ネットワーク egress 制御方式（iptables allowlist / proxy / --network=none）が ADR に決定・記録されている
- [ ] 選択した方式が `configs/claude/docker/` に実装されている

---

### ADR-044: tmw_pick のデフォルト動作反転

**コンポーネント**: tmux / fish | **ADR**: [ADR-044](adr/044-tmw-default-direct-session-instead-of-worktree.md)

**受け入れ条件**:

- [x] `tmw_pick` がデフォルトでメインリポジトリで直接 tmux セッションを開く
- [x] `tmw_worktree_repos.conf` に登録したリポジトリのみ worktree 作成フローになる
- [x] `tmw_direct_repos.conf` が廃止され `tmw_worktree_repos.conf` に改名されている

---

### ADR-045: Claude セッション常時俯瞰 UI

**コンポーネント**: tmux / ghostty | **ADR**: [ADR-045](adr/045-claude-session-always-on-display-ui.md)

**受け入れ条件**:

- [x] tmux のすべてのセッションで Claude ウィンドウ状態のサマリが常時表示される
- [x] サマリには各エントリが `session:window_idx 状態バッジ` の形式で表示される（ウィンドウ単位）
- [x] サマリには各 Claude ウィンドウ名と状態（running/permission/idle）が含まれる
- [x] running 状態のウィンドウには経過時間が表示される
- [x] `prefix+1〜9` でカーソルモード不要でインデックス対応ウィンドウに即時切り替わる（switch-client + select-window）
- [x] `Cmd+c` でカーソルモードが ON になり、ステータスバーのカーソル位置がハイライト表示される
- [x] カーソルモード中に `j` でカーソルが次のウィンドウへ移動し、ステータスバーの表示が更新される
- [x] カーソルモード中に `k` でカーソルが前のウィンドウへ移動し、ステータスバーの表示が更新される
- [x] カーソルモード中に `Enter` でカーソル位置のウィンドウに切り替わり、カーソルモードが OFF になる
- [x] カーソルモード中に `Esc` または `q` でカーソルモードが OFF になる
- [x] ウィンドウ数が増減してカーソルが範囲外になった場合も正常動作する（クランプ）
- [x] `configs/tmux/scripts/claude-sessions-status.sh` がウィンドウ単位で `/tmp/claude-pane-state/` を読んでサマリ文字列を出力する
- [x] `configs/tmux/scripts/claude-session-switch.sh` が switch-client と select-window を両方実行する
- [x] `configs/tmux/tmux.conf` の `status-format[0]` に上記スクリプトが組み込まれている
- [x] ウィンドウが存在しない場合に空文字またはデフォルトメッセージが表示され、エラーが出ない

---

### ADR-046: Claude セッション statusbar 表示の撤廃

**コンポーネント**: tmux / fish | **ADR**: [ADR-046](adr/046-statusbar-popup-role-separation.md)

**受け入れ条件**:

- [x] `configs/tmux/tmux.conf` の `status 2` が `status 1` に戻る
- [x] `configs/tmux/tmux.conf` の `status-format[0]`（Claude セッション行）が削除される
- [x] `configs/tmux/tmux.conf` の `prefix+1~9` Claude 専用バインドが削除される
- [x] `configs/tmux/tmux.conf` の `user-keys[13]`（Cmd+c）と `claude-nav` キーテーブルが削除される
- [x] `configs/tmux/scripts/claude-sessions-status.sh` が削除される（`git rm`）
- [x] `configs/tmux/scripts/claude-session-switch.sh` が削除される（`git rm`）
- [x] `prefix+s` の popup（Claude 状態バッジ付き）が引き続き動作する

---

### ADR-047: Ghostty AppleScript による Claude セッションサイドバー

**コンポーネント**: ghostty / tmux | **ADR**: [ADR-047](adr/047-ghostty-applescript-claude-sidebar.md)

**受け入れ条件**:

- [ ] `ghostty-tmux-init.sh` から `osascript` を呼び出すとGhosttyウィンドウが左右に分割される
- [ ] 左ペインで `claude-session-monitor.sh` が起動し、`/tmp/claude-pane-state/` の状態が表示される
- [ ] 右ペインで `tmux new-session -A -s main` が正常に起動する
- [ ] `tmux switch-client` で別セッションに切り替えても左ペインの表示が消えない
- [ ] Ghostty 再起動時（`window-save-state = always`）に左ペインが二重生成されない
- [ ] 分割後のフォーカスが右ペイン（tmux側）になっている

---

### ADR-048: 1M context モデルの auto-compaction 閾値を 50% に設定する

**コンポーネント**: claude | **ADR**: [ADR-048](adr/048-claude-autocompact-threshold-override.md)

**受け入れ条件**:

- [x] `configs/claude/settings.json` の `env` に `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: "50"` が設定されている
- [x] ADR-041 の managed keys sync により `~/.claude/settings.json` に `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` が伝播される

---

### ADR-049: prtrack を tmux popup から常駐 session に変更する

**コンポーネント**: tmux / ghostty | **ADR**: [ADR-049](adr/049-prtrack-permanent-session-instead-of-popup.md)

**受け入れ条件**:

- [x] Cmd+g で prtrack session が存在しなければ作成・prtrack 起動、存在すれば直接 switch-client される
- [x] ~~prtrack session 内で ESC を押すと直前の session に戻る（`switch-client -l`）~~（2026-04-17 撤回: prtrack ツールの ESC 操作と競合するため削除）
- [x] cmd+s の session 一覧に prtrack session が表示されない
- [x] prtrack 終了後も session が残り、再度 Cmd+g で prtrack が再起動される

---

### Skill 呼び出し回数計測

**コンポーネント**: claude

**受け入れ条件**:

- [ ] Skill ツールが呼び出されるたびに `~/.claude/skill-metrics/counts.jsonl` にログが追記される
- [ ] ログの各行は `{"skill": "<name>", "timestamp": "<ISO8601>"}` の JSONL 形式である
- [ ] `~/.claude/scripts/skill-stats.sh` を実行するとスキル別呼び出し回数が降順で表示される
- [ ] `configs/claude/settings.json` の PostToolUse フックに Skill マッチャーが追加されている
- [ ] フックスクリプト `~/.claude/scripts/skill-call-counter.sh` が実行可能ファイルとして配置されている

---

### ADR-060: orchestrate v4 — エージェントチェーンの復元

**コンポーネント**: claude | **ADR**: [ADR-060](adr/060-orchestrate-v4-agent-chain-restoration.md)

**受け入れ条件**:

- [x] `/orchestrate feature "タスク"` でワークフロータイプに応じたエージェントチェーン（planner → tdd-guide → code-reviewer → security-reviewer）が順次起動される
- [x] 各エージェントが完了時にハンドオフ文書（`.outputs/claude/handoffs/HANDOFF-<prev>-to-<next>.md`）を生成する
- [x] `tmux wait-for` により前エージェント完了後に次エージェントが自動起動される（ポーリング待機なし）
- [x] 各エージェントが専用の tmux ウィンドウで実行され、進捗が視覚的に確認できる
- [x] orchestrate.sh のマニフェストに `workflow`・`chain`（agents, current_phase, phases）が記録される
- [x] 最後のエージェントが `FINAL-REPORT.md` を生成して `creation_state` が `complete` に更新される
- [x] `/orchestrate cleanup <session>` で advance ループの PID kill を含む全リソースが削除される
- [x] `/orchestrate --dry-run feature "タスク"` でエージェントチェーンと計画が表示される（実行はしない）

---

### dispatch 起動中ステータス通知

**コンポーネント**: fish / tmux

**受け入れ条件**:

- [ ] dispatch 実行中、worktree 作成・tmux session 作成・claude 起動の各ステップで `tmux display-message` にステータスが表示される
- [ ] エラー発生時に `tmux display-message` でエラー内容が表示される（サイレント失敗しない）
- [ ] 完了時に `tmux display-message` で成功通知（session 名）が表示される

---

### dispatch repo 省略時にカレントリポジトリで worktree 実行

**コンポーネント**: claude

**受け入れ条件**:

- [ ] `/dispatch "prompt"` で repo を省略した場合、カレントディレクトリのリポジトリで worktree が作成される
- [ ] worktree 作成後、現在の tmux session 内に新しい window が追加されて claude が起動する
- [ ] `/dispatch repo "prompt"` の既存動作（別リポジトリ指定）は変更されない

---

### dispatch 後フォーカス自動遷移

**コンポーネント**: fish / tmux

**受け入れ条件**:

- [ ] `dispatch_launcher` 実行後、フォーカスが呼び出し元のウィンドウ/セッションに留まる
- [ ] dispatch で作成されたワーカーセッションには自動遷移しない

---

### ADR-056: dispatch/orchestrate popup ランチャー

**コンポーネント**: tmux / claude | **ADR**: [ADR-056](adr/056-dispatch-orchestrate-popup-launcher.md)

**受け入れ条件**:

- [x] `cmd+shift+s` で popup ランチャーが開き、ghq リポジトリ一覧 + dispatch/orchestrate 切替が表示される
- [x] popup ランチャーでリポジトリ選択 → prompt 入力 → Enter で dispatch or orchestrate が実行される
- [x] `tmw_pick.fish` が廃止され、`cmd+shift+s` が popup ランチャーに置き換わる

---

### ADR-061: popup ランチャーのトップレベルモードを claude / codex に再構成する

**コンポーネント**: tmux / fish / claude | **ADR**: [ADR-061](adr/061-popup-launcher-claude-codex-modes.md)

**受け入れ条件**:

- [x] `cmd+shift+s` の Step 1 で `tab` を押すとモードが `claude` ↔ `codex` で切り替わる
- [x] Step 1 ヘッダーにアクティブモードがハイライト表示される（`claude / codex` のいずれかが強調）
- [x] `claude` モード（デフォルト）で候補一覧が `ghq list` 由来のリポジトリ（worktree ディレクトリ除外）になる
- [x] `codex` モードで候補一覧が `ghq list` 由来のリポジトリ（worktree ディレクトリ除外）になる
- [x] `claude` モードで選択 → Enter すると、既存の Step 2（dispatch/orchestrate 切替・prompt 入力）に遷移する
- [x] `codex` モードで選択 → Enter すると、選択リポジトリ名のセッションが存在しなければ ghq パスを cwd として新規作成される
- [x] `codex` モードで選択 → Enter すると `codex` CLI が `send-keys` で投入され、`tmux switch-client` でそのセッションに切り替わる
- [x] `codex` モードでは worktree 作成・prompt 投入・モード切替（dispatch 相当）が行われない
- [x] 旧 `PRs` モード（PR worktree 一覧の表示と直接切替）が popup ランチャーから削除される
- [x] ADR-056 のステータスが `部分廃止（ADR-061 で一部変更）` に更新され、Step 1 が ADR-061 で上書きされた旨が注記されている

---

### ADR-062: popup ランチャーの codex モードを dispatch 化する（フェーズ2）

**コンポーネント**: tmux / fish / claude | **ADR**: [ADR-062](adr/062-popup-launcher-codex-dispatch-phase2.md)

**受け入れ条件**:

- [x] `dispatch.sh launch` に `--launcher claude|codex` フラグが実装され、未指定時の既定値が `claude` である
- [x] `dispatch.sh launch --launcher codex --branch feat/x --prompt-file <file> <repo>` で worktree 作成 + tmux session/window 作成 + `codex -C $work_dir "$(cat $prompt_file)"` の `send-keys` 投入が実行される
- [x] `dispatch.sh launch --launcher codex --no-prompt --branch feat/x <repo>` で worktree 作成 + `cd $work_dir; codex` のみが投入される（プロンプトなし）
- [x] `dispatch.sh launch --launcher codex --no-worktree <repo>` で worktree 作成をスキップし、リポジトリ root で codex が起動する
- [x] `~/.config/dispatch/no-worktree-repos` の設定が codex モードでも反映される（claude モードと同じ判定ロジック）
- [x] popup ランチャーで `codex` モードを選び repo を選択 → Enter すると Step 2（prompt 入力）UI が表示される
- [x] codex モードの Step 2 では `tab` キーが無効化され、`dispatch / orchestrate` 切替トグルが表示されない
- [x] codex モードの Step 2 で `:branch-name` プレフィックスを入力すると、既存 remote branch の checkout フロー（`--no-prompt` + worktree 作成）で codex が起動する
- [x] codex モードで session 命名が claude モードと同じ `<repo>@<wt-name>` 形式になる
- [x] `configs/fish/functions/dispatch_launcher.fish` から旧 codex モード分岐ブロック（直接 session 作成 + `codex` 起動の簡易フロー）が削除される
- [x] `configs/claude/skills/dispatch/skill.md` に `--launcher` 引数の説明が追記される
- [x] 既存 claude モードの dispatch 挙動（worktree 作成・prompt 投入・`:branch-name` プレフィックス・no-worktree 設定）に regression がない
- [x] ADR-061 のステータスが `部分廃止（ADR-062 で一部変更）` に更新され、codex モードのフェーズ1 仕様が ADR-062 で上書きされた旨が注記されている

---

### ADR-063: tmux セッションリストに Codex ランタイム状態を表示

**コンポーネント**: tmux / fish / claude / codex | **ADR**: [ADR-063](adr/063-tmux-codex-pane-state.md)

**受け入れ条件**:

- [ ] `configs/claude/scripts/agent-pane-state.sh` が新規作成され、第3引数で agent 種別（`claude` | `codex`）を受け取る
- [ ] `configs/claude/scripts/claude-pane-state.sh` が削除される（`git rm`）
- [ ] 状態ディレクトリが `/tmp/agent-pane-state/` に変更され、状態ファイルに agent 種別が記録される
- [ ] `configs/claude/settings.json` の hooks の command が `agent-pane-state.sh <state> claude [post]` に書き換えられる
- [ ] ADR-041 の managed-keys sync により `~/.claude/settings.json` の hooks command が自動更新される
- [ ] `configs/fish/functions/__tm_agent_state.fish` が新規作成され、agent 種別を含む形で状態を返す
- [ ] `configs/fish/functions/__tm_claude_state.fish` が削除される（`git rm`）
- [ ] `configs/fish/functions/__tm_candidates.fish` が `__tm_agent_state` を呼び出し、agent 種別ごとにバッジ色を分岐する（claude=purple、codex=cyan 等）
- [ ] `configs/codex/config.toml` が新規作成され、`hooks.UserPromptSubmit` / `PostToolUse` / `PermissionRequest` / `Stop` / `SessionStart` で `agent-pane-state.sh <state> codex` が登録される
- [ ] `configs/codex/setup.sh` が新規作成され、`~/.codex/config.toml` への配布が実装される（既存ユーザー設定のマージ方針が確定している）
- [ ] `scripts/setup-manifest.yml` に codex コンポーネントが追加される
- [ ] `scripts/lib/validate.sh` が `~/.codex/config.toml` の `[[hooks.*]]` のスクリプト存在チェックを行う
- [ ] tmux ペインで codex 起動中に `prefix+s` の fzf 一覧で `[running]` / `[idle]` バッジが表示される
- [ ] codex の権限要求発生時に `[perm]` バッジが表示される（`PermissionRequest` hook が発火することを実機で確認）
- [ ] Claude セッションでも従来通り `[running]` / `[idle]` / `[perm]` / `[ask]` バッジが表示され regression がない
- [ ] codex 終了後、ペインのフォアグラウンドが shell に戻ると状態ファイルが自動削除される（`__tm_agent_state.fish` の stale 検知ロジックでカバー）
- [ ] running 状態の経過時間表示（`[running(Nm)]`）が codex でも動作する
- [ ] ADR-007 のステータスが `部分廃止（ADR-063 で一部変更）` に更新され、スクリプト名・関数名・状態ディレクトリパスが ADR-063 で変更された旨が注記されている
- [ ] `docs/reference.md` の pane_state 関連の記述がリネーム後の名称（`agent-pane-state.sh` / `__tm_agent_state.fish` / `/tmp/agent-pane-state/`）に更新されている
- [ ] v0.125.0 で `[features] codex_hooks = true` の指定要否が実機で検証されている
- [ ] `ishii1648/tmux-sidebar` の `internal/state/state.go` の `DefaultStateDir` が `/tmp/agent-pane-state` に変更され、`PaneState` に `Agent` フィールド（`claude` / `codex`）が追加され、状態ファイル 2 行目を agent 種別としてパースする
- [ ] `ishii1648/tmux-sidebar` の `internal/ui/model.go` で agent 種別ごとにバッジ色／表記が分岐し、`__tm_candidates.fish` と同じ配色（claude=purple、codex=cyan 等）になる
- [ ] `ishii1648/tmux-sidebar` の改修版が新 version でタグ付けされ、dotfiles `aqua.yaml` が当該 version に bump されている
- [ ] 移行順序が守られている: tmux-sidebar リリース → `aqua.yaml` bump → dotfiles 本体改修 の順で merge され、状態ディレクトリ切替時に tmux-sidebar が「全 pane 状態不明」状態にならない（実機で確認）
- [ ] tmux-sidebar 上で codex 起動中のペインが含まれるウィンドウに `[running]` / `[idle]` / `[perm]` バッジが表示される（claude 起動中のウィンドウと並べて色／文字で識別できる）

---

### ADR-064: no-worktree-repos の popup 起動はメインworktree+デフォルトブランチに揃える

**コンポーネント**: tmux / fish / claude | **ADR**: [ADR-064](adr/064-dispatch-no-worktree-default-branch.md)

**受け入れ条件**:

- [x] `~/.config/dispatch/no-worktree-repos` に登録されたリポジトリを popup ランチャー経由で起動すると、`work_dir` がメインworktree（`git worktree list --porcelain | head -n1` の結果）になる
- [x] そのとき作業ツリーが clean なら、デフォルトブランチ（`origin/HEAD` 解決、フォールバック `main` → `master`）に checkout される
- [x] 作業ツリーに変更がある場合はブランチ切替をスキップし、現在のブランチで起動する(警告を `tmux display-message` に表示)
- [x] 既に HEAD がデフォルトブランチに乗っている場合は checkout を実行せず冪等に動作する
- [x] `dispatch.sh launch --no-worktree` を直接呼んだ場合でも、リポジトリが `no-worktree-repos` に含まれていれば同じロジックで起動する
- [x] `no-worktree-repos` に含まれないリポジトリで `--no-worktree` を直接渡した場合の挙動には regression がない（ブランチ切替が発生しない）
- [x] worktree モード（`no-worktree-repos` 対象外）の挙動には regression がない

---

### ADR-065: dispatch 経由の codex 起動を attached client が来るまで遅延させる

**コンポーネント**: tmux / fish / claude / codex | **ADR**: [ADR-065](adr/065-dispatch-codex-wait-for-attached-client.md)

**受け入れ条件**:

- [x] `dispatch.sh launch --launcher codex` で起動した codex が、target session に attached client が出現するまで `send-keys` を待機する
- [x] attached client 待機は `tmux list-clients -t "=$session_name"` の行数を 0.5 秒間隔でポーリングし、1 以上になった時点で待機を抜ける
- [x] 待機の上限は 300 秒で、タイムアウト後も `send-keys` は実行される（dispatch がサイレントハングしない）
- [x] `--launcher claude` の場合は待機ロジックが適用されず、従来通り `sleep 0.5` 後即 send-keys される（既存 claude フローへの regression なし）
- [x] popup ランチャー経由で codex を起動 → 新 session に switch すると、入力エリアに背景色 SGR (`[48;2;51;53;67m`) が描画された状態で表示される
- [x] `--no-prompt` オプション付きの codex 起動でも待機ロジックが同様に適用される

---

### ADR-066: dotfiles 管理 skill を Codex CLI へ symlink 配布する

**コンポーネント**: claude / codex | **ADR**: [ADR-066](adr/066-codex-skill-symlink-distribution.md)

**受け入れ条件**:

- [x] `scripts/setup-manifest.yml` の `components.codex` に `symlinks` セクションが追加され、`dispatch` / `orchestrate` / `session-log` の 3 エントリが定義されている
- [x] `bash scripts/setup.sh` 実行後に `~/.codex/skills/dispatch` が `configs/claude/skills/dispatch` への symlink として作成されている
- [x] `bash scripts/setup.sh` 実行後に `~/.codex/skills/orchestrate` が `configs/claude/skills/orchestrate` への symlink として作成されている
- [x] `bash scripts/setup.sh` 実行後に `~/.codex/skills/session-log` が `configs/claude/skills/session-log` への symlink として作成されている
- [x] `bash scripts/setup.sh --dry-run` で codex の symlink チェックが実行され、target 不在時に WARN が出力される
- [x] `configs/claude/skills/<name>/skill.md` が `SKILL.md`（大文字）にリネームされ、git index にも rename として記録されている（`core.ignorecase=true` 環境での二段階 `git mv` で実施）
- [x] codex CLI が `dispatch` / `orchestrate` / `session-log` を認識する（`codex debug prompt-input` の `<skills_instructions>` に 3 件全てが追加されることを確認）
- [x] `linux` profile では codex コンポーネント自体が対象外のままで、symlink エントリ追加による regression がない

---

### ADR-067: Claude Code skill を Codex CLI へ動的に同期する codex-sync skill を追加する

**コンポーネント**: claude / codex | **ADR**: [ADR-067](adr/067-codex-sync-skill.md)

**受け入れ条件**:

- [x] `configs/claude/skills/codex-sync/SKILL.md` が存在し、name / description / version / allowed-tools / argument-hint の frontmatter を持つ
- [x] `configs/claude/skills/codex-sync/codex-sync.sh` が実行可能ビット付きで存在する
- [x] `scripts/setup-manifest.yml` の `claude.symlinks` に `~/.claude/skills/codex-sync` のエントリが追加されている
- [x] `bash scripts/setup.sh` 実行後、`~/.claude/skills/codex-sync` が `configs/claude/skills/codex-sync` への symlink として作成される
- [x] `~/.claude/skills/codex-sync/codex-sync.sh --dry-run` で各 skill のステータス（CREATED / OK / SKIP / WARN / CONFLICT）と Summary 行が出力される
- [x] `~/.claude/skills/codex-sync/codex-sync.sh` の通常実行で `~/.codex/skills/<name>` への symlink が冪等に作成される（再実行で `OK` のみ）
- [x] broken symlink（`~/.claude/skills/spawn` 等）が SKIP として扱われ、エラーにならない
- [x] `SKILL.md`（大文字）が無い skill は WARN を出して続行する（自動リネームしない）
- [x] 既存 symlink が別の先を指す場合 / 通常ファイルが存在する場合は CONFLICT を出して exit 2 で終了する
- [x] codex CLI が `codex-sync` 自身を skill として認識する（`codex debug prompt-input` の `<skills_instructions>` に出現することを確認）

