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

### ADR-012: 端末固有の設定を dotfiles から分離

**コンポーネント**: fish / tmux / ghostty | **ADR**: [ADR-012](adr/012-fish-function-symlink-per-repo.md)

**受け入れ条件**:

- [x] 端末固有の fish functions・conf.d ファイルが dotfiles の `git status` に現れなくなる
- [x] tmux.conf・ghostty/config から社内ツール（prtrack）への参照が除去される
- [x] dotfiles を別端末にクローンしても、端末固有の設定が混入しない
- [x] 既存の共通設定（`tm`, `gw_add`、tmux キーバインド等）が引き続き動作する
- [x] 端末固有リポジトリの setup script で端末固有ファイルを配置できる
