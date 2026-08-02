# リファレンス

## このリポジトリで管理しているコンポーネント

| コンポーネント | パス | 概要 |
|---|---|---|
| Fish 設定 | `configs/fish/` | シェル設定・カスタム関数・エイリアス |
| Ghostty 設定 | `configs/ghostty/` | ターミナルエミュレータ設定 |
| Neovim 設定 | `configs/nvim/` | エディタ設定（lazy.nvim） |
| herdr 設定 | `configs/herdr/` | ターミナルマルチプレクサ設定（キーバインド・サイドバー・agent integration） |
| Claude Code 設定 | `configs/claude/` | CLAUDE.md・スクリプト・statusline |
| Claude Code スクリプト | `configs/claude/scripts/` | 通知・自動承認・リダイレクトなどの補助スクリプト |
| Claude Code skills | `configs/claude/skills/` | codex-sync（skill を Codex CLI にも展開） |
| aqua 設定 | `aqua.yaml` | CLIツールバージョン管理 |

### 管理対象外（別リポジトリ）

| コンポーネント | 管理場所 |
|---|---|
| herdr | `herdrdev/herdr` — エージェント認識ターミナルマルチプレクサ（Rust 製）。公式 install script（`~/.local/bin/herdr`）で導入し、`configs/herdr/setup.sh` が `herdr update` で自動更新する |
| agmsg-go（`dispatch` / `review-loop` skills + IPC コア） | `ishii1648/agmsg-go` — 共有 SQLite を通信路とするエージェント間 IPC binary（`agmsg`）と、その上で動く `dispatch` / `review-loop` skills を同梱。dotfiles からの自動配布（bootstrap）は herdr 移行に伴い廃止した（[ADR-076](adr/076-herdr-migration-from-tmux.md)）。手動で使う場合は `go install github.com/ishii1648/agmsg-go/cmd/agmsg@latest` → `agmsg skills install` |

## ツールスタック

| カテゴリ | ツール | 設定ファイル |
|---------|--------|-------------|
| terminal | Ghostty | `configs/ghostty/config` |
| multiplexer | herdr | `configs/herdr/config.toml` |
| editor | Neovim (lazy.nvim) | `configs/nvim/` |
| shell | Fish | `configs/fish/` |
| coding agent | Claude Code | `configs/claude/` |
| package manager | aqua | `aqua.yaml` |
| VCS | Git (SSH署名) | `configs/git/gitconfig` |

## 並列スケール開発アーキテクチャ（廃止）

独立タスクの並列実行のため `/dispatch`・`/orchestrate`・`/session-log` skill と tmux-sidebar の popup picker を使う仕組みがあったが、herdr 移行（[ADR-076](adr/076-herdr-migration-from-tmux.md)）に伴い廃止した。orchestrate・session-log は dotfiles vendor を削除、dispatch・review-loop（agmsg-go 配布）は自動配布（bootstrap）を止めた。並列実行は herdr の agent 機能（`agent start`/`agent send` 等）への置き換えを検討中（未実装）。

### 手動並列作業

Ghostty 起動時に herdr が起動する（`command = ~/.local/bin/herdr`）。セッション（herdr の workspace）とタブの管理は herdr 側のキーバインドで行う（`configs/herdr/config.toml` の `[keys]` を参照。prefix は `ctrl+space`）。

| スコープ | 方法 |
|---------|------|
| リポジトリ単位 | herdr workspace（`prefix+s` の workspace picker / `prefix+g` の goto で切替） |
| リポジトリ内の並列 | git worktree（`gw_add` で作成、herdr の `prefix+shift+g` / `prefix+shift+o` でも操作可能） |

## 主要な運用フロー

### Worktree 管理 — `gw_add` / `gw_cd` / `gw_rm`

| コマンド | 概要 |
|---------|------|
| `gw_add <name>` | worktree 作成 + cd。`--claude` で Claude Code を自動起動 |
| `gw_cd [branch\|path\|/]` | worktree 間を fzf または引数で移動。`/` でメイン worktree に戻る |
| `gw_rm [--dry-run] [--days N]` | マージ済み・古い worktree を一括削除（デフォルト 30 日） |

worktree 配置先: `<リポジトリ>@<worktree名>`（例: `dotfiles@feat-herdr`）

### セットアップ

`scripts/setup.sh` + `scripts/setup-manifest.yml` で dotfiles のセットアップを宣言的に管理（ADR-018）。

```bash
scripts/setup.sh                    # full プロファイルで実行
scripts/setup.sh --profile remote   # remote プロファイルで実行
scripts/setup.sh --dry-run          # チェックのみ
```

マニフェストにコンポーネントごとの symlink 定義・セットアップスクリプト委譲を記述。

### ADR 一覧

→ [issues.md](issues.md)（サマリ・対応状況・ADR リンクを一元管理）

## ツール詳細

Neovim プラグイン・Fish カスタム関数・aqua 管理ツールの詳細は → [reference-tools.md](reference-tools.md)
