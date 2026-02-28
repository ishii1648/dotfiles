# ADR-012: 端末固有の設定を dotfiles から分離する

## ステータス

採用済み

## コンテキスト

`ishii1648/dotfiles` は端末・環境をまたいで共有できる設定のみを管理するリポジトリである。しかし現状、**端末固有の設定が dotfiles 内に混入している**。

### 棚卸し: 全コンポーネントの分類

#### fish / conf.d

| ファイル | 現在地 | 分類 | 内容 |
|---------|--------|------|------|
| `aliases.fish` | dotfiles | 共通 | 汎用エイリアス |
| `completions.fish` | dotfiles | 共通 | gcloud・aws CLI の補完登録 |
| `env.fish` | dotfiles | 共通 | Go / editor / aqua / npm の環境変数 |
| `fzf-fish-config.fish` | dotfiles | 共通 | fzf.fish プラグインの UI オプション設定 |
| `fzf.fish` | dotfiles | 共通 | fzf.fish プラグインの初期化・キーバインド登録 |
| `path.fish` | dotfiles | 共通 | Go / aqua / npm / cargo の PATH 設定 |
| `tmw_direct_repos.conf.example` | dotfiles | 共通 | `tmw_direct_repos.conf` のひな形 |
| `l_sandbox.fish` | dotfiles | **端末固有（要削除）** | 端末固有リポジトリの `local.fish` を source するブリッジ。`ghq root` のパスがハードコードされており端末依存 |
| `tmw_direct_repos.conf` | 手動配置（管理なし） | **端末固有** | worktree を作らず直接 tmux セッションを開くリポジトリ一覧 |
| `local.fish` | 端末固有リポジトリ | **端末固有** | AWS 設定・SSL 証明書・Company secrets・GPG 初期化 |

#### fish / functions

| ファイル | 現在地 | 分類 | 内容 |
|---------|--------|------|------|
| `tm.fish`, `tmw_pick.fish` など | dotfiles | 共通 | tmux セッション管理 |
| `gw_add.fish`, `gw_cd.fish`, `gw_rm.fish` | dotfiles | 共通 | git worktree 操作 |
| `g_reset.fish`, `gh_rate_limit.fish` | dotfiles | 共通 | git/GitHub 操作 |
| `s_ghq.fish` | dotfiles | 共通 | ghq 検索 |
| `fish_prompt.fish` | dotfiles | 共通 | プロンプト |
| `__tm_candidates.fish`, `__tm_claude_state.fish` など | dotfiles | 共通 | tmux セッションリスト生成・Claude 状態表示 |
| `a_eks_kubeconfig.fish` | dotfiles（untracked symlink） | **端末固有** | AWS EKS kubeconfig 選択 |
| `a_profile.fish` | dotfiles（untracked symlink） | **端末固有** | AWS プロファイル選択 |
| `a_saml2aws.fish` | dotfiles（untracked symlink） | **端末固有** | AWS SAML2 認証（企業 SSO） |
| `a_sso_login.fish` | dotfiles（untracked symlink） | **端末固有** | AWS SSO ログイン |
| `claude.fish` | dotfiles（untracked symlink） | **端末固有** | Claude Code ラッパー（端末固有 secrets 使用） |
| `codex.fish` | dotfiles（untracked symlink） | **端末固有** | Codex CLI ラッパー（端末固有 secrets 使用） |
| `g_create_pr.fish` | dotfiles（untracked symlink） | **端末固有** | GitHub PR 作成（社内ツール依存） |
| `prtrack.fish` | dotfiles（untracked symlink） | **端末固有** | PR Track CLI（端末固有 secrets 使用） |

#### fish / config.fish

| ファイル | 現在地 | 分類 | 内容 |
|---------|--------|------|------|
| `config.fish` | dotfiles | 共通 | zoxide 初期化など標準的なシェル設定 |

#### claude

| ファイル | 現在地 | 分類 | 内容 |
|---------|--------|------|------|
| `CLAUDE.md` | dotfiles | 共通 | Claude Code の汎用ガイドライン |
| `statusline.js` | dotfiles | 共通 | ステータスバー表示スクリプト |
| `scripts/session-index*.sh` / `.py` | dotfiles | 共通 | セッションインデックス記録・PR URL 収集 |
| `scripts/claude-pane-state.sh` など | dotfiles | 共通 | Hook スクリプト群（汎用実装） |

#### tmux

| ファイル | 現在地 | 分類 | 内容 |
|---------|--------|------|------|
| `tmux.conf` | dotfiles | 共通（一部端末固有を含む） | キーバインド・外観・プラグイン設定。`~/.tmux.local.conf` でローカル上書き可能 |
| `tmux.conf` L126 | dotfiles | **端末固有（要移動）** | `~/.local/bin/prtrack-popup` への参照（社内ツール） |
| `tmux.local.conf.example` | dotfiles | 共通 | ローカル設定のひな形 |
| `tmux-fzf-url-pr-filter` | dotfiles | 共通 | tmux-fzf-url 用 PR URL 生成フィルタ |

#### ghostty

| ファイル | 現在地 | 分類 | 内容 |
|---------|--------|------|------|
| `config` | dotfiles | 共通（一部端末固有を含む） | フォント・テーマ・キーバインド設定。`?local.conf` でローカル上書き可能 |
| `config` L74-75 | dotfiles | **端末固有（要移動）** | `prtrack` ポップアップキーバインド（社内ツール依存） |
| `ghostty-tmux-init.sh` | dotfiles | 共通 | Ghostty 起動時の tmux 初期化スクリプト |

#### nvim

| ファイル | 現在地 | 分類 | 内容 |
|---------|--------|------|------|
| `init.lua`, `lua/` | dotfiles | 共通 | プラグイン管理・汎用設定。`pcall(require, "local")` で端末固有設定を任意読み込み |

### 問題の根本原因

dotfiles に「共通設定のみを含める」というポリシーが明文化されておらず、端末固有の設定を置く場所と管理方法が定まっていない。棚卸し結果の通り、端末固有の設定が fish・tmux・ghostty にまたがって混入している。

現状の fish の symlink 方式（`~/.config/fish` → `dotfiles/configs/fish/` のディレクトリ全体）はこの問題を悪化させる一因だが、根本ではない。仮に symlink 方式を変えても、端末固有ファイルの置き場ルールがなければ同じ問題が再発する。

## 設計案

### 方針1: 分類ルールの明文化

dotfiles に含めてよいファイルの基準を以下の通り定める：

- **dotfiles に含める（共通）**: どの端末でも動作する。端末・組織固有の情報（社内ツール名・認証情報・特定ホスト名など）を含まない
- **端末固有リポジトリに含める（端末固有）**: 特定の端末・組織環境でのみ使用する。secrets・社内ツール・端末固有パスへの依存がある

### 方針2: コンポーネント別の対応

棚卸し結果をもとに、コンポーネントごとに対応方針を定める。

#### fish: ファイル単位 symlink への移行

現状のディレクトリ全体 symlink（`~/.config/fish` → `dotfiles/configs/fish/`）は、端末固有リポジトリがファイルを作成すると dotfiles 内に混入する構造になっている。ファイル単位の symlink に切り替え、各ファイルがそれぞれのリポジトリへ独立して symlink する。

```
# 共通ファイル（dotfiles → ~/.config/fish/）
~/.config/fish/functions/tm.fish      →  dotfiles/configs/fish/functions/tm.fish
~/.config/fish/conf.d/aliases.fish    →  dotfiles/configs/fish/conf.d/aliases.fish

# 端末固有ファイル（端末固有リポジトリ → ~/.config/fish/）
~/.config/fish/functions/claude.fish  →  <端末固有リポジトリ>/configs/fish/functions/claude.fish
~/.config/fish/conf.d/local.fish      →  <端末固有リポジトリ>/configs/fish/conf.d/local.fish
~/.config/fish/conf.d/tmw_direct_repos.conf  →  <端末固有リポジトリ>/configs/fish/conf.d/tmw_direct_repos.conf
```

`l_sandbox.fish` は削除する。fish が `conf.d/` 内の `.fish` ファイルを自動 source するため、`local.fish` を直接 symlink すれば十分。

#### tmux・ghostty: ローカル上書きファイルへの移動

`tmux.conf` と `ghostty/config` は大部分が共通だが、社内ツール (`prtrack`) への参照が一部含まれている。いずれもローカル上書きの仕組みが既にある（`~/.tmux.local.conf`、`?local.conf`）ため、端末固有の設定をそちらに移動する。

| 移動元 | 移動先 |
|--------|--------|
| `tmux.conf` L126（`prtrack-popup` keybind） | `~/.tmux.local.conf`（端末固有リポジトリで管理） |
| `ghostty/config` L74-75（`prtrack` popup keybind） | `~/.config/ghostty/local.conf`（端末固有リポジトリで管理） |

#### claude・nvim: 変更不要

すでに共通設定のみを含んでいる。nvim は `pcall(require, "local")` による端末固有設定の任意読み込みが機能している。

### 方針3: 再発防止のためのチェック機構

setup 後に `check-symlinks.sh` で各 symlink の向き先を検証できるようにする。dotfiles 管理のファイルが端末固有リポジトリを参照していたり、端末固有ファイルが dotfiles 内に存在する場合はエラーとする。

### 変更が必要なファイル

| ファイル | 変更内容 |
|---------|---------|
| `dotfiles/configs/fish/conf.d/l_sandbox.fish` | 削除 |
| `dotfiles/configs/tmux/tmux.conf` | `prtrack-popup` の keybind を削除（`~/.tmux.local.conf` へ移動） |
| `dotfiles/configs/ghostty/config` | `prtrack` popup keybind を削除（`local.conf` へ移動） |
| `dotfiles/configs/claude/scripts/check-symlinks.sh` | fish のチェックをディレクトリ symlink → ファイル単位 symlink の検証に変更 |
| 端末固有リポジトリ | setup script 追加（fish / tmux / ghostty の端末固有ファイルを配置） |
| `dotfiles` | setup script 追加（共通ファイルの個別 symlink 作成） |

### 検討中の事項

- `~/.config/fish/completions/` ディレクトリの扱い（現状 dotfiles 管理のファイルのみ、個別 symlink か dir symlink か）
- dotfiles と端末固有リポジトリの setup script の実行順序（初回セットアップ時）

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-012 セクション）
