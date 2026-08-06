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
| ✔ | ○ | claude | hook の複雑性が増すにつれ settings.json の肥大化・重複エントリ・変更理由の喪失が発生する — ディスパッチャ方式または責務統合で構造的に対処したい | [ADR-042](adr/042-hook-scalability-architecture.md) |
| - | ○ | claude | Docker サンドボックスのネットワーク egress が無制限 — deny ルール単体では根本的な対策にならず、ネットワーク層での制御が必要 | [ADR-043](adr/043-docker-sandbox-network-egress-control.md) |
| ✔ | ○ | tmux / fish | tmw_pick のデフォルトが worktree 強制で煩雑 — 大多数のリポジトリはメインで直接開くのが望ましいが、都度 conf に追記が必要 | [ADR-044](adr/044-tmw-default-direct-session-instead-of-worktree.md) |
| - | △ | tmux / ghostty | 複数 Claude セッションを常時俯瞰できない — prefix+s の都度 popup のみで、ブラウザのタブに相当する常時表示・即時切り替え UI がない | [ADR-045](adr/045-claude-session-always-on-display-ui.md) |
| ✔ | ○ | tmux / fish | ADR-045 で追加した Claude セッション statusbar 表示が過剰 — 常時表示の恩恵1点に対し表示・操作領域の増加コストが大きく、popup で充分 | [ADR-046](adr/046-statusbar-popup-role-separation.md) |
| - | △ | ghostty / tmux | Ghostty AppleScript で Claude セッション常時俯瞰サイドバーを実現できるか未検証 — tmux レイヤー内では switch-client で消えるが Ghostty レベルの分割なら不変なはず | [ADR-047](adr/047-ghostty-applescript-claude-sidebar.md) |
| ✔ | ○ | claude | 1M context モデルで auto-compaction 閾値が高すぎ推論品質が劣化する — デフォルト 80%+ では MRCR 17pt 低下、推論の捏造・修正無視が発生 | [ADR-048](adr/048-claude-autocompact-threshold-override.md) |
| ✔ | ○ | tmux / ghostty | prtrack popup の状態が毎回リセットされ操作モデルが非対称 — display-popup はスクロール履歴を失い、他 session と異なる操作感 | [ADR-049](adr/049-prtrack-permanent-session-instead-of-popup.md) |
| - | ○ | claude | Skill ツールの呼び出し回数が把握できない — どのスキルが頻繁に使われているか分からず、改善優先度の判断ができない | — |
| ✔ | ○ | tmux / claude | dispatch/orchestrate の起動に毎回ターミナルで手入力が必要 — popup ランチャーでリポジトリ選択・モード切替・prompt 入力を一箇所に集約する | [ADR-056](adr/056-dispatch-orchestrate-popup-launcher.md) |
| ✔ | ○ | fish / tmux | ~~dispatch 後にフォーカスが自動遷移する — `dispatch_launcher.fish` の `run-shell -b` 内 `switch-client` が popup 閉幕後にワーカーセッションへ強制移動する~~（ADR-069 で `tmux-sidebar new` に移管され、picker が意図的に `Switch off` で起動するため構造的に解消） | [ADR-069](adr/069-popup-launcher-tmux-sidebar-new-migration.md) |
| ✔ | ○ | claude | orchestrate がフェーズ分離を構造的に強制できない — v2.0/v3.0 の簡素化で dispatch と実質同じになり、エージェントチェーンとハンドオフ文書が失われている | [ADR-060](adr/060-orchestrate-v4-agent-chain-restoration.md) |
| ✔ | ○ | tmux / fish / claude | popup ランチャーのトップレベルが repos/PRs で利用頻度が偏る — claude/codex の二値モードに整理し、codex 起動を素早くできるようにする | [ADR-061](adr/061-popup-launcher-claude-codex-modes.md) |
| ✔ | ○ | tmux / fish / claude | popup ランチャーの codex モードが起動のみで dispatch 挙動を伴わない — claude モードと同等の worktree 作成 + 初期プロンプト投入を `--launcher` フラグで共通化する | [ADR-062](adr/062-popup-launcher-codex-dispatch-phase2.md) |
| - | ○ | tmux / fish / claude / codex | tmux セッションリストで codex 起動中ペインの状態が分からない — Claude 用の pane_state 機構を汎用化し codex hooks で同等に扱う | [ADR-063](adr/063-tmux-codex-pane-state.md) |
| ✔ | ○ | tmux / fish / claude | popup ランチャーで `no-worktree-repos` 対象を開くと直前のブランチで起動する — メインworktreeのデフォルトブランチに揃えたい | [ADR-064](adr/064-dispatch-no-worktree-default-branch.md) |
| ✔ | ○ | tmux / fish / claude / codex | popup 経由の codex 起動で入力エリアの背景色が描画されない — codex は OSC 11 で背景色 query するが detached session には tmux が応答を返さないため、attached client が来るまで起動を遅延させる | [ADR-065](adr/065-dispatch-codex-wait-for-attached-client.md) |
| ✔ | ○ | claude / codex | dotfiles 管理 skill が Codex CLI から利用できない — Claude 用に作った dispatch/orchestrate/session-log を Codex セッションでも使いたい | [ADR-066](adr/066-codex-skill-symlink-distribution.md) |
| ✔ | ○ | claude / codex | dotfiles 外の skill（個人/プラグイン）を Codex CLI に伝播する手段がない — manifest 化できない skill を任意のタイミングで同期する skill が必要 | [ADR-067](adr/067-codex-sync-skill.md) |
| ✔ | ○ | tmux | tmux プラグイン (TPM / `wfxr/tmux-fzf-url` 等) が `scripts/setup.sh` の対象外で再現できない — symlink は貼られるが TPM 未インストールのため `prefix + u` 等の plugin バインドが効かない | — |
| ✔ | ○ | claude | auto mode 運用への切替で hook と CLAUDE.md の permission 緩和規約が冗長/負債化した — `permission_mode` フィールドによる hook 内 skip と destructive 防御の `permissions.deny` 移行で対処 | [ADR-068](adr/068-permission-mode-aware-hooks.md) |
| - | ○ | tmux | `wfxr/tmux-fzf-url` が xre 書き直し時に `@fzf-url-extra-filter` を廃止し PR URL フィルタが無効化された — `prefix + u` で PR URL が popup 表示できない | — |
| - | ○ | tmux / fish / claude / codex | popup ランチャーが二系統並存（dispatch_launcher.fish と `tmux-sidebar new`）でメンテ負債が発生する — `prefix+S` を `tmux-sidebar new` に統一し dispatch_launcher を廃止する | [ADR-069](adr/069-popup-launcher-tmux-sidebar-new-migration.md) |
| - | ○ | claude / codex | coding agent 間の双方向・反復連携を自動化できない — dispatch は片方向のみで「claude 実装 → codex レビュー → claude 反映 → codex 再レビュー」の往復を人間が手動中継している | [ADR-070](adr/070-cross-agent-review-loop.md) |
| ✔ | ○ | claude / codex | dispatch / review-loop を dotfiles で vendor し続けると agmsg-go 同梱版（IPC 機構・team・auto-join）と二重メンテになる — 配布を agmsg-go（`agmsg skills install`）に外部化し dotfiles の vendor を廃止する | [ADR-072](adr/072-externalize-dispatch-review-loop-to-agmsg-go.md) |
| ✔ | ○ | claude | statusline のコンテキスト使用率表示が model.id の "[1m]" サフィックスに依存し新モデルで誤動作する — Claude Code 本体が stdin で渡す context_window フィールドを優先する必要がある | [ADR-073](adr/073-statusline-context-window-over-model-id-suffix.md) |
| ✔ | ○ | claude | statusline の org 名表示が `<email>'s Organization` で冗長かつ Fable 専用の週間利用率が確認できない — org 表示を廃止し、`oauth/usage` API の `limits[]` から Fable のスコープ制限を抽出して表示する | [ADR-074](adr/074-statusline-org-shorten-and-fable-usage.md) |
| ✔ | ○ | tmux / claude | `tmux-sidebar new` の popup 起動(`prefix+S`)は tmux popup 内で入力補完まわりが不便 — bind を `new-window` に変更する | [ADR-075](adr/075-picker-launch-popup-to-new-window.md) |
| ✔ | ○ | claude | main worktree が意図せず非 default branch のまま放置され `git switch <default>` が別 worktree との衝突で失敗する — main worktree での `git switch`/`checkout` を PreToolUse hook でブロックし EnterWorktree 経由の分離を強制する | [ADR-081](adr/081-block-main-worktree-branch-switch.md) |
| ✔ | ○ | claude | default worktree が非 default branch のまま放置される事故が別リポジトリでも再発し、linked worktree は自由に branch を切替できるため worktree:branch の 1:1 対応が保証されていなかった — hook を全 worktree に拡張し、CLAUDE.md の「main worktree に居座る」例外を stash ベースの手順に置き換える | [ADR-082](adr/082-pin-every-worktree-to-single-branch.md) |
| - | ○ | fish | worktree の削除が手動ルーティン（`gw_rm`）任せで放置され際限なく溜まる（ADR-081 で実測 224 個） — 作成から72時間超の worktree をマージ状態問わず launchd で無条件自動削除する | [ADR-083](adr/083-worktree-launchd-auto-cleanup.md) |
| - | ○ | git | `setup-github-ssh.sh` の SSH 接続テストが認証成功時も常に WARN になる — `set -o pipefail` 下で `ssh -T git@github.com` が終了コード 1 を返すため `grep -q` の一致がパイプ全体の非0で打ち消される | — |
| ✔ | ○ | 複合 | `setup.sh` の symlink 配置・パッケージ導入層が Nix の機能縮小版になっている — 静的 symlink とパッケージ導入は home-manager に譲り、`setup.sh` は mutable 設定と外部インストーラの層に縮退させる（aqua はバージョン固定用途で残す） | [ADR-084](adr/084-nix-home-manager-package-symlink-layer.md) |
| - | ○ | 複合 | Phase A で symlink が home-manager と `setup.sh` の二重定義になっている — full profile に限って `setup.sh` 側の定義を削除する。remote/linux は Nix 非対象なので profile 出し分けと端末固有 fish 関数の保全が必要 | [ADR-085](adr/085-nix-phase-b-manifest-migration.md) |
| - | ○ | herdr | `prefix+p` で herdr space（workspace）を新規作成しても claude session が自動起動されず毎回手動で `claude` を打っている — `workspace create` レスポンスの pane_id を使って `herdr agent start` を呼ぶ | [ADR-086](adr/086-herdr-new-workspace-auto-claude-launch.md) |
| - | ○ | herdr | linked worktree に居ると新しい tab / space まで linked worktree で開く — `new_cwd = "follow"` に「repo の default worktree」の選択肢が無いため、組み込み `new_tab` / `new_workspace` を cwd 解決付きの `[[keys.command]]` に差し替える | [ADR-087](adr/087-new-tab-workspace-at-default-worktree.md) |
| - | ○ | herdr | space / tab を開いたあと毎回手で `git pull origin <default branch>` を叩いている — 自動化チェーン（repo 選択 → space/tab → claude 起動）の最後に pull まで含める | [ADR-088](adr/088-auto-pull-default-branch-on-open.md) |
| ✔ | ○ | docs | ADR のリスト書式が textlint 指摘（強調 + コロン）を全体で踏んでいる — 30 本・128 箇所を太字 + em ダッシュに統一し、規約を `adr-reference` skill に明記する | — |

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

- [x] `approve-safe-file-ops.py` の Read/Write/Edit/NotebookEdit 重複 4 エントリが 1 エントリに統合される（案D）
- [x] `approve-safe-file-ops.py` を全 PreToolUse に対して適用しても、Read/Write/Edit/NotebookEdit 以外のツールへの動作が変化しない（案D）
- [x] hook 登録経路が dotfiles 一元化され、外部 CLI が settings.json を直接編集しない（案E、ADR-041 で同期基盤完成）
- [x] settings.json から呼び出される hook スクリプト（`configs/claude/scripts/` 配下）すべてに `# ADR:` と `# Purpose:` ヘッダが付与される
- [x] `scripts/lib/validate.sh` がヘッダ未記入の hook を WARN で検出する
- [x] `docs/development.md` に新規 hook 追加時のヘッダ規約が記載される
- [x] 構造改革（案A/案B）は将来課題として保留（トリガー条件は ADR-042 に記載）

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

- [x] ~~`dispatch_launcher` 実行後、フォーカスが呼び出し元のウィンドウ/セッションに留まる~~ — ADR-069 で `tmux-sidebar new` に移管された picker は dispatch.Options.Switch を意図的に未設定にしているため、popup 閉幕後も呼び出し元に留まる
- [x] ~~dispatch で作成されたワーカーセッションには自動遷移しない~~ — 同上

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

---

### tmux プラグイン (TPM) の setup.sh 対応

**コンポーネント**: tmux | **ADR**: —

**受け入れ条件**:

- [x] `scripts/setup-manifest.yml` の `components.tmux` に `setup: configs/tmux/setup.sh` が追加されている
- [x] `configs/tmux/setup.sh` が冪等に動作する（TPM 既存時はクローンをスキップ）
- [x] `bash scripts/setup.sh` 実行後に `~/.tmux/plugins/tpm/.git` が存在する
- [x] `bash scripts/setup.sh` 実行後に `wfxr/tmux-fzf-url` 等 tmux.conf 宣言済みプラグインが `~/.tmux/plugins/` 配下に展開されている
- [x] tmux サーバーをリロードした後、`tmux list-keys -T prefix` の出力に `bind-key -T prefix u` が含まれる（cmd+u → URL popup が動作する前提条件）
- [x] `bash scripts/setup.sh --dry-run` が TPM の存在チェックのみ行い、未インストール時に MISSING を報告する

---

### ADR-068: auto mode 下での hook 無効化と destructive 防御の permissions.deny 移行

**コンポーネント**: claude | **ADR**: [ADR-068](adr/068-permission-mode-aware-hooks.md)

**受け入れ条件**:

- [x] `configs/claude/scripts/redirect-to-tools.py` が `permission_mode` 系（`auto` / `bypassPermissions` / `dontAsk`）で hook 全体を skip する（`/tmp/` チェック含む全 rule）
- [x] default mode では `redirect-to-tools.py` の全 rule（`/tmp/` 誘導 / `$()` 禁止 / `&&` 禁止 / native tool redirect）が従来どおり機能する
- [x] `configs/claude/scripts/approve-safe-commands.py` が `permission_mode` 系で即 `exit 0` する
- [x] `configs/claude/scripts/approve-safe-file-ops.py` が `permission_mode` 系 + `acceptEdits` で即 `exit 0` する
- [x] `configs/claude/CLAUDE.md` から「自律性の原則」セクション全体が削除されている
- [x] `configs/claude/CLAUDE.md` から「禁止コマンド」セクションが削除されている
- [x] `configs/claude/settings.json` の `permissions.deny` に `Bash(rm -rf *)` / `Bash(rm -fr *)` / `Bash(rm -r -f *)` / `Bash(rm -f -r *)` が追加されている
- [x] `~/.claude/settings.json` の `permissions.deny` にも同 4 パターンが反映されている

---

### prefix+u を自前 popup に置き換え PR URL を扱う

**コンポーネント**: tmux | **ADR**: —

**受け入れ条件**:

- [x] `configs/tmux/fzf-pr-popup.sh` が新規作成され、capture-pane → `tmux-fzf-url-pr-filter` + 生 URL 抽出 → `fzf --tmux` popup → `open` の流れを実装している
- [x] `~/.local/bin/tmux-fzf-pr-popup` が `configs/tmux/fzf-pr-popup.sh` への symlink として作成される（`scripts/setup-manifest.yml` で管理）
- [x] `configs/tmux/tmux.conf` の TPM `run` 後に `bind u` が `tmux-fzf-pr-popup` を呼ぶ形で `wfxr/tmux-fzf-url` の bind を上書きしている
- [x] PR が作成済みの worktree pane で `prefix + u` を押すと PR URL が popup 候補に出る
- [x] popup から URL を選択すると `open` (macOS) または `xdg-open` (Linux) で開かれる
- [x] `tmux-fzf-url-pr-filter` の `#NNN` 抽出ロジックを削除し、キャッシュ + `gh pr view` の結果のみを返す（誤検出防止）
- [x] tmux global PATH に `/sbin` を追加し、display-popup 経由で `md5` (macOS の `/sbin/md5`) が見える
- [x] 画面上に http(s):// の生 URL が映っているとき、PR URL の候補に加えて生 URL も popup 候補に出る（OSC 8 ハイパーリンクの URL も抽出される）
- [x] `tmux-fzf-url-pr-filter` の出力に含まれる URL と画面上の同一 URL が重複候補として並ばない（awk で URL ベース重複排除）

---

### tmux-sidebar setup.md コンプライアンス再整合

**コンポーネント**: tmux / claude / codex | **ADR**: —（[ishii1648/tmux-sidebar docs/setup.md](https://github.com/ishii1648/tmux-sidebar/blob/main/docs/setup.md) に追従）

**受け入れ条件**:

- [ ] §4: `configs/tmux/tmux.conf` の `client-resized` hook が `tmux-sidebar relayout` を呼ぶ形になっており、3 ペイン以上の window でも右端ペインの累積ドリフトが発生しない
- [ ] §8: `configs/codex/hooks.json` の `SessionStart` / `PostToolUse` / `Stop` で `agent-pane-state.sh <state> codex [post]` が呼ばれ、`/tmp/agent-pane-state/pane_N` の 2 行目に `codex` が記録される
- [ ] §8: `configs/claude/scripts/agent-pane-state.sh` が `running` 遷移時に `pane_N_path` を未存在の場合のみ pwd で記録し、サイドバーの Git/PR 表示の起点パスを提供する
- [ ] §9: `configs/tmux-sidebar/pinned_sessions.example` が新規作成され、`scripts/setup-manifest.yml` の tmux 配下 copies に `if_missing: true` で `~/.config/tmux-sidebar/pinned_sessions` への配布が登録されている
- [x] §10: `configs/tmux/tmux.conf` に popup picker (`tmux-sidebar new`) を起動する bind-key が登録されている（ADR-069 採用後は `bind S` に集約。Cmd+Shift+S → ghostty `super+shift+s` → tmux `prefix+S` の経路）
- [ ] `configs/tmux-sidebar/setup.sh` が `~/go/bin/tmux-sidebar` 等で `~/.local/bin/tmux-sidebar` が PATH 上で shadow されているケースを検出し warning を表示する
- [ ] `bash scripts/setup.sh --dry-run` が All OK で完了し、`tmux-sidebar doctor` の全項目が `[OK]` になる

---

### ADR-069: popup launcher を `tmux-sidebar new` に移行し dispatch_launcher.fish を廃止する

**コンポーネント**: tmux / fish / claude / codex | **ADR**: [ADR-069](adr/069-popup-launcher-tmux-sidebar-new-migration.md)

**受け入れ条件（Spike フェーズ）**:

- [x] spike/069 ブランチで `tmux-sidebar new` の claude モードが ghq repo を選択 → worktree 作成 → Claude Code 起動 → 初期 prompt 投入の一連の流れで動作することを上流ソース静的検証（`internal/dispatch/dispatch.go` `BranchFromPrompt` / `CreateWorktree` / prompt file 書き込み）で確認している
- [x] 同 codex モードで worktree 作成 → codex 起動 → 初期 prompt 投入が動作し、ADR-065 相当の attached client 待機ロジックが効いている（detached session で codex の入力エリア背景色が崩れない）ことを `dispatch.go:259 waitForAttachedClient(5min)` で確認している
- [x] `~/.config/dispatch/no-worktree-repos` に登録した repo を選択した場合、メイン worktree のデフォルトブランチで起動することを `MatchesNoWorktreeConfig` + `CheckoutDefaultBranch` で確認している（ADR-064 相当）
- [x] dispatch_launcher の `:<branch>` 記法相当の既存 remote branch checkout 機能が `tmux-sidebar new` にあるか／無いかが ADR-069 に追記されている — `branch.go ParseBranchPrefix` で実装ありと確認
- [x] orchestrate モード（ADR-060 のエージェントチェーン）の起動経路の有無が ADR-069 に追記されている — picker は claude/codex 二値のみで未対応、`/orchestrate` skill 経由で代替する旨を記録
- [x] dispatch 完了後にフォーカスが呼び出し元に留まるか（issues.md L54/L685 と同質の regression が無いか）が確認されている — picker.go の `Switch is left off` コメントで構造的に解消されることを確認
- [x] Spike の知見（OK/NG 内訳と未対応機能のリスト）が ADR-069 の `## 設計案 > Spike 検証項目` の下に追記されている

**受け入れ条件（採用フェーズ — Spike OK 確定後）**:

- [x] `configs/tmux/tmux.conf` から `bind S display-popup -E "fish -c dispatch_launcher"` が削除される
- [x] `configs/tmux/tmux.conf` に `bind S display-popup -E -w 80 -h 24 'tmux-sidebar new'` が追加される
- [x] `configs/fish/functions/dispatch_launcher.fish` が `git rm` される
- [x] `configs/fish/functions/__dl_*` 系 helper（`__dl_repo_candidates.fish` / `__dl_fzf_toggle.fish`）が `git rm` される
- [x] `tmux source-file ~/.tmux.conf` 後に `tmux list-keys | grep "bind-key.*S"` で prefix+S が `tmux-sidebar new` を起動することを実機確認している
- [x] Cmd+Shift+S（ghostty `super+shift+s` 経由）で `tmux-sidebar new` の popup が表示される（ghostty の keybind 配線変更不要、tmux 側 bind 差し替えのみで反映）
- [x] ADR-056 のステータスが `廃止（ADR-069 で置換）` に更新され、起動 UI が `tmux-sidebar new` に移管された旨が注記されている
- [x] ADR-061 のステータスが `廃止（ADR-069 で置換）` に更新されている
- [x] ADR-062 のステータスが `廃止（ADR-069 で置換）` に更新されている
- [x] ADR-064 のステータスが `廃止（ADR-069 で置換）` に更新されている（Spike で完全互換と確認）
- [x] ADR-065 のステータスが `廃止（ADR-069 で置換）` に更新されている（Spike で完全互換と確認）
- [x] `docs/reference.md` の popup 起動経路の記述が `tmux-sidebar new` ベースに書き換えられている
- [x] `docs/issues.md` の dispatch_launcher 関連エントリ（L54/L685）が打消し or 「ADR-069 で解消」と注記されている
- [x] `bash scripts/setup.sh --dry-run` が regression 無しで完了する

---

### ADR-070: headless コーディネータによる claude↔codex 反復レビューループ

**コンポーネント**: claude / codex | **ADR**: [ADR-070](adr/070-cross-agent-review-loop.md)

**受け入れ条件**:

- [x] `configs/claude/skills/review-loop/SKILL.md` が新規作成され、`/review-loop "<タスク or レビュー観点>"` で起動できる（skill 登録を確認）
- [x] `configs/claude/skills/review-loop/review-loop.sh` に `launch` / `cleanup` / `selftest` サブコマンドが実装されている
- [x] `review-loop.sh launch` が現在の git worktree（レビュー対象ブランチ）上で動作し、新規 worktree を作成しない（`work_dir=repo_root` 固定）
- [x] 実装役・レビュー役を固定せず、`--implementer claude|codex` / `--reviewer claude|codex` で入替できる（既定は実装役=claude / レビュー役=codex）。不正値はバリデーションで弾く。エージェント別の起動コマンドは `rl_build_agent_cmd` に集約し selftest で検証する
- [x] claude（どのロールでも）が round1 は `claude --session-id <uuid>`、round2 以降は `claude --resume <uuid>` で interactive 起動され（`tmux wait-for -S <signal>` を付与）、`claude -p` / `--print` を一切使用しない（subscription 課金を維持）。claude がレビュー役のときは verdict を指定ファイルに書き出させる
- [x] claude が完了しても終了せず REPL に留まる問題に対し、完了マーカーファイル（実装役 `round-N-impl.done`／レビュー役 `round-N-review.md` の `REVIEW_RESULT` 行）で完了検知し、claude へは Ctrl-D を送って終了させ、次ラウンドは `claude --resume` で再起動する（claude→codex の 2 ラウンドライブ実行で Ctrl-D 終了→`--resume` 再起動→`round-2-impl.done` 生成を確認）
- [x] 2 ラウンド目以降の claude 起動で `--resume <session-id>` によりラウンド間の文脈が保持される（ライブ実行で round2 の `--resume` 再起動が動作）
- [x] レビュー役プロンプトに判定パターン `REVIEW_RESULT: <verdict>` をリテラルで含めない（codex は exec 時にプロンプトを stdout へエコーするため、含めると完了検知・収束判定がプロンプトのエコーを誤検知する）。selftest に回帰ガードを追加し、claude→codex のライブ実行で正しく round1 APPROVED→converged することを確認
- [x] codex（レビュー役）が `codex exec -s read-only -` headless で作業ツリー差分をレビューして `round-N-review.md` に捕捉され、codex（実装役）が `-s workspace-write` で worktree を編集する（implementer=codex/reviewer=codex のライブ実行で is_prime 実装→レビュー→APPROVED を確認）
- [x] コーディネータがバックグラウンドの advance ループで各ロールの完了マーカーを待ち、完了後に次ロールを自動起動する（ライブ実行で implementer→reviewer→（次round）implementer の自動連鎖を確認。当初の `tmux wait-for` は claude が終了しないため使えず、マーカーファイル方式へ変更）
- [x] レビュー結果が承認（`REVIEW_RESULT: APPROVED`）のときループが収束終了する（収束判定 `rl_review_converged` を selftest で検証 + ライブで round1 APPROVED→converged を確認）
- [x] 最大ラウンド数（既定 3、`--max-rounds N` で変更可）到達時に未収束でも終了し、その旨を報告する（`--max-rounds 2` のライブ実行で round2 まで回って exhausted→SUMMARY 生成を確認）
- [x] 各ラウンドのレビュー結果（`round-N-review.md`）がファイルとして残り、最終サマリ（収束/打ち切り・ラウンド数・ロール割当）が `SUMMARY.md` に出力される（ライブ実行で SUMMARY.md 生成を確認）
- [x] `review-loop.sh cleanup <session-id>` で advance ループ停止・tmux セッション削除・manifest 削除ができる（ERROR 分岐 + ライブ実行後の happy path 両方を確認）
- [x] claude を未信頼ディレクトリで interactive 起動すると信頼ダイアログでループが停止する。既定は信頼済み worktree 前提とし、`--trust-workdir` 明示時のみ `~/.claude.json` に信頼登録するオプトインとする（global 設定の無断書き換えはしない）
- [x] `review-loop.sh` 先頭に `# ADR: 070` / `# Purpose:` ヘッダが記入されている（ADR-042 規約）
- [x] `~/.claude/skills/review-loop` への配布が setup.sh（`configs/claude/skills/*/` 自動 symlink）経由で行われ、codex 側は `setup-manifest.yml` の symlink 登録で `/review-loop` が claude / codex 双方から呼べる
- [x] `docs/reference.md` の連携モード表に review-loop が追記される
- [x] review-loop.sh の終了判定・プロンプト生成の純粋ロジックを検証する `selftest` サブコマンドが実装され、`review-loop.sh selftest` が PASS する（リポジトリに bash 用テストフレームワークがないため、依存ゼロの自己テストとして同梱する）


---

### ADR-071: 元セッション主導の反復レビューループ（review-loop 再設計）

**コンポーネント**: claude / codex | **ADR**: [ADR-071](adr/071-session-driven-review-loop.md)

**受け入れ条件**:

- [x] ADR-070 のステータスが `廃止（ADR-071 で置換）` に更新され、置換の要約注記が付いている
- [x] `review-loop.sh` から `advance_loop`・実装役プロンプト生成（`rl_build_implementer_prompt`）・実装役の claude/codex 起動分岐・専用 tmux session 作成（`tmux new-session -s review-loop-<id>`）が削除されている
- [x] `review-loop.sh` のサブコマンドが `review-once` / `wait-review` / `cleanup` / `selftest` に再構成されている（`launch` は廃止）
- [x] `review-once` が現在の tmux session に reviewer 用 window/pane を `new-window` で追加して起動し、専用 session を新規作成しない（現 session 名を `tmux display-message -p '#{session_name}'` で取得して `new-window` する）
- [x] レビュアーは実装役（元セッション）の逆エージェントに自動決定される（元セッションが claude → codex レビュー、codex → claude レビュー）。SKILL.md の手順を実行するエージェント自身が「自分の逆」を選んで `review-once` を呼ぶ。`review-once` は reviewer 種別を内部フラグで受け取り、codex は `codex exec -s read-only -`（stdout を `round-N-review.md` にリダイレクト捕捉）、claude は verdict を指定ファイルに書き出させる形で起動する。実装役プロセスは一切起動しない
- [x] review-loop はユーザー向けの起動引数を持たない（ADR-070 の位置引数（タスク/観点）・`--implementer`・`--reviewer`・`--max-rounds`・`--base` をすべて廃止）。レビュー観点・base・ラウンド数の調整は skill 起動時の自然言語指示として元セッションが受け取り、内部で `review-once`/`wait-review` のフラグに変換する。SKILL.md から `argument-hint` を削除する
- [x] round1 がレビューから開始する（実装は完了済み前提。起動直後に実装役の実装フェーズを挟まない）
- [x] `wait-review` がレビュー結果ファイルに `REVIEW_RESULT:` 行（`APPROVED|CHANGES_REQUESTED`）が現れるまで待機し、検知したら終了する（タイムアウト時は非ゼロ終了で報告）。元セッションは `wait-review` を background 実行し、完了通知で再開する運用を SKILL.md に明記する
- [x] ループ制御・収束判定・修正は元 coding session（skill 起動者）が SKILL.md の手順として実行する。`REVIEW_RESULT: APPROVED` で収束終了、`CHANGES_REQUESTED` なら元セッションが自分で差分を修正して次ラウンドの `review-once` を起動する。最大ラウンド（既定 3）到達で打ち切る
- [x] レビュアープロンプトに判定パターン `REVIEW_RESULT: <verdict>` をリテラルで含めない（codex の stdout エコー誤検知対策）。selftest に回帰ガードを残す（ADR-070 から継承）
- [x] reviewer pane の send-keys が tmux-sidebar 等の自動追加 pane で誤爆しないよう、起動時に pane_id を固定する（ADR-070 から継承）
- [x] 現在の worktree（レビュー対象ブランチ）上で動作し、新規 worktree を作成しない（ADR-070 から継承）
- [x] レビュアーが claude のとき `claude -p` / `--print` を使用しない（subscription 課金を維持。ADR-070 から継承）
- [x] 各ラウンドのレビュー結果（`round-N-review.md`）がファイルとして残り、最終サマリ（収束/打ち切り・ラウンド数）が `SUMMARY.md` に出力される
- [x] `cleanup <session-id>` で reviewer window 削除・manifest 削除ができる
- [x] `review-loop.sh` 先頭の `# ADR:` ヘッダが `071`（または `070, 071`）に更新されている（ADR-042 規約）
- [x] `review-loop.sh selftest` が PASS する（再編後の純粋ロジック: レビュアープロンプト生成・収束判定・base_ref 解決・reviewer コマンド生成を検証）
- [x] `docs/reference.md` の連携モード表の review-loop 記述が元セッション主導モデルに更新されている
- [x] SKILL.md の `description` / 本文が元セッション主導フロー（実装完了後にレビュー → 自己修正 → 再レビューを収束まで）に書き換えられている
- [x] レビュアーが claude になるのは元セッションが codex のときのみ。read-only sandbox 強制がないためプロンプト指示依存になる非対称を ADR-071 に明記する（codex レビュアーは `-s read-only` で機構保証）

### ADR-072: dispatch / review-loop の配布を agmsg-go へ外部化する

**コンポーネント**: claude / codex | **ADR**: [ADR-072](adr/072-externalize-dispatch-review-loop-to-agmsg-go.md)

**受け入れ条件**:

- [ ] `agmsg` binary が `go install github.com/ishii1648/agmsg-go/cmd/agmsg@v0.0.1` で導入され、`~/go/bin/agmsg`（PATH 上）で `agmsg version` が動く（version pin、`@latest` を使わない）
- [ ] `~/.claude/skills/dispatch` / `~/.claude/skills/review-loop` が dotfiles を指す symlink ではなく、`agmsg skills install` が展開した**実ファイル**になっている
- [ ] `bash ~/.claude/skills/review-loop/review-loop.sh selftest` が PASS する（agmsg-go 同梱版 v2.0.0）
- [ ] `agmsg join` / `agmsg send` / `agmsg inbox` の IPC 疎通が確認できる（共有 SQLite DB 既定 `~/.agents/skills/agmsg`）
- [ ] `configs/claude/skills/dispatch` / `configs/claude/skills/review-loop` が dotfiles から削除されている（vendor 廃止）。`orchestrate` / `session-log` は残す
- [ ] `configs/dispatch/no-worktree-repos.example` は据え置く（runtime config `~/.config/dispatch/no-worktree-repos` の雛形で skill ソース非依存）
- [ ] `configs/claude/setup.sh` が agmsg を bootstrap する: `agmsg` 未導入なら `go install ...@v0.0.1`、続けて `agmsg skills install --force` を実行する
- [ ] `configs/claude/setup.sh` が `~/.claude/skills/{dispatch,review-loop}` の stale な dotfiles symlink を install 前に除去する（残すと install が skip して dotfiles へ書き込む事故になるため）
- [ ] `configs/claude/setup.sh` を 2 回連続実行しても冪等（2 回目で再 install/再 symlink-除去が壊れない。`--dry-run` も動く）
- [ ] `setup.sh` の skill symlink ループが残存 skill（orchestrate 等）の symlink 生成を従来どおり行う（vendor 削除後も回帰しない）
- [ ] `docs/reference.md` の記述が skills の出所を agmsg-go（`agmsg skills install`）に更新し、review-loop のシグナリング機構が agmsg IPC である旨を注記している
- [ ] review-loop は `agmsg` 必須（無いと `die`）、dispatch は `agmsg` soft 依存（無ければ従来動作）という依存差を ADR-072 に明記する

### ADR-073: statusline のコンテキスト上限判定を model.id サフィックスから context_window フィールドへ変更する

**コンポーネント**: claude | **ADR**: [ADR-073](adr/073-statusline-context-window-over-model-id-suffix.md)

**受け入れ条件**:

- [x] `configs/claude/statusline.js` が stdin の `context_window.context_window_size` をコンテキスト上限として使用する
- [x] `configs/claude/statusline.js` が stdin の `context_window.used_percentage` を使用率として使用する（`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` 未設定時）
- [x] stdin に `context_window` が存在しない場合、`model.id` の `"[1m]"` サフィックス判定 + transcript 解析にフォールバックする
- [x] `"[1m]"` サフィックスを持たない 1M モデル（例: Sonnet 5）で ctx 表示が 1M 基準になる

### ADR-074: statusline の org 表示廃止と Fable 週間利用率の追加

**コンポーネント**: claude | **ADR**: [ADR-074](adr/074-statusline-org-shorten-and-fable-usage.md)

**受け入れ条件**:

- [x] statusline 1行目から org 表示（`[ishii1492]` 等）が完全に消え、`[tier][model|effort] ...` の形式になる
- [x] `getRateLimitUsage()` が `oauth/usage` API の `limits[]` から `scope.model.display_name === "Fable"` の週間スコープ制限（`percent` / `resets_at`）を抽出して返す
- [x] stdin に `rate_limits`（five_hour/seven_day）が来ている場合でも Fable の週間利用率を取得するため `getRateLimitUsage()` を常時呼び出す（5h/7d/月間表示自体は従来通り stdin を優先）
- [x] statusline 1行目に `| fable ████░░░░ 33% <reset>` の形式で Fable の週間利用率が表示される
- [x] Fable の利用率データが取得できない場合（API 失敗・フィールド不在）は `fable` セグメントを表示しない

### ADR-075: `tmux-sidebar new` の起動を popup から new-window に変更する

**コンポーネント**: tmux / claude | **ADR**: [ADR-075](adr/075-picker-launch-popup-to-new-window.md)

**受け入れ条件**:

- [x] `configs/tmux/tmux.conf` の `prefix+S`（Cmd+Shift+S）が `display-popup -E` ではなく `new-window` で `tmux-sidebar new` を起動する
- [x] Cmd+Shift+S の既存 keybind（ghostty 側）は変更不要のまま動作する
- [x] `tmux-sidebar` 側（upstream）の spec.md / design.md / setup.md / history.md が popup 前提から new-window 前提の記述に更新されている（[issues/0022](https://github.com/ishii1648/tmux-sidebar/blob/main/issues/0022-feat-drop-popup-launch.md) 側で対応）

### ADR-076: ghostty + tmux + tmux-sidebar から ghostty + herdr へ移行する

**コンポーネント**: herdr / tmux / tmux-sidebar / claude / codex | **ADR**: [ADR-076](adr/076-herdr-migration-from-tmux.md)

Phase 0（Spike）は完了。移行続行と機能後退（OSC 8 由来 URL / pinned・hidden セッション /
graveyard）の許容を決定した（ADR-076「Spike の結論」参照）。
**未チェックの項目は Phase 1（並走運用）で使いながら判断する持ち越し**であり、Phase 0 のブロッカーではない。
Phase 2 以降の受け入れ条件は、herdr の運用感を得てから追記する。

**受け入れ条件**:

- [x] herdr 0.7.5 が導入されている（`herdr --version`）
- [x] `configs/herdr/config.toml` が `~/.config/herdr/config.toml` に symlink され、`herdr config check` が `config: ok` を返す
- [x] `scripts/setup-manifest.yml` に `herdr` コンポーネント（symlink + setup）が定義され、profile `full` に含まれる
- [x] profile 内の順序が `claude` / `codex` → `herdr` になっている（herdr integration が両者の設定ファイルを書き換えるため）
- [x] `configs/herdr/setup.sh` 経由で `herdr integration install claude` / `codex` が完了し、`herdr integration status` で両者が `current` になる
- [x] `configs/herdr/setup.sh` が冪等（2 回連続実行しても `configs/codex/hooks.json` に追加の差分が出ない。`--dry-run` も `current` を正しく OK 判定する）
- [x] Spike: **日本語 IME の入力** — `open -na Ghostty --args --command=/opt/homebrew/bin/herdr` で起動した herdr 内の Claude Code で、変換候補窓がカーソルに追従し、確定文字列の欠落・重複が起きない（実機確認で良好）
- [x] Spike: **IME 有効時の prefix** — CJK IME が有効な状態でも `ctrl+space` の prefix が herdr に届く（実機確認で良好）
- [x] Spike: **描画品質** — BIZ UDGothic Bold + `adjust-cell-height = 20%` で日本語が崩れず、Claude Code / Codex の TUI が正しくレンダリングされる（実機確認で良好）
- [ ] Spike: **分割方向** — `split_vertical` / `split_horizontal` の実際の分割方向を確認し、tmux（`prefix+n` = 左右、`prefix+v` = 上下）と同じ体験になるよう config のキー割当を確定する（API の `--direction right` = 左右は確認済み。config キー名との対応が未確定）
- [x] Spike: **エージェント状態検出（idle）** — `herdr agent list` が Claude Code を検出し、`agent_status: idle` と会話セッション UUID（`source: herdr:claude`）を報告する
- [ ] Spike: **エージェント状態検出（working / blocked）** — permission プロンプトが `blocked` として現れ、応答待ちが実態と一致する
- [x] Spike: **通知** — `herdr notification show` が `shown: true` を返し、`[ui.toast] delivery = "system"` で macOS 通知が発火する
- [x] Spike: **scrollback 取得** — `pane read --source recent` / `recent-unwrapped` が viewport を超えた scrollback 全体を返し（実測 214 行）、生 URL を完全に抽出できる
- [x] Spike: **OSC 8 ハイパーリンク（結果: NG）** — `--format ansi` でも `\e]8;;<URL>` は落ち、表示テキストしか残らない。API にも link 抽出メソッドが無い。Phase 2 で案 A（生 URL + PR フィルタのみ）か案 B（`mouse_capture = false` で ghostty に委譲）を選ぶ
- [ ] Spike: **クリップボード** — `copy_on_select` とコピー操作で ghostty のクリップボードに入る。`herdr --remote` 経由でも osc52 相当が機能する
- [x] Spike: **worktree（list）** — `herdr worktree list` が repo_root / branch / `open_workspace_id` を返し、workspace と worktree の紐付けを把握できる
- [ ] Spike: **worktree（create/remove）** — `herdr worktree create/open/remove` が `tmw` の代替になる（配置規約、`remove --force` 時の未コミット変更の扱い）
- [x] Spike: 検証結果を ADR-076 に追記し、ステータスを Draft（Phase 0 完了・Phase 1 並走運用中）に遷移させる
- [x] Phase 1: fish 関数 `hd` で herdr セッションを起動/アタッチできる（tmux を経由しない ghostty ウィンドウで開く）
- [x] Phase 2 は実施しない方針に変更。dispatch（agmsg-go 配布）・orchestrate（dotfiles vendor）は herdr CLI へ移植せず削除する。URL/PR popup の herdr 移植（案 A/案 B の選択）は保留とし、Phase 3/4 完了後に別途検討する
- [x] dispatch/orchestrate 廃止: `configs/claude/skills/orchestrate/`・`configs/claude/skills/session-log/`（発火源を失うため同時削除）・`configs/claude/scripts/{dispatch-new-worker-window,workflow-window-register,workflow-session-start,workflow-session-log,workflow-skill-detect,tmux-send-prompt}.sh`・`configs/dispatch/`・`configs/claude/workflow-sessions.json` を削除。`configs/claude/setup.sh` の agmsg bootstrap（dispatch/review-loop 一括配布、分離不可のため review-loop も配布停止）を削除。実機 `~/.claude/skills`・`~/.codex/skills`・`~/.workflow-sessions/` をクリーンアップ済み
- [x] Phase 3: `configs/ghostty/config` の `command` を herdr に切替（`ghostty-tmux-init.sh` 削除）。keybind は `\x00` 経由の間接送信のまま維持した（tmux が居なくなり herdr が直接 prefix を受けるため、直接バインドへの置換は不要と判断）
- [x] Phase 4: tmux 一式（`configs/tmux/`, `configs/tmux-sidebar/`, `prtrack-popup.sh`, `tm`/`tms`/`tmw`/`ssh` 等の fish 関数, `claude-pane-state.sh`/`agent-pane-state.sh`/`claude-notify.sh` と hook エントリ, manifest の tmux/tmux-sidebar コンポーネント, brew tmux, 関連テスト, `docs/tmux/`）を撤去した
- [x] URL/PR popup（`prefix+u`）の herdr 移植 — fzf 選択 UI を使う案 A/B ではなく、`statusline.js` が書き出す表示中 PR のキャッシュを直接開く方式（`herdr-open-pr`, `type = "shell"`）を採用した
- [x] `prefix+u`（`herdr-open-pr`）は `herdr pane current --current` の `foreground_cwd` が実際の作業ディレクトリと食い違う場合でも正しい PR を開く。実測で foreground_cwd は「pane 内の何らかの foreground 子プロセスの cwd」を返すに過ぎず、(a) worktree 使用時に base repo の cwd を返す（`aft-account-customizations` の worktree ペインで base repo のパスが返り、実際のブランチ `feat/move-session-infra-feature-flag-iam-policies-to-aws-infra`／PR #813 と食い違う）、(b) Claude Code が spawn した MCP サーバーの一時 workdir（`aws-api-mcp` の tmp dir）を拾う、の 2 パターンを確認した。`statusline.js` が cwd 非依存の `session_id`（herdr の `agent_session.value` と一致することを実測確認済み）をキーに `/tmp/gh-pr-session-<id>` を書き出し、`open-pr.sh` は cwd ベースの照合より session_id ベースの照合を優先する（`statusline.js` を実際の worktree cwd + 実在の session_id で単体実行し、`gh pr view` が解決した PR #813 が session キャッシュに書き出され、誤った base repo cwd を使ってもそのキャッシュ経由で正しい PR URL を解決できることを確認）
- [x] Cmd+U（`prefix+u`）の session_id 照合が壊れない: `configs/claude/settings.json` に herdr の SessionStart 配線（`~/.claude/hooks/herdr-agent-state.sh session`、機械非依存のチルダ形式）を持たせ、`configs/claude/setup.sh` の managed-keys sync（ADR-041、`hooks` キーを dotfiles 側の値で全置換）が配線を消さないようにする。背景: herdr integration install が `~/.claude/settings.json` に書く SessionStart 配線は dotfiles 側に無かったため、setup が走るたびに全置換で消え、新規セッションの `agent_session` が herdr に報告されず「PR が見つかりません: session_id=<unset>」で全滅していた（実機は配線再適用+手動発火で `agent_session` 登録を確認済み）
- [x] バックストップ: `herdr integration status` が `current` でも設定ファイル側の配線（`~/.claude/settings.json` / `~/.codex/hooks.json` の `herdr-agent-state` 参照）が消えていれば `configs/herdr/setup.sh` が install を再実行して修復し、`--dry-run` も ✗ WIRING MISSING として検出する（status は hook スクリプト自体のバージョンしか見ないため、配線欠落時も current を返し続ける）
- [x] Cmd+U を pane_id キャッシュに単純化し、herdr integration（hooks 配線）非依存にする: session_id 照合は「pane → session の対応付け」を SessionStart hook の配線に依存しており、配線が消えると全滅する構造的な弱点が残る。statusline.js は herdr が pane のシェルに与える `HERDR_PANE_ID` を Claude Code 経由で継承しているので、これをキーに `/tmp/gh-pr-pane-<pane_id>` へ表示中 PR を書き出し、`open-pr.sh` は `herdr pane current --current` の `pane_id`（`agent_session` と異なり常に存在するフィールド）で直読みする。session_id キャッシュ（`/tmp/gh-pr-session-*`）と cwd md5 キャッシュ（`/tmp/gh-pr-<md5>`）は廃止し、フォールバックは `gh pr view`（foreground_cwd → cwd → HERDR_ACTIVE_PANE_CWD の順）だけ残す
- [x] statusline.js: PR 表示なし（ブランチに PR が無い）のとき pane キャッシュを削除し、古い PR を開かない
- [x] open-pr.sh: pane キャッシュがヒットしない pane（Claude Code が動いていない素のシェル等）でも `gh pr view` フォールバックで PR を解決できる
- [x] `prefix+u` を tmux-sidebar 時代の `tmux-fzf-pr-popup` 相当の一覧 popup に統一する: `type = "shell"`（即時 1 件 open）から `type = "popup"` へ変更し、フォーカス中 pane の `herdr pane read --source recent-unwrapped --format text` でスクロールバックをスクレイプして URL を正規表現抽出、statusline の pane キャッシュが持つ現在の PR を先頭に固定した上で fzf multi-select（`--ansi --multi`）に渡し、選択した URL を開く。旧 tmux 版と異なり OSC 8 ハイパーリンクの復元は不要（`gh` は URL をプレーンテキストで出力するため）だが、`herdr pane read` はスクロールバックが約 1000 行でクランプされる制約があり、長いセッションでは古い PR が窓の外に出て拾えないことを許容する（screen scrape 方式を選択、hook 方式は不採用）
- [x] 一覧に URL が 1 件も無い場合、popup は即座に閉じずメッセージを表示してキー入力を待つ（`herdr-agent-picker.sh` の `notice()` と同型）
- [x] fzf を Esc / Ctrl+C でキャンセルすると何も開かずに popup が閉じる
- [x] popup 内で `herdr pane current --current` を使わない。popup 自身も一つの pane として登録されるため、popup コマンドの中から `--current` を呼ぶと popup 自身を解決しようとして失敗する（実機で `error: フォーカス中の pane を特定できませんでした` を確認）。herdr は `[[keys.command]]` 実行時に呼び出し元 pane を `HERDR_ACTIVE_PANE_ID` 環境変数で渡す仕組みを持つため（旧実装が `HERDR_ACTIVE_PANE_CWD` を最終フォールバックとして使っていたのと同じ経路）、これを一次情報として使い、詳細（foreground_cwd/cwd）が要る場合は `herdr pane get "$HERDR_ACTIVE_PANE_ID"` で明示 ID 指定して引く
- [ ] 実機: Cmd+U（`prefix+u`）で popup が開き、一覧から選んだ PR/URL がブラウザで開く（`herdr server reload-config` で config 反映後に確認）
- [x] Cmd+U の popup が「一瞬開いて URL を 1 件も出さずに閉じる」不具合を直す。原因: `open-pr.sh` だけが `herdr` を素の PATH 解決で呼んでおり（`agent-picker.sh` / `new-workspace.sh` は `HERDR_BIN="${HERDR_BIN_PATH:-herdr}"` を使っていた）、popup の PATH に `$HOME/.local/bin`（herdr 公式 install script の配置先）が無いため `herdr pane read` が `command not found` で全滅していた。修正は (1) `HERDR_BIN` を導入して 2 箇所の `herdr` 呼び出しを置換、(2) 3 スクリプト共通で `$HOME/.local/bin` を PATH に前置（`HERDR_BIN_PATH` が渡らない場合のフォールバック。ADR-077/079 型の横展開）
- [x] 必須コマンドチェックに `herdr` を含める。herdr が呼べないと候補ゼロの「PR/URL が見つかりません」に化けて原因が見えなくなるため、`fzf` と同様に起動時に die させる
- [x] popup が無言で閉じても事後に追える: 起動時に `invoked pid/tty/term/cwd` を、候補収集後に `candidates=<件数>` を、`set -e` による中断時に ERR trap で `aborted rc/line/cmd` を `~/.local/state/herdr/open-pr.log` に記録する（旧実装は起動ログが無く、実障害時に `herdr: command not found` の行しか残らなかった）。fzf のキャンセル（130）は正常系なので ERR trap を一時解除して `aborted` を出さない
- [x] 検証: PATH から `$HOME/.local/bin` を外した popup 相当の環境で `HERDR_ACTIVE_PANE_ID=<pane>` を渡して実行し、`candidates=2` を収集して fzf が起動、Esc で `fzf cancelled (exit=130)` を記録して閉じることを確認（`script(1)` の疑似 tty 経由）
- [x] 一覧を GitHub の PR/Issue（`https://github.com/<owner>/<repo>/(pull|issues)/<n>`）だけに絞る。用途が「PR/Issue に飛ぶ」ことに尽きるため、ドキュメントや CI ログの URL を並べると目的の 1 件を探す手間が増える。マッチ部分だけを取り出す正規表現にすることで `#issuecomment-...` / `/files` は落ち、同じ PR への別リンクが 1 行に畳まれる（サンプル文字列で除外・正規化・重複畳み込みを確認）
- [x] popup の表示ラグを削る。原因は `gh pr view` のネットワーク往復（実測 578ms/回）を候補収集の 2 番目に、しかも同一 cwd に対して最大 3 回叩いていたこと。(1) ローカル完結のスクロールバックスクレイプ（実測 25ms）を先に回し、pane キャッシュとスクレイプが両方空振りしたときだけ `gh` を叩く、(2) 同じ cwd は 2 度叩かない、(3) `herdr pane get`（python3 起動を伴う）も `gh` を使うときだけに遅延させる。実測: PR/Issue URL がスクロールバックにある pane で 1413ms → 33ms、URL が無く `gh` に落ちる pane でも 1294ms → 817ms
- [x] 少し前に作った PR が一覧から消える問題を、pane キャッシュの履歴化で緩和する。背景: スクレイプは完全な URL 文字列しか拾えないが、Claude Code の応答は PR を `#1071` の短縮表記で書くため、URL 全文が出るのは `gh pr create` した瞬間の 1 回だけ。`herdr pane read` の約 1000 行クランプ（実測 999 行）でその行が窓の外に出ると、直前まで作業していた PR でも候補から消える（実測: 同一 pane のスクロールバックに `#1071` の言及が 17 回あるのに完全 URL は 0 件で、popup に出たのは URL 全文が残っていた 3 件だけだった）。`gh` の出力を hook で捕捉する方式は ADR-076 で不採用済みなので採らず、`statusline.js` が毎ターン `gh pr view` で解決している PR をそのまま履歴として残す
- [x] `statusline.js` が pane キャッシュを 1 件上書きではなく履歴付きで書く: 1 行目 = 現在表示中の PR（無ければ空行）、2 行目以降 = 同一 pane で過去に表示した PR。URL で重複除去し、上限 20 行でトリムする
- [x] PR の無いブランチへ移っても履歴は消えない（1 行目が空行になるだけ）。従来はキャッシュファイルごと削除していたため、直前まで見ていた PR も同時に失われていた
- [x] `open-pr.sh` が pane キャッシュの全行を候補にする。1 行目だけ `★ 現在のPR` として先頭に固定し、2 行目以降は ★ 無しでスクロールバック由来より前に並べる（新しい順）
- [x] `gh pr view` フォールバックは pane キャッシュ（現在・履歴とも）とスクレイプが**すべて**空振りしたときだけ走る
- [x] 検証: `gh` / `fzf` / `herdr` をスタブ化し（`open-pr.sh` は `$HOME/.local/bin` を PATH 先頭に前置するため、`HOME` を差し替えてスタブを勝たせる）、同一 pane で PR のあるブランチ → 別 PR のブランチ → 同じブランチ再実行 → PR の無いブランチ と `statusline.js` を順に単体実行。キャッシュが「1 行目 = 現在（最後は空行）／2 行目以降 = 過去 2 件」になり、同じ PR を続けて表示しても履歴が増えないこと、その状態で `open-pr.sh` が ★ 付き 1 件 + ★ 無し 1 件（現在なしのときは ★ 無し 2 件）を fzf に渡すこと、25 件連続で表示しても現在 1 + 履歴 20 行にトリムされることを確認（7 ケース全 PASS）
- [x] 旧フォーマット（改行なしの 1 行）のキャッシュが残っていても壊れない: 1 行目 = 現在として読まれ、現在の PR と一致すれば履歴に二重掲載されない
- [x] ADR-034 の追加基準 2（チェーン依存: 書き手 `statusline.js` と読み手 `open-pr.sh` がキャッシュのファイル形式で結ばれ、片方の変更が他方を壊す）・3（暗黙の契約: 「1 行目 = 現在 / 2 行目以降 = 履歴」という位置依存フォーマット）に該当するため、`tests/pane-pr-cache.bats` を追加する（7 ケース。`tests/Dockerfile` に `nodejs` を追加して CI でも `statusline.js` 側を実行する。node が無い環境では該当ケースを skip する）
- [ ] 実機: `home-manager switch` で `~/.claude/statusline.js` と `~/.local/bin/herdr-open-pr`（いずれも nix store 経由のコピー）を更新したうえで、ブランチをまたいだ pane の Cmd+U に直前の PR が並ぶ
- [x] herdr は端末から届いたリテラル大文字を shift 付きとして解釈しない（`\x00D` は `prefix+shift+d` ではなく `prefix+d` として処理される）。ghostty から到達させるアクションは `prefix+<小文字>` のみを使う
- [x] Cmd+D（ghostty から `\x00d` = `prefix+d`）で `close_workspace` が起動し、フォーカス中の space（サイドバーで選択中の space）だけを閉じる
- [x] `prefix+d` を空けるため `detach` は herdr 既定の `prefix+q` へ退避した
- [x] Cmd+D の誤爆で space を失わないよう `[ui] confirm_close = true` を明示し、閉じる前に確認プロンプトが出る
- [x] Cmd+S は `workspace_picker`（"Select space" ピッカー）のまま維持される
- [x] Cmd+D を追われた `close_tab` は Cmd+Shift+X（`\x00w` = `prefix+w`）から起動できる（`\x00X` は `close_pane` を誤発火するため使わない）
- [x] `new_workspace`（Cmd+Shift+S → `\x00S`）は同じ大文字問題で `workspace_picker` が開く。`prefix+<小文字>` へ移すか判断する → ADR-077 で `\x00p` = `prefix+p`（ghq ピッカー popup）に付け替えて解消
- [x] `herdr config check` が `config: ok` を返す

### ADR-077: Cmd+Shift+S の workspace 作成に ghq リポジトリピッカーを挟む

**コンポーネント**: herdr | **ADR**: [ADR-077](adr/077-new-workspace-ghq-picker.md)

**受け入れ条件**:

- [x] `configs/ghostty/config` の `super+shift+s` が `text:\x00p`（`prefix+p`、リテラル小文字）を送出し、`configs/herdr/config.toml` の `[[keys.command]] key = "prefix+p"` が popup（`~/.local/bin/herdr-new-workspace`）を起動する（設定反映済み。`herdr server reload-config` が `status: applied` / diagnostics 空）
- [ ] 実機: Cmd+Shift+S でピッカー popup が開く（旧 `\x00S` の「大文字が小文字として解釈され `workspace_picker`（`prefix+s`）が開く」問題が解消している）。ghostty の設定リロード（Cmd+R）が必要
- [ ] 実機: popup 内で `ghq list` のリポジトリ一覧が fzf で表示され、選択すると当該 repo を cwd とする workspace が作られてフォーカスが移る
- [x] 一覧は default worktree（メインのチェックアウト）だけを表示し、`<repo>@<branch>` 形式の linked worktree は除外する（実測 175 件 → 13 件、40ms）
- [x] 組み込みの `new_workspace`（cwd 継承でそのまま作る）は herdr 既定の `prefix+shift+n` に残っている
- [x] 選択した repo を cwd とする workspace が `herdr workspace create --cwd <repo> --label <basename>` で作られる（fzf をモックして検証。label = basename を確認）
- [x] 選んだ repo をカレントディレクトリに持つ workspace が既にある場合は、二重に作らず既存の workspace にフォーカスする（同上の方法で `focus w9` を確認）
- [x] fzf を Esc / Ctrl+C でキャンセルすると workspace を作らずに popup が閉じる（fzf の exit 130 で workspace が増えないことを確認）
- [x] `ghq` / `fzf` が herdr サーバの PATH に無い環境でも、スクリプトが aqua / homebrew の bin を PATH に前置して解決する
- [x] エラー時は popup がキー入力待ちで表示を保持し、`$XDG_STATE_HOME/herdr/new-workspace.log`（既定 `~/.local/state/herdr/new-workspace.log`）にも記録される
- [x] `scripts/setup-manifest.yml` の herdr コンポーネントに `~/.local/bin/herdr-new-workspace` の symlink が定義されている
- [x] `herdr config check` が `config: ok` を返す

**追加の受け入れ条件（popup が一瞬で消える不具合の修正）**:

実機で「popup が一瞬で消える」「選択しても workspace が増えない」が発生。ログから原因を 2 つ特定した。
(1) popup の cwd は `[terminal] new_cwd = "follow"` で呼び出し元ペインを継承するため、dotfiles 以外の repo で押すと aqua が cwd の `aqua.yaml` を探して `fzf: command is not found` で失敗する。旧コードは fzf の非0終了を `|| exit 0` で一括に握り潰していたため無言で閉じていた。
(2) 既存 workspace の判定が「任意のペインの cwd 一致」だったため、別 repo の workspace 内に当該 repo のペインが 1 つあるだけで既存扱いになり、focus するだけで新規作成されなかった。

- [x] dotfiles 以外の repo を cwd とするペインから Cmd+Shift+S を押しても fzf が起動する（`AQUA_GLOBAL_CONFIG` を明示して cwd 非依存で解決する。`env -i` + zeitreise の cwd で、未設定なら `command is not found`・設定すれば `fzf 0.68.0` を返すことを実測）
- [x] fzf が起動失敗（exit が 0/1/130 以外）したときは popup を閉じずにエラーを表示し、fzf の stderr がログに残る（無効オプションで exit 2 を起こし、`unknown option` がログに残り入力待ちになることを確認）
- [x] 選んだ repo と同じ label の workspace が無ければ、他の workspace が当該 repo のペインを持っていても新しい workspace を作る（herdr をモックし、zeitreise の workspace に dotfiles ペインがある状態で dotfiles を選ぶと `workspace create --cwd .../dotfiles --label dotfiles --focus` が呼ばれることを確認）
- [x] 選んだ repo と同じ label の workspace が既にあれば、二重に作らずそれにフォーカスする（同上の方法で zeitreise 選択時に `workspace focus wH` を確認）
- [x] `ghq list -p` の末尾が linked worktree でも選択結果が `pipefail` で捨てられない（旧実装は exit 1・`if` 包みの新実装は exit 0 を確認）
- [x] popup 起動時に tty / TERM / cwd がログに記録され、消えた場合でも原因を追える（実機ログに `invoked pid=... tty=/dev/ttys010 term=xterm-256color cwd=...` を確認）
- [ ] 実機: dotfiles 以外の repo のペインから Cmd+Shift+S を押して popup が消えずに一覧が出る

### ADR-078: SSH 接続中は herdr のタブラベルを接続先ホストにする

**コンポーネント**: fish / herdr | **ADR**: [ADR-078](adr/078-ssh-tab-label.md)

**受け入れ条件**:

- [x] herdr のペインで `ssh <host>` すると、そのタブのラベルが `<色付き丸> <host>` になる（`ssh` をモックして実タブで確認。`-p 2222 root@host` でもホスト名だけが出る）
- [x] タブラベルの色分けは絵文字で行う（ANSI エスケープはタブバーで文字化けし、`[theme]` にタブ個別の色設定も無いことを実機で確認）
- [x] 同じホストには常に同じアイコンが付き、色は 6 色パレットのいずれかになる（bats）
- [x] ssh を抜けると元のラベル（連番 or 手動で付けた名前）に戻る（`emit fish_prompt` でハンドラを発火させて確認）
- [ ] ssh の接続待ちで Ctrl-C した場合も、次のプロンプトが出た時点で元のラベルに戻る
- [x] `ssh a; ssh b` のように 1 コマンドラインで続けて接続しても、最後に戻るのは最初のラベルである
- [x] `_ssh_tab_host` が `user@host` / `-p 2222 host` / `-oPort=22 host` / `host cmd` から `host` を取り出す（bats）
- [x] `_ssh_tab_host` はホストを含まない引数（`-V` のみ等）では何も出力せず、その場合ラッパはリネームしない
- [x] `HERDR_TAB_ID` が無い環境（herdr の外、remote プロファイルの fish）では素の `ssh` と同じ挙動になる
- [x] herdr サーバが停止していて `herdr tab rename` が失敗しても、ssh 自体は通常どおり実行される（`HERDR_SOCKET_PATH` を無効パスにして確認。元ラベルを控えられないためリネーム自体を行わない）
- [ ] master 取り込み後に `configs/fish/setup.sh` を実行し、`--dry-run` が `conf.d/herdr-ssh-tab.fish` を含めて OK を返す（worktree からの実行では既存 symlink が master 実体を指すため WRONG TARGET になる。対象リストに入っていることは MISSING 判定で確認済み）
- [x] `tests/fish-functions.bats` の "all fish functions load successfully" が新規関数を含めて通る
- [x] 撤去済み `__tm_session_name`（`.gitignore` の `configs/fish/functions/__*` により配布されず、CI で常に失敗していた）のテスト 3 件を削除し、`bats tests/` が緑になる（9/9 ok。テスト名に全角括弧を含めると bats がテスト名を解決できず実行されないため ASCII に統一した）

### ADR-079: Cmd+A でエージェント一覧を j/k で辿ってフォーカスする

**コンポーネント**: herdr | **ADR**: [ADR-079](adr/079-agent-picker-popup.md)

**受け入れ条件**:

- [x] navigate mode（`goto`）を spaces と agents に分ける設定が herdr に無いことを確認した（`herdr --default-config` のキー一覧に navigate mode を開くアクションは `goto` のみ。バイナリのアクション enum にも `FocusSidebar` 相当は無く、末尾は `OpenNotificationTarget, OpenNavigator`）
- [x] `configs/ghostty/config` の `super+a` が `text:\x00a`（`prefix+a`、リテラル小文字）を送出し、`configs/herdr/config.toml` の `[[keys.command]] key = "prefix+a"` が popup（`~/.local/bin/herdr-agent-picker`）を起動する定義になっている
- [x] `prefix+a` が herdr 組み込みアクションおよび既存の `[[keys.command]]` と衝突しない（`config.toml` の全キーを走査して確認）
- [x] 一覧は `herdr api snapshot` 1 回から生成され、`<状態アイコン> <workspace>/<tab>  <agent>  <タイトル>` の形式で workspace 順に並ぶ（実測 2 エージェント）
- [x] `pane_id` は一覧に表示されない（TSV の 1 列目に埋め、fzf の `--with-nth=2..` で隠す）
- [x] j/k で一覧を移動できる（`--no-input` で検索欄を隠して bind。pty 上で `jj` → 3 行目、`G` → 末尾、`Gk` → 1 つ上を実測）
- [x] 文字を打っても絞り込みが起きず選択行が動かない（`abc` を打っても 1 行目のまま。j/k との両立は不可能なため絞り込みを捨てる判断）
- [x] 選択すると `herdr agent focus <pane_id>` が呼ばれる（herdr をモックして `agent focus wM:p2` を確認。実サーバへの `herdr agent focus` 自体も自ペインを対象に成功を実測）
- [x] Esc / Ctrl+C / q でキャンセルすると focus を呼ばずに popup が閉じる（fzf の exit 130 で `agent focus` が呼ばれないことを確認）
- [x] fzf が起動失敗（exit が 0/1/130 以外）したときは popup を閉じずにエラーを表示し、`$XDG_STATE_HOME/herdr/agent-picker.log` に残る（exit 2 を起こして入力待ちとログを確認）
- [x] エージェントが 1 件も無いときは popup が一瞬で閉じず、メッセージを出してキー入力を待つ（空の snapshot をモックして確認）
- [x] `fzf` / `jq` が herdr サーバの PATH に無い環境でも、スクリプトが aqua / homebrew の bin を PATH に前置して解決する（`AQUA_GLOBAL_CONFIG` も明示して cwd 非依存にする。ADR-077 と同型）
- [x] `scripts/setup-manifest.yml` の herdr コンポーネントに `~/.local/bin/herdr-agent-picker` の symlink が定義されている
- [x] master 取り込み後: `herdr config check` が `config: ok` を返し、`herdr server reload-config` が `status: applied` / diagnostics 空を返す（master に fast-forward 取り込み後に実測）
- [x] master 取り込み後: `~/.local/bin/herdr-agent-picker` の symlink が作られ、`scripts/setup.sh --dry-run` が `herdr-agent-picker ✓ OK` を返す
- [ ] 実機: ghostty の設定リロード（Cmd+R）後、Cmd+A でピッカー popup が開き、j/k で移動して Enter で当該エージェントにフォーカスが移る
- [ ] 実機: 別 workspace のエージェントを選んでも workspace を跨いでフォーカスが移る
- [ ] 実機: herdr 以外の ghostty ウィンドウで Cmd+A が全選択でなくなることを許容できるか確認する（ghostty にアプリ別バインドが無いため上書きは全ウィンドウに及ぶ）

**追加の受け入れ条件（sre-hub 等ローカル aqua.yaml のバージョンに引っ張られて fzf が落ちる不具合の修正）**:

実機で「`prefix+a` のたびに `unknown option: --no-input` で fzf が exit=2 になる」が sre-hub の cwd で頻発。`AQUA_GLOBAL_CONFIG` を明示していても、aqua は cwd から辿ったローカル `aqua.yaml` を探索してグローバル設定にマージするため、呼び出し元 repo（sre-hub）が同名パッケージ（`fzf@v0.56.3`。dotfiles 側は `fzf@v0.68.0`）を別バージョンで固定していると、そちらが優先解決される。v0.56.3 には `--no-input`（fzf 0.65 系で追加）が無く unknown option になる。ADR-077/079 の「`AQUA_GLOBAL_CONFIG` を明示すれば cwd 非依存になる」という前提はローカル aqua.yaml に同名パッケージが無い場合にしか成り立たなかった。

- [x] `AQUA_CONFIG` で dotfiles の aqua.yaml 1 本を明示し、aqua のカレントディレクトリ探索（ローカル `aqua.yaml` のマージ）自体を無効化する（`agent-picker.sh` / `new-workspace.sh` / `open-pr.sh` の 3 スクリプトに適用。ADR-077/079 型は全て同じ脆弱性を持つため横展開）
- [ ] 実機: sre-hub を cwd とするペインから Cmd+A を押しても fzf が `--no-input` を認識して popup が開く

### ADR-080: Cmd+G を空けて将来の割り当て用に確保する

**コンポーネント**: ghostty / herdr | **ADR**: [ADR-080](adr/080-free-cmd-g-keybind.md)

**受け入れ条件**:

- [x] `configs/ghostty/config` の `super+g` が `ignore` になっている（`ghostty +validate-config --config-file` が診断を出さないことを確認。同ファイルに不正な action を足すと `keybind: unknown error error.InvalidAction` を報告するので、検証経路自体が機能していることも確認済み）
- [x] 行を削除する方式は採らない（ghostty 組み込みの `super+g=navigate_search:next` が復活することを `ghostty +list-keybinds --default` で確認したため、`ignore` を明示する）
- [x] herdr 側の `goto = "prefix+g"` は残っており、物理 Ctrl+Space → g で navigate mode を開ける（`configs/herdr/config.toml` は変更なし）
- [ ] 実機: ghostty の設定リロード（Cmd+R）後、Cmd+G を押しても何も起きない（navigate mode も ghostty の検索も発火しない）

---

### ADR-081: main worktree での git switch/checkout を PreToolUse hook でブロックする

**コンポーネント**: claude | **ADR**: [ADR-081](adr/081-block-main-worktree-branch-switch.md)

**受け入れ条件**:

- [x] main worktree（`git rev-parse --git-dir` == `--git-common-dir`）で `git switch <default 以外>` / `git checkout <default 以外>` を実行しようとすると `permissionDecision: "deny"` で拒否される（実 git リポジトリ + 実 worktree を使った統合テストで確認）
- [x] ~~リンク worktree（main worktree ではない）では同じコマンドがブロックされない~~ → ADR-082 でリンク worktree も自身の branch に固定する方向に反転（統合テストで確認。旧挙動は本 ADR 時点でのもの）
- [x] default branch（`git switch <default>` 自身）への切替はブロックされない
- [x] `git checkout <ref> -- <path>` / 既存パスに一致する `git checkout <path>` はファイル復元とみなしブロック対象外になる
- [x] `git switch -c <newbranch>` / `git checkout -b <newbranch>` のような新規ブランチ作成も同様にブロックされる
- [x] `&&`/`||`/`;`/`|` で連結されたコマンド内の `git switch`/`checkout` も検出される
- [x] git 以外のコマンド・読み取り専用 git コマンド（`status` 等）・`switch -`（直前ブランチ復帰）は誤検知しない
- [x] パース不能・非 git リポジトリ・git 実行失敗時は常に許可する（fail-open）
- [x] `git -C <main worktree> switch <branch>`（cwd が main worktree の外）で回避できない（Codex stop-review 指摘。統合テストで確認）
- [x] `git -C <linked worktree> switch <branch>`（cwd が main worktree）を誤ってブロックしない（Codex stop-review 指摘。統合テストで確認）
- [x] `-C` が複数回指定された場合も直前の実効ディレクトリに対して相対解決される
- [x] `cd <main worktree> && git switch <branch>`（-C を使わない cd 単独の回避）で回避できない（Codex stop-review 指摘 2。統合テストで確認）
- [x] `cd <dir> && git -C <相対パス> switch <branch>`（cd 後の相対 -C 基点ズレを突く回避）で回避できない（同上）
- [x] ~~`cd <linked worktree> && git switch <branch>` は誤ってブロックしない~~ → ADR-082 で同上反転（自身の branch への no-op switch のみ誤ブロックしない）
- [x] `-C` は git 本来の挙動どおり単発の呼び出しにしか効かず、`cd` のように後続コマンドの実効 cwd を書き換えない
- [x] `hook_input.cwd`（Claude Code が追跡するセッション cwd）があれば優先し、無ければ `os.getcwd()` にフォールバックする
- [x] `git commit -m "$(cat <<'EOF' ... EOF)"` の heredoc 本文に `cd`/`git switch` という**説明文字列**が含まれても実コマンドとして誤検知しない（自己回帰: 本 ADR 自身の commit で誤検知して発覚。統合テストで確認）
- [x] heredoc 終了後に続く本物の `git switch` は引き続き検出される
- [x] `configs/claude/scripts/tests/test_block_worktree_branch_switch.py`（ADR-082 でリネーム。旧名 `test_block_main_worktree_branch_switch.py`）の全テストが PASS する（34/34）
- [ ] 実機: sre-hub の main worktree で `git switch <feature-branch>` を実行し、拒否メッセージとともに EnterWorktree の利用を促されることを確認する

### ADR-082: worktree と branch を 1:1 に固定し、linked worktree でも branch 切替をブロックする

**コンポーネント**: claude | **ADR**: [ADR-082](adr/082-pin-every-worktree-to-single-branch.md)

**受け入れ条件**:

- [x] main worktree は引き続き default branch に固定され、default 以外への `git switch`/`checkout` は deny される（既存 ADR-081 の挙動を維持。統合テストで確認）
- [x] linked worktree も「現在チェックアウトしている branch」に固定され、別 branch への `git switch`/`checkout`（default branch も含む）は deny される
- [x] linked worktree で自身の現在 branch への switch（no-op）はブロックされない
- [x] linked worktree での新規ブランチ作成（`git switch -c` / `git checkout -b`）も他 branch への逸脱としてブロックされる
- [x] linked worktree が detached HEAD で現在ブランチを判定できない場合は fail-open で許可する
- [x] `git -C <linked worktree> switch <branch>` / `cd <linked worktree> && git switch <branch>` など、main worktree 判定と同様の `-C`/`cd` 追跡経路でも linked worktree の固定 branch 判定が正しく適用される
- [x] `configs/claude/scripts/block-worktree-branch-switch.py`（`block-main-worktree-branch-switch.py` からリネーム）・`configs/claude/settings.json` の hook パス・`configs/claude/scripts/tests/test_block_worktree_branch_switch.py` が一致して更新されている
- [x] `configs/claude/scripts/tests/test_block_worktree_branch_switch.py` の全テストが PASS する（39/39）
- [x] グローバル CLAUDE.md「並列セッションの衝突回避（worktree isolation）」に worktree:branch 1:1 の不変条件を明記する
- [x] グローバル CLAUDE.md の「main worktree の未コミット変更を引き継ぐ場合は分離しない」という例外を削除し、`git stash push` → `EnterWorktree` → `git stash pop` の手順に置き換える（1:1 不変条件と矛盾する例外を残さない）
- [ ] 実機: 既に branch がずれてしまっている worktree（例: sre-docs の default worktree）は本 hook では自動修復されないため、手動で default branch に戻す必要があることをユーザに確認済み

---

### ADR-083: 作成から72時間超の worktree を launchd で無条件自動削除する

**コンポーネント**: fish | **ADR**: [ADR-083](adr/083-worktree-launchd-auto-cleanup.md)

**受け入れ条件**:

- [x] `configs/fish/scripts/worktree-auto-cleanup.sh` が `ghq list --full-path` で列挙した全リポジトリを横断し、各リポジトリの `git worktree list --porcelain` から worktree を取得する（実機: ユーザーの ghq 管理下 930 worktree を横断し、実行時間は約24秒。当初 `ghq list` が linked worktree 自身も別 repo として列挙するため repo数×worktree数で重複処理する不具合があったが、`git rev-parse --git-dir`/`--git-common-dir` の一致判定を repo 発見側にも適用し解消）
- [x] main worktree（`git rev-parse --git-dir` == `--git-common-dir` のディレクトリ）は判定・削除の対象から常に除外される（実機の 2 回の実削除テストで main worktree が無傷なことを確認）
- [x] worktree ディレクトリの `stat -f %B`（birthtime）から経過時間を算出し、72 時間を超えたものだけを削除対象とする（実機 930 worktree の dry-run で age 79h〜3986h の候補のみが挙がり、72h 以下のものは含まれないことを確認）
- [x] 削除対象の判定にマージ状態・ブランチ名は一切使わない（`gw_rm.fish` のマージ判定ロジックとは独立している。コード上そのようなロジックが存在しないことを確認）
- [x] 72 時間以内の worktree（未マージ・作業中を含む）は削除されない（実機 dry-run で 72h 以下の候補が一件も出ないことを確認。境界値は `--hours 0` を使った隔離テスト用リポジトリで `age <= threshold` の判定コードパスを直接確認）
- [x] `git worktree list --porcelain` の `locked <reason>` 行を持つ worktree（`EnterWorktree` でアクティブに使用中のセッション等）は経過時間を問わず削除対象から除外される（`git worktree remove -f` は locked も dirty も無視して強制削除できてしまうため、`--force` の挙動に頼らずスクリプト側で明示的に skip する。実機: ユーザーの実際の 3 件のアクティブセッション worktree が `skipped_locked=3` として正しく除外されることを確認。隔離テストリポジトリでも `git worktree lock` した worktree が実削除を伴う実行でも無傷なことを確認）
- [x] `--dry-run` オプションで実際には削除せず削除対象一覧のみを標準出力・ログに出せる（実機 930 worktree で確認。何も削除されていないことを実行後の `git worktree list` 件数不変で確認）
- [x] `git worktree remove --force` で未コミット変更が残っていても対象を強制削除し、対応するローカルブランチも `git branch -D` で削除する（隔離テストリポジトリで、untracked ファイルを含む dirty worktree が `--force` なしでは `fatal: contains modified or untracked files` で拒否されること、本スクリプト経由では強制削除されブランチも消えることの両方を実 git で確認）
- [x] 削除対象パス・経過時間・成功/失敗が `~/.local/state/worktree-cleanup/cleanup.log` に記録される（実機で `cleanup.log` に記録されることを確認）
- [x] `configs/fish/launchd/com.user.worktree-auto-cleanup.plist` が1日1回スクリプトを起動する launchd agent として定義されている（`StartCalendarInterval` Hour=4/Minute=0。`plutil -lint` で XML 妥当性を確認）
- [x] `configs/fish/setup.sh` が `configs/claude/setup.sh` と同じパターン（`~/Library/LaunchAgents` へコピー、`launchctl load`、`--dry-run` での存在チェック）で launchd agent を導入する
- [x] `configs/fish/setup.sh --dry-run` が plist の導入状態を正しく OK/MISSING 判定する（未インストール状態で `✗ MISSING` と正しい Fix ヒントを実機で確認）
- [x] 実機: ユーザーに 927 件の削除候補が存在することを確認したうえで `scripts/setup.sh --profile full` を実行して launchd agent を実際にインストールし、`launchctl list | grep com.user.worktree-auto-cleanup` でロードされていることを確認した（インストール時に `configs/fish/scripts/worktree-auto-cleanup.sh` に実行属性が付いていない不具合を発見・修正。`~/.local/bin/worktree-auto-cleanup` 経由で plist と同じ `bash -lc` 呼び出しが正常動作することも確認）
- [x] 実機: ユーザーの許可を得て初回の実運用実行を行った。plist と同じ呼び出し形式（`bash -lc '$HOME/.local/bin/worktree-auto-cleanup'`、既定 72h）で手動起動し、`checked=931, removed=924, skipped_locked=1` で失敗ログなしに完了。実行前後で空き容量が増加したことを `df` で確認（計測開始が実行途中だったため正確な総回収量は不明だが、チェックポイント以降だけで 128Gi→149Gi の +21Gi を確認）。launchd の `StartCalendarInterval` による自動起動そのもの（次回は翌4:00）はまだ未検証

---

### git: setup-github-ssh.sh の SSH 接続テストが常に WARN になる

**コンポーネント**: git | **ADR**: —

`configs/git/setup-github-ssh.sh` は `set -uo pipefail`（14行目）配下で `ssh ... -T git@github.com 2>&1 | grep -q "successfully authenticated"` を条件式に使っている。`ssh -T git@github.com` は GitHub が shell を提供しないため**認証成功時も終了コード 1** を返し、`pipefail` によってパイプ全体が非0になる。結果として `grep` が一致しても常に else 側の WARN が表示される。

**受け入れ条件**:

- [x] 認証が通っている環境で Step 6 が `✓ SSH connection to GitHub OK` を表示する（実機: まず `SETUP_*` 環境変数を与えて `configs/git/setup-github-ssh.sh` を直接実行して確認。`scripts/setup.sh` 経由の確認は worktree 内で実行すると symlink 先が worktree に張り替わるため master 取り込み後に main worktree で実施し、`Result: All OK (15)` とともに Step 6 が OK になることを確認済み）
- [x] 認証が通らない環境（鍵未登録・鍵なし）では従来どおり WARN を表示する（`git@github.com: Permission denied (publickey).` を吐いて exit 255 する ssh スタブを PATH 先頭に置いて確認）
- [x] `set -o pipefail` を無効化せず（他ステップの失敗検出を弱めず）に修正する（14行目の `set -uo pipefail` は変更せず、コマンド置換 + `|| true` で ssh の終了コードだけを局所的に無害化）
- [x] 接続テストの失敗がスクリプトの終了コードに影響しない（ssh スタブでの失敗ケース実行時も終了コード 0 を確認）
- [x] `tests/static-analysis.bats` 相当の構文チェックが PASS する（ローカルに bats 未インストールのため、同テストが行う `bash -n`（`scripts` / `configs` 配下の全 .sh）と `fish -n`（`configs/fish` 配下の全 .fish）を直接実行して 0 failure を確認。bats 自体は CI の e2e で実行される）

---

### ADR-084: Nix (home-manager) をパッケージ導入と静的 symlink 配置の層として限定導入する

**コンポーネント**: 複合 | **ADR**: [ADR-084](adr/084-nix-home-manager-package-symlink-layer.md)

Phase A（home-manager と `setup.sh` の共存）のみを対象とする。Phase B（`setup-manifest.yml` からの移管済みエントリ削除・fish 本体の移行）と Phase C（docker/colima・remote/linux profile）は別 ADR で扱う。

> **実機の現状**: 検証のため実機で activate 済みで、`~/` 配下の 53 本は Nix 管理の三段リンクになっている。`scripts/lib/path.sh` の判定修正により `setup.sh` はこれを `WRONG TARGET` と誤判定しない（この修正が無い状態で `setup.sh` を非 dry-run 実行すると、53 本すべてが一段リンクに張り替えられて Nix 側の管理が外れる）。`~/.vimrc` のみ `profiles.full` から外して Nix 単独管理にしてある。
>
> **実マシン（sho-ishii@darwin）への初回ロールアウトで判明した差分**（Phase A スパイクの検証環境では顕在化しなかった）:
> - `flake.nix` の `username` がスパイク環境の値 `"sho"` のままハードコードされており、実際の macOS ユーザー名 `sho-ishii` と不一致だった（`home-manager switch` が `USER is "sho-ishii", expected "sho"` で activation 前に失敗）。`username = "sho-ishii"` に修正し、flake output 名 `homeConfigurations."sho-ishii@darwin"` および README.md のコマンド例を合わせて更新した
> - `jq` を `home.packages` に入れた状態で `nix/check-parity.py` を実行すると、この実マシンでは `~/.local/share/aquaproj-aqua/bin` 側にも `jq` が存在し PATH 衝突（ADR-084 知見 8 が警告していたケース）が実際に発生した。line 1339 の「現状 jq は aqua 側に無く衝突なし」はスパイク環境限定の観測であり、本番機では成立しなかった。aqua 側のバージョン固定を優先するため `jq` を `home.packages` から除外した（`neovim` / `ghostty-bin` のみ Nix 管理を継続）
>
> **知見 9: `username` は 1 台に固定できない**。上記の `"sho"` → `"sho-ishii"` 修正は会社 mac を通す代わりに個人 mac（ユーザー名 `sho`）を switch 不能にした（`USER is "sho", expected "sho-ishii"` で activation 前に失敗）。home-manager は activation 冒頭で `$USER` と `home.username` の一致を検証するため、どちらか 1 つにハードコードする限り必ず片方が壊れる。`usernames = [ "sho" "sho-ishii" ]` から `builtins.listToAttrs` で両方の output を生成し、各マシンは `--flake .#$(whoami)@darwin` で自分の output を選ぶ形にした（`dotfilesDir` は `/Users/${username}/...` なので username に追従する）。

**受け入れ条件（ADR-084 追補: マシン別 username）**:

- [x] `nix eval .#homeConfigurations --apply builtins.attrNames` が `[ "sho-ishii@darwin" "sho@darwin" ]` を返す
- [x] 個人 mac（`whoami` = `sho`）で `home-manager switch --flake .#sho@darwin` が activation まで通り、pull 済みの新規 symlink（`~/.local/bin/herdr-new-default-worktree` / `herdr-pull-default-branch`）が張られる
- [x] README のコマンド例をユーザー名非依存（`.#$(whoami)@darwin`）にする

**受け入れ条件**:

- [x] `flake.nix` / `nix/home.nix` / `nix/symlinks.nix` が追加され、eval が通る（`nix eval .#homeConfigurations."sho@darwin".activationPackage.drvPath` が derivation を返すことを確認。Determinate Nix 3.21.9 / nixpkgs 104240a / home-manager bf9ce9f）
- [x] `nix build .#homeConfigurations."sho@darwin".activationPackage` が成功する（`ghostty-bin` を含めて解決・ビルド完了）
- [x] 生成物 `home-files` を検査し、`mkOutOfStoreSymlink` の最終解決先が dotfiles clone の実体になっていることを確認した（`~/.claude/CLAUDE.md` → `/nix/store/<hash>-hm_CLAUDE.md` → `<dotfiles>/configs/claude/CLAUDE.md` の二段リンク）
- [x] `setup.sh` 側が二段リンクを `WRONG TARGET` と誤判定して張り替える問題を修正した（`scripts/lib/path.sh` の `symlink_points_to` を追加し、`scripts/lib/symlink.sh` / `configs/fish/setup.sh` / `configs/claude/setup.sh` の 3 箇所を最終解決先ベースの判定に変更。ADR-084「Spike の知見」2 を参照）
- [x] home-manager の activate が macOS (aarch64-darwin) で成功する（`activationPackage` を直接 activate。generation 作成・`linkGeneration`・`setupLaunchAgents` まで完走）
- [x] Nix レイヤが実際に symlink を張る経路を先行検証した（`profiles.full` から `vim` を外し `~/.vimrc` を削除して activate → Nix が三段リンクを張り、`realpath` が dotfiles 実体に解決。修正後の `symlink_points_to` は同一と判定、修正前の一段比較は `WRONG TARGET` と誤判定することを実測）
- [x] activate 後、Nix 管理下の 53 本すべてで最終解決先が dotfiles clone 内であることを確認した
- [x] `~/.claude/settings.json` / `~/.gitconfig` / `~/.config/fish/fish_variables` が通常ファイルのまま、`~/.codex/hooks.json` が dotfiles への一段 symlink のまま維持されている（Nix に奪われていない）
- [x] launchd agent（`com.user.worktree-auto-cleanup`）が生存し、fish 4.6.0 の起動と関数読み込みが正常であることを確認した
- [x] `configs/fish/setup.sh` の symlink 対象から `fish_variables` を外す（実機で 2026-07-05 以降 symlink が剥がれて通常ファイルになっており、`setup.sh --dry-run` が `NOT A SYMLINK` で失敗し続けていた。fish が `set -U` のたびに rename で書き換えるため symlink 管理自体が成立しない。ADR-084 知見 6）
- [x] `nix/check-parity.py` が `nix/symlinks.nix` と既存 setup 定義（`setup-manifest.yml` full profile + `configs/fish/setup.sh` + `configs/claude/setup.sh`）の symlink を突合し、意図的除外（`fish_variables`）を除いて一致することを検証する（worktree 内で実行し 53/54 一致・exit 0 を確認。ターゲットの実在チェックも全て PASS）
- [x] `nix/check-parity.py` を main worktree で実行して一致する（.gitignore 済みの端末固有 fish 関数 `claude.fish` / `fable.fish` は setup.sh のみが張るため、両側の比較対象から外して「local only」として報告する実装に修正。worktree / main worktree の双方で exit 0）
- [x] Nix が管理する symlink が `setup.sh` の張るものと同一パス・同一ターゲットになり、activate 後に `bash scripts/setup.sh --dry-run` が新たな失敗を出さない（**共存の判定条件**。master で `Result: All OK (14 checked)`、うち 52 本が `✓ OK (nix)` と判定）
- [x] symlink のターゲットが `mkOutOfStoreSymlink` により dotfiles clone の実体を指しており、`configs/claude/CLAUDE.md` を編集した内容が `home-manager switch` なしで `~/.claude/CLAUDE.md` 経由で読める（管理下 53 本すべてで `realpath` が dotfiles clone 内に解決）
- [x] `~/.local/bin/` 配下に張られるスクリプト（herdr-open-pr / herdr-new-workspace / herdr-agent-picker / worktree-auto-cleanup）が実行可能である（4 本すべて実行属性あり。`worktree-auto-cleanup --dry-run` が `checked=162` で正常完走）
- [x] `~/.config/fish/fish_variables` が Nix の管理対象に**含まれない**（fish の `set -U` が実行時に書き換えるため）。activate 後に `set -U` が成功することを確認した
- [x] `~/.claude/settings.json` / `~/.codex/hooks.json` / `~/.gitconfig` が Nix の管理対象に**含まれない**（activate 後も settings.json / gitconfig は通常ファイル、hooks.json は dotfiles への一段 symlink のまま）
- [x] `~/.claude/skills/` はディレクトリごとではなく dotfiles 由来の skill（codex-sync）のみが個別 symlink として張られ、Claude Code / プラグインが置いた他の skill が消えない（activate 後も 15 件すべて残存）
- [x] `jq` が `home.packages` 経由で入り、PATH 上で解決される（macOS 標準 1.7.1-apple → Nix 1.8.2。`setup.sh --dry-run` は `All OK` のままでマニフェスト解析の互換性に問題なし）
- [x] Nix profile の PATH 順位を実測した（`~/.nix-profile/bin` が **1 位**、aqua が 7 位、Homebrew が 19 位。Nix に入れたパッケージは aqua / Homebrew を無条件に上書きする。ADR-084 知見 8）
- [x] `nix/check-parity.py` が Nix profile と aqua の同名コマンド衝突を検査する（両ディレクトリが揃っていない環境では自動スキップ。現状 `jq` は aqua 側に無く衝突なし）
- [x] GNU tools（ggrep/gsed/gtar/gawk/gfind/gdate）は Homebrew 管理のまま残り、`grep` 等の BSD 版が Nix によって PATH 上で上書きされていない（Nix profile に GNU tools が入っていないことを確認）
- [x] aqua 管理下の CLI（terraform/kubectl 等）のバージョンが Nix 導入前後で変化しない（PATH 衝突検査で機械的に担保）
- [x] neovim / ghostty-bin を `home.packages` に投入する（nvim は Homebrew 0.12.2 → Nix 0.12.4 に切り替わり、`--headless` で lazy.nvim 込みの設定読み込みが成功。ghostty は `~/Applications/Home Manager Apps/Ghostty.app` に GUI が置かれ、手動インストール版 `/Applications/Ghostty.app` とは別インスタンスとして共存。aqua との名前衝突なし、master で `setup.sh --dry-run` は `All OK`）
- [ ] `tests/static-analysis.bats` が PASS する（Nix 導入で既存スクリプトを壊していないこと。ローカルに bats 未インストールのため、同テストが行う `bash -n` / `fish -n` と `nix/check-parity.py --quiet` を直接実行して確認済み。bats 自体は CI の Docker e2e で実行される）
- [ ] Docker e2e（`--profile linux`）が引き続き PASS する（Nix はスコープ外なので影響しないこと）
- [ ] 撤退可能性: `home-manager` を削除した状態でも `bash scripts/setup.sh` 単独で従来通りセットアップが完走する
- [x] 移行後の総行数が減っている見込みが立つ（Phase B で削除できる `setup-manifest.yml` / `configs/fish/setup.sh` / `configs/claude/setup.sh` の行数を実測し、Nix 側の増分と比較する。**増えるなら Spike は却下**）→ **実測の結果、総行数は 1,612 → 2,092 行（+480 行 / +30%）に増加し、この基準は満たさなかった**。remote/linux profile が Nix 非対象のため `setup.sh` の symlink コードを一行も削除できず、profile 分岐（+約 60 行）と多段リンク判定（`scripts/lib/path.sh` 49 行）が上乗せされた。詳細と判断材料は [ADR-085 の「移行後の評価」](adr/085-nix-phase-b-manifest-migration.md) を参照

---

### herdr: codex 未導入環境で integration install に失敗し Docker e2e が落ち続けていた

**コンポーネント**: herdr | **ADR**: —

`configs/herdr/setup.sh` は `AGENTS=(claude codex)` を固定で対象にしていたが、codex CLI は `linux` profile に含まれない（`configs/codex/setup.sh` は full/remote のみ）。そのため Docker e2e では `herdr integration install codex` が失敗し、`setup.sh` が exit 1 で終わっていた。エラー出力を `>/dev/null 2>&1` で握りつぶしていたため、CI では `✗ install failed` としか出ず原因が追えなかった。ADR-084/085 の作業以前から CI は全て failure だった。

**受け入れ条件**:

- [x] codex CLI が PATH にある場合のみ `AGENTS` に codex を含める（full profile では manifest 上 codex コンポーネントが herdr より先に実行されるため影響しない）
- [x] `herdr integration install` の失敗時に stderr の内容を表示する（原因追跡のため握りつぶさない）
- [x] Docker e2e（`--profile linux`）が PASS する（`setup.sh --non-interactive` が `All OK (created/fixed: 14)`、`--dry-run` が `All OK (14 checked)`、bats 12 件すべて ok）

---

### ADR-085: full profile の symlink 定義を setup.sh から home-manager へ移管する（Phase B）

**コンポーネント**: 複合 | **ADR**: [ADR-085](adr/085-nix-phase-b-manifest-migration.md)

ADR-084 Phase A で生じた symlink の二重定義を、full profile に限って解消する。fish 本体の移行と docker/colima は Phase C（別 ADR）。

**受け入れ条件**:

- [x] `setup-manifest.yml` の `symlinks` が `nix_managed: true` を受け付け、full profile ではスキップされる
- [x] remote / linux profile では `nix_managed: true` のエントリも従来どおり symlink が張られる（Nix はこれらの profile を対象にしないため）
- [x] `scripts/setup.sh` が component setup スクリプトに `SETUP_PROFILE` を渡し、`configs/fish/setup.sh` / `configs/claude/setup.sh` がそれを読んで挙動を切り替える
- [x] `configs/fish/setup.sh` の functions ループが `git ls-files` で tracked/untracked を判定し、**tracked（dotfiles 管理）は full でスキップ・untracked（端末固有）は profile を問わず張る**
- [x] 実機（main worktree, full profile）で `~/.config/fish/functions/claude.fish` / `fable.fish` が引き続き symlink として存在する（ADR-084 知見 7 の課題 2 が解消されていること）
- [x] `nix/check-parity.py` が `nix_managed: true` を正として突合する（`MIGRATED_TO_NIX` のハードコードを廃止し、manifest とコードの整合を機械的に保つ）
- [x] full profile で `bash scripts/setup.sh --dry-run` が `All OK` になる（Nix が張ったリンクを setup.sh が二重に主張しない）
- [x] full profile で `bash scripts/setup.sh`（非 dry-run）を実行しても Nix 管理の symlink が張り替えられない
- [x] `--profile linux` の Docker e2e が PASS する（remote/linux では従来どおり全 symlink が張られること）
- [x] `tests/static-analysis.bats` 相当の構文チェック（`bash -n` / `fish -n`）が PASS する
- [x] 撤退可能性: home-manager を削除しても、`--profile remote` 相当の経路で全 symlink を復元できる手段が残っている（Docker e2e がクリーンな Linux 環境で `--profile linux` から全 symlink を新規作成（`created/fixed: 14`）していることをもって証明とする。`nix_managed: true` は Nix 非対象 profile では無視されるため、home-manager を失っても remote/linux 経路で復元できる）

**検証サマリ（実機 macOS + Docker）**:

| 検証 | 結果 |
|---|---|
| full profile `--dry-run`（main worktree） | `All OK (2 checked)` — symlink 13 件はスキップ、copies のみ検査 |
| full profile 非 dry-run（main worktree） | `All OK (created/fixed: 0)` — Nix 管理 **57 本すべて readlink 差分なし** |
| 端末固有 fish 関数 | `claude.fish` / `fable.fish` が dotfiles 実体への symlink として存続 |
| Docker e2e（linux profile） | setup 完走 `created/fixed: 14` → dry-run `All OK (14 checked)` → bats **12/12 ok** |
| `nix/check-parity.py` | 53/53 整合、端末固有 2 件は local only として報告 |

---

### ADR-086: herdr の workspace 新規作成時に claude session を自動起動する

**コンポーネント**: herdr | **ADR**: [ADR-086](adr/086-herdr-new-workspace-auto-claude-launch.md)

**受け入れ条件**:

- [x] `herdr workspace create` のレスポンス JSON に新規 pane の `pane_id` が含まれることを実機で確認した（`.result.root_pane.pane_id`。テスト用 workspace を作成後 `herdr workspace close` で後片付け済み）
- [x] `configs/herdr/new-workspace.sh` が新規 workspace 作成時（既存 workspace への focus 分岐は対象外）に `herdr agent start <name> --kind claude --pane <pane_id>` を呼ぶ
- [x] `<name>` は pane_id から導出され、複数 workspace で同時に claude を起動しても名前が衝突しない
- [x] `agent start` が失敗しても `die()` は呼ばれず、ログに warn を残した上で popup は通常どおり閉じる（workspace 自体は使える状態のまま残る）
- [x] `bash -n configs/herdr/new-workspace.sh` が構文エラーなく通過する
- [x] 実機（CLI 直接実行、popup 外）: `prefix+p` 相当の実処理（`herdr workspace create --cwd <repo> --label <label> --focus` → `herdr agent start <name> --kind claude --pane <pane_id>`）を `kubernetes/dns` repo で実行し、新規 workspace の pane で claude session が実際に起動することを確認した（`agent_status: idle`, `interactive_ready: true`, `terminal_title: "claude ~/g/g/k/dns"` を実機確認）。**この検証方法は不十分だった**: 同じ手順を実際に `Cmd+Shift+S`（popup 経由）で実行するとユーザー環境で毎回 `agent_pane_busy` エラーになり自動起動しなかった。popup 外からの CLI 直接実行では何度再現を試みても失敗せず、popup 経由でのみ発生する
- [x] `agent_pane_busy` 失敗時に `agent start` を最大 10 回・0.5 秒間隔でリトライする
- [x] 実機（popup 経由）: `Cmd+Shift+S` で未使用の repo を選び、新規 workspace の pane で claude session が実際に自動起動する（ユーザー確認済み: 「claude 自動起動は ok」）
- [x] `launch_claude_retry` のリトライループが popup の exit（= クローズ）をブロックしない。スタンドアロンのシェルスクリプトで、バックグラウンド化した処理が親プロセスの即時 exit を妨げず独立して完走することを実測した（`main start`/`main end` が同時刻、2 秒後に `background done` がログに残る）
- [x] 実機（popup 経由）: `Cmd+Shift+S` で repo を選んだ直後（claude 起動完了を待たず）に popup が閉じる。バックグラウンド化前は claude 起動待ちで popup のクローズが遅延していた（ユーザー確認済み）

---

### ADR-087: 新しい tab / workspace を repo の default worktree で開く

**コンポーネント**: herdr | **ADR**: [ADR-087](adr/087-new-tab-workspace-at-default-worktree.md)

**受け入れ条件**:

- [x] `[terminal] new_cwd` に「repo の default worktree」に相当する選択肢が無いことを確認した（`herdr --default-config` の記載は `follow` / `home` / `current` / 固定パス の 4 つのみ）
- [x] `configs/herdr/new-default-worktree.sh` が linked worktree の pane から呼ばれたとき、default worktree を cwd として `herdr tab create` / `herdr workspace create` を呼ぶ（herdr をモックし、sre-hub の linked worktree `.claude/worktrees/knowledge-map` から main checkout `sre-hub` に解決されることを確認）
- [x] default worktree から呼んだ場合も同じパスに解決される（冪等）
- [x] git 管理外のディレクトリから呼んだ場合は解決せず呼び出し元の cwd をそのまま使う（`/tmp` で確認）
- [x] 呼び出し元 cwd は pane の `cwd` を一次情報とし、`HERDR_ACTIVE_PANE_CWD` → `$PWD` の順にフォールバックする（`foreground_cwd` は使わない。ADR-076 の知見）
- [x] tab モードは `HERDR_ACTIVE_WORKSPACE_ID` があれば `--workspace` を付け、無ければ付けない
- [x] workspace モードは `--label` に default worktree の basename を渡す
- [x] 引数が不正・未指定の場合は exit 2 で終了する
- [x] `configs/herdr/config.toml` で組み込みの `new_tab` / `new_workspace` が空文字で無効化され、同じキー（`prefix+c` / `prefix+shift+n`）に `type = "shell"` の `[[keys.command]]` が定義されている
- [x] `herdr config check` が `config: ok` を返す（編集後の config.toml を `HERDR_CONFIG_PATH` で指定して確認）
- [x] `nix/symlinks.nix` と `scripts/setup-manifest.yml` の双方に `~/.local/bin/herdr-new-default-worktree` が定義され、`nix/check-parity.py` が整合を報告する（54 links）
- [x] `bash -n configs/herdr/new-default-worktree.sh` が構文エラーなく通過する
- [x] master 取り込み後: `home-manager switch` で `~/.local/bin/herdr-new-default-worktree` の symlink が作られ、実行可能である（新規 symlink のため switch が必要。既存スクリプトの編集と異なり out-of-store symlink だけでは反映されない）。実行属性は `git update-index --chmod=+x` でインデックスに記録した（`git add` が filesystem の 644 で上書きするため、commit 直前に再適用が必要だった）
- [x] master 取り込み後: `herdr config check` が `config: ok`、`herdr server reload-config` が `status: applied` / diagnostics 空を返す
- [ ] 実機: linked worktree に居る pane から `Cmd+T` を押すと、新しい tab が repo の default worktree で開く
- [ ] 実機: linked worktree に居る pane から `prefix+shift+n` を押すと、新しい workspace が repo の default worktree で開く
- [x] `new-default-worktree.sh` の初回実行バグ修正: `LOG_FILE` 定義直後に `mkdir -p` する（ログディレクトリ未作成の初回は `herdr tab create >>"$LOG_FILE"` のリダイレクトごと失敗し、tab を作らずに失敗扱いになっていた。ADR-088 の実装中に同型バグを踏んで発覚。既存環境では `~/.local/state/herdr/` が既にあるため実機では顕在化していなかった）

---

### ADR-088: space / tab を開いたときに default branch を自動で pull する

**コンポーネント**: herdr | **ADR**: [ADR-088](adr/088-auto-pull-default-branch-on-open.md)

**受け入れ条件**:

ローカルの bare repo を origin にした fixture（ネットワーク非依存）で検証した。

- [x] default worktree かつ default branch に居るとき `git pull --ff-only origin <default branch>` が実行され、実際に HEAD が前進する
- [x] 2 回目以降の実行も成功する（冪等）
- [x] linked worktree を渡した場合は pull せず skip する（ADR-082 の worktree:branch 1:1 を壊さない）
- [x] default branch 以外のブランチに居る場合は skip する
- [x] `origin` remote が無い repo では skip する
- [x] git 管理外のディレクトリ・存在しないディレクトリでは skip する
- [x] 引数なしで呼ばれた場合は exit 2 で終了する
- [x] 初回実行（ログディレクトリが存在しない状態）でも pull が実行される
- [x] `configs/herdr/new-workspace.sh` が workspace 作成後にバックグラウンドで呼ぶ（popup のクローズを待たせない）
- [x] `configs/herdr/new-default-worktree.sh` が tab / workspace 作成後にバックグラウンドで呼ぶ
- [x] pull の失敗が呼び出し元の成否に影響しない（バックグラウンド起動で終了コードを見ない）
- [x] `nix/symlinks.nix` と `scripts/setup-manifest.yml` の双方に `~/.local/bin/herdr-pull-default-branch` が定義され、`nix/check-parity.py` が整合を報告する（55 links）
- [x] `bash -n` が両スクリプトで構文エラーなく通過する
- [x] ADR-087 のモックテスト 8 件がログディレクトリ修正後も PASS する（回帰なし）
- [x] master 取り込み後: `home-manager switch` で `~/.local/bin/herdr-pull-default-branch` の symlink が作られ、実行可能である
- [x] 実機（スクリプト直接実行）: 配置後の `~/.local/bin/herdr-pull-default-branch` を dotfiles repo に対して実行し、exit 0 かつログに `pulled master` が残ることを確認した
- [x] 実機（herdr 経由）で pull が全く走らない不具合を修正した。原因は herdr が popup クローズ時にプロセスグループへ SIGHUP を送ること。`&` + `disown` だけの素のバックグラウンド起動はスクリプトの 1 行目に到達する前に死ぬためログすら残らなかった（同じ場所の `launch_claude_retry` が無事なのは冒頭で `trap '' HUP` しているから、という差分から切り分けた）
- [x] 呼び出しを `( trap '' HUP; exec <script> <arg> ) &` の形にし、プロセスグループへ SIGHUP を送る再現実験で pull が完走し HEAD が前進することを確認した（素の起動では死亡、`trap` 付きでは生存も併せて実測）
- [x] pull 起動の stderr を `/dev/null` ではなくログへ落とす（今回「ログが無い」以外の手掛かりが無く切り分けに時間を要したため）
- [x] 実機（herdr 経由・再確認）: `Cmd+Shift+S` で repo を選ぶと、popup のクローズや claude 起動を遅らせずに default branch が最新化される（ログに clusterops / aws-infra の `pulled master` が残ることを確認）
- [x] 「pane に何も出力しない」ことが ADR の設計判断として明文化されている。実装当初は結果的にそうなっていただけで判断として書かれておらず、利用者から「pull が実行されているように見えない」と問われて発覚した。あわせて可観測性をログに一本化する要件と、`cd` せず `git -C <path>` で操作する理由も追記した
- [x] ログの読み方（`pulled` / `skip:` / `warn:`）と確認コマンドが `docs/reference.md` に記載されている（ADR は「なぜ」、reference.md は「今の全体像」という役割分担に従い、運用情報は reference.md 側に置く）

---

### ADR のリスト書式を太字 + em ダッシュに統一する

**コンポーネント**: docs | **ADR**: —

textlint（`@textlint-ja/ai-writing/no-ai-list-formatting`）が `- **ラベル**: 説明` を「強調とコロンの組み合わせが機械的」として指摘する。ADR 全体で常態化していたため一括で移行する。ADR 本文の意味は変えず、区切り記号だけを置き換える。

**受け入れ条件**:

- [x] 置換後の書式が textlint を通ることを、候補3種（太字+emダッシュ / 太字なし+コロン / 太字+句点）を実際に lint して確認したうえで採用案を決めた
- [x] `docs/adr/` 全 30 ファイル・128 箇所が `- **ラベル** — 説明` に統一されている（同一行に説明がある 122 箇所）
- [x] ネストしたリストの見出し行（`- **利点**:` のようにコロンが行末）はコロンを落とすだけにする（6 箇所）。textlint はこの形も指摘するため対象に含める
- [x] コードフェンス内は書き換えない（書式例やスクリプトが壊れるため）
- [x] 置換で行が失われていない（全ファイルで置換前後の行数が一致し、`git diff --stat` が 128 挿入 / 128 削除で釣り合う）
- [x] 128 行すべてが「区切り記号のみの変更」で本文が保存されている（逆変換して元ファイルと突き合わせ、不一致 0 件）
- [x] `docs/adr/` に `- **ラベル**: ` パターンが 1 件も残っていない
- [x] `adr-reference` skill にリスト項目の書式規約を明記し、新規 ADR で元の形式に戻らないようにした
