# ADR-051: Fish 実装不可要件を理由とした Go 製 tmux サイドバーツールへの移行

## ステータス

Superseded by [ADR-076](076-herdr-migration-from-tmux.md)（tmux-sidebar を撤去し herdr のネイティブサイドバーへ移行）

## 関連 ADR

- 依存: ADR-007（`/tmp/claude-pane-state/` の状態ファイル仕様を継続利用）
- 関連: ADR-050（Fish スクリプト実装を部分廃止。実装言語・ツール構成の決定を変更）

## コンテキスト

ADR-050 の決定（「案C: Rust/Go 自前実装は却下」）を変更する。

ADR-050 で Fish スクリプト + `split-window -hfb` による Claude セッション常時俯瞰サイドバーを実装した。
実装完了後に、ユーザーが必要とする以下3機能が Fish の passive display では実現不可であることが判明した：

| 機能 | Fish での実現可否 | 理由 |
|------|-----------------|------|
| 全 tmux session + window 表示（+ Enter 移動） | × | fzf reload でカーソルリセット問題。1秒ポーリングと interactive 選択の共存が困難 |
| 通常ペイン移動キーからサイドバーを除外 | × | tmux にネイティブ機能なし。`after-select-pane` hook の workaround は UX 悪化 |
| キーボード選択 + Enter でウィンドウ移動 | × | passive display の polling loop にインタラクティブ入力を組み込む設計変更コストが過大 |

[hiroppy/tmux-agent-sidebar](https://github.com/hiroppy/tmux-agent-sidebar)（Rust/Ratatui 実装）は上記3機能すべてを満たしているが、
Rust バイナリの依存と ADR-007 hook 書き換えが必要なため採用しない。

Go でゼロから実装し、独立リポジトリ（`ishii1648/tmux-sidebar`）で管理する。
ADR-007 の状態ファイル仕組みはそのまま継続利用する。

## 設計案

### 案A: Go 製専用ツール（採用）

- 独立リポジトリ `ishii1648/tmux-sidebar` で実装・リリース管理
- `aqua.yaml` でバイナリバージョンを管理し、`setup.sh` でインストール
- dotfiles 側は Fish wrapper と `tmux.conf` のキーバインドのみ保持
- ADR-007 の `/tmp/claude-pane-state/pane_N` をそのまま状態ソースとして利用

**機能:**
- 全 tmux session + window を階層表示（Claude Code 以外のウィンドウも含む）
- Claude Code が存在するウィンドウに状態バッジ表示（running / idle / permission / ask）
- `j/k` でカーソル移動、`Enter` で `switch-client` + `select-window`
- TUI がキー入力をキャプチャすることで通常ペイン移動の対象から実質的に除外

**dotfiles との分担:**

| 管理場所 | 内容 |
|---------|------|
| `ishii1648/tmux-sidebar` | Go 実装・リリースバイナリ |
| dotfiles `aqua.yaml` | バイナリバージョン管理 |
| dotfiles `configs/fish/functions/` | `claude-sidebar-create/toggle` wrapper |
| dotfiles `configs/tmux/tmux.conf` | `prefix+e` keybind・`after-new-window` フック |

### 案B: Fish スクリプト継続（却下）

passive display として Claude Code 状態の監視に特化する分には動作する。
しかし全 session 表示 + Enter 移動 + ペイン除外の3機能が構造的に実現不可。

### 案C: hiroppy/tmux-agent-sidebar 採用（却下）

3機能すべてを満たすが、Rust バイナリ依存・TPM 依存・ADR-007 hook の書き換えが必要。
外部プラグインへの依存は dotfiles のポータビリティを下げる。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `aqua.yaml` | dotfiles | `ishii1648/tmux-sidebar` エントリを追加 |
| `configs/fish/functions/claude-sidebar.fish` | dotfiles | 削除（Go バイナリが直接起動するため不要） |
| `configs/fish/functions/claude-sidebar-create.fish` | dotfiles | split-window の起動コマンドを `fish -l -c claude-sidebar` から `tmux-sidebar` バイナリに変更 |
| `configs/fish/functions/claude-sidebar-toggle.fish` | dotfiles | 同上 |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-051 セクション）
