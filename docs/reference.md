# リファレンス

## このリポジトリで管理しているコンポーネント

| コンポーネント | パス | 概要 |
|---|---|---|
| Fish 設定 | `configs/fish/` | シェル設定・カスタム関数・エイリアス |
| Ghostty 設定 | `configs/ghostty/` | ターミナルエミュレータ設定 |
| Neovim 設定 | `configs/nvim/` | エディタ設定（lazy.nvim） |
| herdr 設定 | `configs/herdr/` | ターミナルマルチプレクサ設定（キーバインド・サイドバー・agent integration） |
| Claude Code 設定 | `configs/claude/` | CLAUDE.md・スクリプト・statusline |
| Claude Code スクリプト | `configs/claude/scripts/` | 通知・リダイレクト・worktree ガードなどの補助スクリプト |
| Claude Code skills | `configs/claude/skills/` | codex-sync（skill を Codex CLI にも展開） |
| Claude Code permissions ベースライン | `configs/claude/permissions-baseline.json` | どの端末でも必要な deny と推奨 allow の定義。配布物ではなく検査基準で、`setup.sh` が欠落を指摘する（`--fix` で追加のみ実行、[ADR-092](adr/092-permissions-baseline-check.md)） |
| aqua 設定 | `aqua.yaml` | CLIツールバージョン管理 |
| Nix (home-manager) | `flake.nix` / `nix/` | 静的 symlink 配置と OS レベルパッケージの宣言（Spike 中、[ADR-084](adr/084-nix-home-manager-package-symlink-layer.md)） |

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
| package manager (バージョン固定 CLI) | aqua | `aqua.yaml` |
| package manager (OS レベル) | Homebrew → Nix (home-manager) へ移行中 | `nix/home.nix` / `scripts/lib/deps-macos.sh` |
| VCS | Git (SSH署名) | `configs/git/gitconfig` |

## 並列スケール開発アーキテクチャ（廃止）

独立タスクの並列実行のため `/dispatch`・`/orchestrate`・`/session-log` skill と tmux-sidebar の popup picker を使う仕組みがあったが、herdr 移行（[ADR-076](adr/076-herdr-migration-from-tmux.md)）に伴い廃止した。orchestrate・session-log は dotfiles vendor を削除、dispatch・review-loop（agmsg-go 配布）は自動配布（bootstrap）を止めた。並列実行は herdr の agent 機能（`agent start`/`agent send` 等）への置き換えを検討中（未実装）。

### 手動並列作業

Ghostty 起動時に herdr が起動する（`command = ~/.local/bin/herdr`）。セッション（herdr の workspace）とタブの管理は herdr 側のキーバインドで行う（`configs/herdr/config.toml` の `[keys]` を参照。prefix は `ctrl+space`）。

| スコープ | 方法 |
|---------|------|
| リポジトリ単位 | herdr workspace（`prefix+s` の workspace picker / `prefix+g` の goto で切替） |
| リポジトリ内の並列 | git worktree（`gw_add` で作成、herdr の `prefix+shift+g` / `prefix+shift+o` でも操作可能） |
| エージェント単位 | `prefix+a`（Cmd+A）のエージェントピッカーで一覧を j/k で辿って移動（[ADR-079](adr/079-agent-picker-popup.md)）。番号指定は `prefix+alt+1..9` |

### space / tab を開いたときの自動処理

`Cmd+Shift+S`（repo ピッカー）・`Cmd+T`（新しい tab）・`prefix+shift+n`（新しい workspace）では、開くのと同時に以下が自動で走る。

| 処理 | 内容 | ADR |
|---|---|---|
| default worktree で開く | linked worktree に居ても、repo のメインチェックアウトを cwd にする | [ADR-087](adr/087-new-tab-workspace-at-default-worktree.md) |
| claude 自動起動 | 新しい pane で Claude Code を起動（repo ピッカー経由のみ） | [ADR-086](adr/086-herdr-new-workspace-auto-claude-launch.md) |
| default branch を pull | `git pull --ff-only origin <default branch>` | [ADR-088](adr/088-auto-pull-default-branch-on-open.md) |

**自動 pull は pane に何も表示されない。** pane のシェルに入力するのではなく独立プロセスとして走るため（画面を占有せず、popup のクローズや claude 起動を待たせないための設計）、確認はログで行う。

```fish
tail -5 ~/.local/state/herdr/pull-default-branch.log
```

| ログの行 | 意味 |
|---|---|
| `pulled <branch> (dir=...)` | 成功 |
| `skip: <理由> (dir=...)` | 意図的なスキップ（linked worktree / default branch 以外に居る / `origin` remote が無い / git 管理外） |
| `warn: ...` | 失敗（fast-forward できない等）。space / tab 自体は使えるので処理は続行される |

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
