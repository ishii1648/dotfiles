# ツール詳細リファレンス

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
| `ssh` | ssh 実行中だけ herdr のタブラベルを `⇢ <host>` にする（[ADR-078](adr/078-ssh-tab-label.md)）。ホスト抽出は `_ssh_tab_host`、書き戻しは `conf.d/herdr-ssh-tab.fish` |
| `fish_prompt` | カスタムプロンプト (git branch + worktree 状態表示) |

## aqua 管理ツール

| ツール | バージョン |
|-------|-----------|
| golang/go | go1.22.2 |
| aquaproj/registry-tool | v0.2.4 |
| kubernetes-sigs/kind | v0.22.0 |
| kubernetes/kubectl | v1.30.0 |
| ahmetb/kubectx | v0.9.5 |
| ahmetb/kubectx/kubens | v0.9.5 |
| istio/istio/istioctl | 1.21.2 |
| helm/helm | v3.15.0 |
| helmfile/helmfile | v0.164.0 |
| derailed/k9s | v0.32.4 |
| stern/stern | v1.30.0 |
| mikefarah/yq | v4.52.4 |
| ajeetdsouza/zoxide | v0.9.9 |
| junegunn/fzf | v0.68.0 |
| sharkdp/fd | v10.3.0 |
| BurntSushi/ripgrep | 15.1.0 |
| toshimaru/nyan | v1.2.5 |
| nodejs/node | v22.7.0 |
| hashicorp/terraform | v1.10.3 |
| cli/cli | v2.69.0 |
| docker/buildx | v0.32.1 |
| mike-engel/jwt-cli | 6.2.0 |
| knative/client | knative-v1.14.0 |
| kubernetes-sigs/kubebuilder | v4.0.0 |
| kubernetes-sigs/kwok/kwokctl | v0.6.1 |
| a8m/envsubst | v1.4.3 |
