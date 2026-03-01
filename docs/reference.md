# リファレンス

## このリポジトリで管理しているコンポーネント

| コンポーネント | パス | 概要 |
|---|---|---|
| Fish 設定 | `configs/fish/` | シェル設定・カスタム関数・エイリアス |
| Ghostty 設定 | `configs/ghostty/` | ターミナルエミュレータ設定 |
| Neovim 設定 | `configs/nvim/` | エディタ設定（lazy.nvim） |
| tmux 設定 | `configs/tmux/` | マルチプレクサ設定 |
| Claude Code 設定 | `configs/claude/` | CLAUDE.md・スクリプト・statusline |
| Claude Code スクリプト | `configs/claude/scripts/` | フック・通知・シンボリックリンク検証などの補助スクリプト |
| aqua 設定 | `aqua.yaml` | CLIツールバージョン管理 |

### 管理対象外（別リポジトリ）

| コンポーネント | 管理場所 |
|---|---|
| Claude Code skills | 別リポジトリ |

## ツールスタック

| カテゴリ | ツール | 設定ファイル |
|---------|--------|-------------|
| terminal | Ghostty | `configs/ghostty/config` |
| multiplexer | tmux | `configs/tmux/tmux.conf` |
| editor | Neovim (lazy.nvim) | `configs/nvim/` |
| shell | Fish | `configs/fish/` |
| coding agent | Claude Code | `configs/claude/` |
| package manager | aqua | `aqua.yaml` |
| VCS | Git (SSH署名) | `configs/git/gitconfig` |

## 並列作業の構成

tmux セッション一本化（Ghostty tab 廃止）による構成:

| スコープ | 方法 |
|---------|------|
| リポジトリ単位 | tmux session（`tm` コマンドで管理） |
| リポジトリ内の並列 | git worktree + tmux session（`gw_add` で自動作成） |

Ghostty 起動時に `tmux new-session -A -s main` で main セッションに自動接続する。
各リポジトリは `tm` で ghq 管理下のリポジトリから fzf で選択し、リポジトリ名ベースの tmux session を作成・切替する。
リポジトリ内でブランチ並列作業が必要な場合は `gw_add` で worktree + 専用 tmux session を同時に作成する。

## 主要な運用フロー

### セッション管理 — `tm`

ghq 管理リポジトリと既存 tmux セッションを統合した fzf セレクタ。

- 既存セッション: 緑/黄アイコンで表示、選択で `switch-client`
- 未作成リポジトリ: 選択で新規 session 作成 + 切替
- `X` キーでセッション削除（worktree の場合は worktree + branch も自動削除）
- セッション名は ghq パスから自動生成（例: `github.com/<org>/<repo>` → `<org>_<repo>`）

### Worktree 管理 — `gw_add` / `gw_cd` / `gw_rm`

| コマンド | 概要 |
|---------|------|
| `gw_add <name>` | worktree 作成 + tmux session 作成・切替。`--claude` でセッション内で Claude Code を自動起動 |
| `gw_cd [branch\|path\|/]` | worktree 間を fzf または引数で移動。`/` でメイン worktree に戻る |
| `gw_rm [--dry-run] [--days N]` | マージ済み・古い worktree を一括削除（デフォルト 30 日） |

worktree 配置先: `<リポジトリ>@<worktree名>`（例: `dotfiles@feat-tmux`）

### Worktree ピッカー — `tmw_pick`

`tmw_pick` は ghq リポジトリ一覧から fzf で選択し、worktree 名を入力して `gw_add` を呼ぶ。
`tmw_direct_repos.conf` に記載されたリポジトリ（例: dotfiles）は worktree を作成せず直接セッションを開く。

### セットアップ

`scripts/setup.sh` + `scripts/setup-manifest.yml` で dotfiles のセットアップを宣言的に管理（ADR-018）。

```bash
scripts/setup.sh                    # full プロファイルで実行
scripts/setup.sh --profile remote   # remote プロファイルで実行
scripts/setup.sh --dry-run          # チェックのみ
```

マニフェストにコンポーネントごとの symlink 定義・セットアップスクリプト委譲を記述。

### ADR 一覧

意思決定は [docs/adr/](adr/) に ADR として記録:

- [001-tmux-cmd-key.md](adr/001-tmux-cmd-key.md)
- [002-tmux-link-click.md](adr/002-tmux-link-click.md)
- [003-tmux-notification-click.md](adr/003-tmux-notification-click.md)
- [004-tmux-text-copy.md](adr/004-tmux-text-copy.md)
- [005-tmux-pane-keybind-sharing.md](adr/005-tmux-pane-keybind-sharing.md)
- [006-pretooluse-hook-bash-permissions.md](adr/006-pretooluse-hook-bash-permissions.md)
- [007-tmux-claude-pane-state.md](adr/007-tmux-claude-pane-state.md)
- [008-pretooluse-hook-redirect-to-tools.md](adr/008-pretooluse-hook-redirect-to-tools.md)
- [009-claude-permission-ask-inline-response.md](adr/009-claude-permission-ask-inline-response.md)
- [010-dotfiles-regression-testing.md](adr/010-dotfiles-regression-testing.md)
- [011-claude-session-index.md](adr/011-claude-session-index.md)
- [012-fish-function-symlink-per-repo.md](adr/012-fish-function-symlink-per-repo.md)
- [013-claude-permission-ask-auto-block.md](adr/013-claude-permission-ask-auto-block.md)
- [014-claude-redirect-rules-auto-expansion.md](adr/014-claude-redirect-rules-auto-expansion.md)
- [015-claude-settings-json-base-local-merge.md](adr/015-claude-settings-json-base-local-merge.md)
- [016-dotfiles-remote-profile-support.md](adr/016-dotfiles-remote-profile-support.md)
- [017-pretooluse-hook-approve-safe-commands.md](adr/017-pretooluse-hook-approve-safe-commands.md)
- [018-unified-setup-command.md](adr/018-unified-setup-command.md)
- [019-dotfiles-linux-support-and-e2e-testing.md](adr/019-dotfiles-linux-support-and-e2e-testing.md)
- [020-unify-local-override-into-terminal-repo.md](adr/020-unify-local-override-into-terminal-repo.md)
- [021-ssh-visual-indicator.md](adr/021-ssh-visual-indicator.md)
- [022-ssh-auto-tmux-attach.md](adr/022-ssh-auto-tmux-attach.md)
- [023-tmux-nested-architecture-decision.md](adr/023-tmux-nested-architecture-decision.md)
- [025-adr-reference-skill.md](adr/025-adr-reference-skill.md)
- [026-tmux-passthrough-ui-improvement.md](adr/026-tmux-passthrough-ui-improvement.md)
- [027-config-copy-validate-pattern.md](adr/027-config-copy-validate-pattern.md)
- [028-git-ssh-key-gitconfig-profile-separation.md](adr/028-git-ssh-key-gitconfig-profile-separation.md)
- [029-per-terminal-ssh-key-generation.md](adr/029-per-terminal-ssh-key-generation.md)
- [030-claude-code-docker-sandbox.md](adr/030-claude-code-docker-sandbox.md)

## Neovim プラグイン一覧

| プラグイン | 用途 |
|-----------|------|
| dracula/vim | カラースキーム |
| nvim-neo-tree/neo-tree.nvim | ファイルエクスプローラ (`<leader>e`) |
| nvim-telescope/telescope.nvim | ファジーファインダー (fzf-native 連携) |
| akinsho/toggleterm.nvim | ターミナル統合 (`<C-t>`) |
| NeogitOrg/neogit | Git クライアント (diffview 連携) |
| nvim-treesitter/nvim-treesitter | シンタックスハイライト |
| nvim-lualine/lualine.nvim | ステータスライン (worktree 状態表示対応) |
| akinsho/bufferline.nvim | バッファタブ |
| folke/which-key.nvim | キーバインドヘルプ |
| kevinhwang91/nvim-ufo | コード折りたたみ (treesitter ベース) |
| lukas-reineke/indent-blankline.nvim | インデントガイド |
| RRethy/vim-illuminate | カーソル下シンボルハイライト |
| viewer-mode (ローカル) | バッファ読み取り専用モード切替 |

## Fish カスタム関数・エイリアス

### Abbreviations (`conf.d/aliases.fish`)

| 略称 | 展開 |
|-----|------|
| `g` | `git` |
| `k` | `kubectl` |
| `d` | `docker` |
| `t` | `terraform` |
| `gc` | `gcloud` |
| `a` | `aws` |
| `e` | `eksctl` |
| `ic` | `istioctl` |
| `n` | `nvim .` |
| `cc` | `claude` |
| `cat` | `nyan` |
| `python` | `python3` |
| `grep` | `ggrep` |
| `sed` | `gsed` |
| `date` | `gdate` |
| `rgrep` | `grep -r` |

### 主要カスタム関数

| 関数 | 概要 |
|-----|------|
| `tm` | tmux セッション管理 (ghq + fzf) |
| `tms` | SSH 先の tmux セッションに接続（パススルーモード対応） |
| `tmw` | git worktree を fzf で選択して tmux session 作成/アタッチ |
| `tmw_pick` | fzf でリポジトリ選択 → worktree + session 作成 |
| `gw_add` | git worktree 作成 + tmux session 作成 |
| `gw_cd` | worktree 間の移動 |
| `gw_rm` | 古い worktree の一括削除 |
| `g_co_ammend_push_f` | amend + force push |
| `g_co_command_push_f` | commit -a --amend + force push |
| `g_reset` | fzf で commit 選択 → git reset |
| `gh_rate_limit` | GitHub API レート確認 |
| `s_ghq` | ghq リポジトリを fzf で検索 |
| `fish_prompt` | カスタムプロンプト (git branch + worktree 状態表示) |

## aqua 管理ツール

| ツール | バージョン |
|-------|-----------|
| golang/go | go1.22.2 |
| aquaproj/registry-tool | v0.2.4 |
| kubernetes-sigs/kind | v0.22.0 |
| kubernetes/kubectl | v1.30.0 |
| ahmetb/kubectx | v0.9.5 |
| istio/istio/istioctl | 1.21.2 |
| helm/helm | v3.15.0 |
| helmfile/helmfile | v0.164.0 |
| derailed/k9s | v0.32.4 |
| mikefarah/yq | v4.52.4 |
