# 開発環境

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

## 仕様駆動開発の進め方

実装タスクは以下のサイクルで進める。仕様を完成させてから実装するのではなく、**仕様と実装を行き来しながら育てる**。

### サイクル

1. **受け入れ条件を書く** — 「〜できる」形式で箇条書き（完璧でなくてよい）
2. **実装する**
3. **仕様と実装を同期する** — 実装で判明した変更・追記を受け入れ条件に反映
4. **意思決定があれば ADR を作成する** — `create-adr` スキルを使用

### ドキュメントの役割分担

| 種類 | 置き場所 | 内容 |
|---|---|---|
| 課題・受け入れ条件 | `docs/issues.md` | 何を解決するか・完了条件 |
| 意思決定 | `docs/adr/` | なぜこう決めたか・却下した選択肢 |
| 実装 | `configs/` | どう実現するか |

### ルール

- 受け入れ条件は実装ファイルのそばではなく `docs/issues.md` にまとめる
- 仕様は実装後に更新してよい（後追いOK）
- 「なぜこうしたか」だけ書く。実装手順は仕様に書かない

### ADR テンプレート

ADR のセクション構成は以下の通り。

```markdown
## ステータス

Draft | 採用済み | 却下 | 対応不可（受容）

## コンテキスト

背景・問題・制約。

## 設計案

Draft 中に検討した案。却下した選択肢も含む。採用後も根拠として残す。

## 決定

1〜3 文で。採用した案と選んだ理由。Draft 中は「（未定）」。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-NNN セクション）

## 参考（任意）
```

- `## 設計案` が Draft 中の主な作業場所。実装で判明した変更もここに追記する
- `## 決定` は採用済みになったときに 1〜3 文で確定させる
- 受け入れ条件は `issues.md` にのみ定義する（ADR にはリンクのみ）
- ADR のステータスを「採用済み」にするタイミング = `issues.md` の受け入れ条件を確認したタイミング

## ツールスタック

| カテゴリ | ツール | 設定ファイル |
|---------|--------|-------------|
| terminal | Ghostty | `configs/ghostty/config` |
| multiplexer | tmux | `configs/tmux/tmux.conf` |
| editor | Neovim (lazy.nvim) | `configs/nvim/` |
| shell | Fish | `configs/fish/` |
| coding agent | Claude Code | `configs/claude/` |
| package manager | aqua | `aqua.yaml` |
| VCS | Git (SSH署名) | `.gitconfig` |

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

### Git ワークフロー

Claude Code の `git-ship` skill で commit → push → Draft PR 作成を自動化。

### Symlink 管理

`configs/claude/scripts/check-symlinks.sh` で dotfiles のシンボリックリンク状態を検証。
チェック対象: `~/.config/{fish,nvim}`, `~/.config/ghostty/config`, `~/.tmux.conf`, `~/.claude/` 配下。

### tmux 課題対応

tmux 移行に伴う課題は [docs/adr/](adr/) に ADR として記録:

- [001-tmux-cmd-key.md](adr/001-tmux-cmd-key.md)
- [002-tmux-link-click.md](adr/002-tmux-link-click.md)
- [003-tmux-notification-click.md](adr/003-tmux-notification-click.md)
- [004-tmux-text-copy.md](adr/004-tmux-text-copy.md)
- [005-tmux-pane-keybind-sharing.md](adr/005-tmux-pane-keybind-sharing.md)

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

### 主要カスタム関数

| 関数 | 概要 |
|-----|------|
| `tm` | tmux セッション管理 (ghq + fzf) |
| `tmw_pick` | fzf でリポジトリ選択 → worktree + session 作成 |
| `gw_add` | git worktree 作成 + tmux session 作成 |
| `gw_cd` | worktree 間の移動 |
| `gw_rm` | 古い worktree の一括削除 |
| `claude` | Claude Code ラッパー |
| `g_create_pr` | GitHub PR 作成 |
| `g_co_ammend_push_f` | amend + force push |
| `g_reset` | fzf で commit 選択 → git reset |
| `gh_rate_limit` | GitHub API レート確認 |
| `s_ghq` | ghq リポジトリを fzf で検索 |
| `fish_prompt` | カスタムプロンプト (git branch + worktree 状態表示) |
| `a_sso_login` | AWS SSO ログイン |
| `a_profile` | AWS プロファイル選択 |
| `a_eks_kubeconfig` | EKS kubeconfig 設定 |

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
