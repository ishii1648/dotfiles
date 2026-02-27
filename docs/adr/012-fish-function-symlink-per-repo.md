# ADR-012: 端末固有の fish 設定を dotfiles から分離する

## ステータス

Draft

## コンテキスト

`ishii1648/dotfiles` は端末・環境をまたいで共有できる設定のみを管理するリポジトリである。しかし現状、**端末固有（会社 PC 専用）の fish 設定が dotfiles 内に混入している**。

### 棚卸し: 現在の設定の所在と分類

#### fish conf.d

| ファイル | 現在地 | 分類 | 内容 |
|---------|--------|------|------|
| `aliases.fish` | dotfiles | 共通 | 汎用エイリアス |
| `l_sandbox.fish` | dotfiles | 端末固有（要削除） | 端末固有リポジトリの `local.fish` を source するブリッジ。`ghq root` のパスがハードコードされており端末依存 |
| `local.fish` | 端末固有リポジトリ | 端末固有 | AWS 設定・SSL 証明書・Company secrets・GPG 初期化 |
| `tmw_direct_repos.conf` | 未管理（~/.config/fish/conf.d/ に手動配置） | 端末固有 | worktree を作らず直接 tmux セッションを開くリポジトリ一覧 |

#### fish functions

| ファイル | 現在地 | 分類 | 内容 |
|---------|--------|------|------|
| `tm.fish`, `tmw_pick.fish` など tmux 関連 | dotfiles | 共通 | tmux セッション管理 |
| `gw_add.fish`, `gw_cd.fish`, `gw_rm.fish` | dotfiles | 共通 | git worktree 操作 |
| `g_reset.fish`, `gh_rate_limit.fish` | dotfiles | 共通 | git/GitHub 操作 |
| `s_ghq.fish` | dotfiles | 共通 | ghq 検索 |
| `fish_prompt.fish` | dotfiles | 共通 | プロンプト |
| `a_eks_kubeconfig.fish` | dotfiles（untracked symlink） | 端末固有 | AWS EKS kubeconfig 選択 |
| `a_profile.fish` | dotfiles（untracked symlink） | 端末固有 | AWS プロファイル選択 |
| `a_saml2aws.fish` | dotfiles（untracked symlink） | 端末固有 | AWS SAML2 認証 |
| `a_sso_login.fish` | dotfiles（untracked symlink） | 端末固有 | AWS SSO ログイン |
| `claude.fish` | dotfiles（untracked symlink） | 端末固有 | Claude Code ラッパー（端末固有の secrets 使用） |
| `codex.fish` | dotfiles（untracked symlink） | 端末固有 | Codex CLI ラッパー（端末固有の secrets 使用） |
| `g_create_pr.fish` | dotfiles（untracked symlink） | 端末固有 | GitHub PR 作成（社内ツール依存） |
| `prtrack.fish` | dotfiles（untracked symlink） | 端末固有 | PR Track CLI（端末固有の secrets 使用） |

### 問題の根本原因: ディレクトリ全体の symlink

`check-symlinks.sh` が期待する状態:

```
~/.config/fish  →  dotfiles/configs/fish/   （ディレクトリごと symlink）
```

この設計のため、端末固有リポジトリの setup script が `~/.config/fish/functions/` に symlink を作成すると、その実体が `dotfiles/configs/fish/functions/` 内に書き込まれる。dotfiles リポジトリに管理対象外の untracked files が恒常的に現れる。

```
端末固有リポジトリの setup:
  ln -s <端末固有リポジトリ>/.../claude.fish  ~/.config/fish/functions/claude.fish
                                               ↓（~/.config/fish は dotfiles/configs/fish への symlink）
  実体:  dotfiles/configs/fish/functions/claude.fish  ← git status に ?? として現れる
```

### 課題のスコープ

fish 固有の問題に見えるが、本質は **「端末固有の設定・スクリプトを dotfiles に含めない」** というポリシーの欠如である。

- fish functions の symlink 混入は現在の顕在症状
- 今後 claude scripts や他のコンポーネントにも同様の問題が起きる可能性がある

## 設計案

**方針: ディレクトリ全体 symlink → ファイル単位 symlink への移行**

`~/.config/fish` のディレクトリ全体 symlink をやめ、各ファイルを個別に symlink する方式に切り替える。`~/.config/fish/functions/` は実ディレクトリとし、各 `.fish` ファイルがそれぞれのリポジトリへ個別に symlink する。

```
# 共通関数（dotfiles 管理）
~/.config/fish/functions/tm.fish
  → dotfiles/configs/fish/functions/tm.fish

# 端末固有関数（端末固有リポジトリ管理）
~/.config/fish/functions/claude.fish
  → <端末固有リポジトリ>/configs/fish/functions/claude.fish
```

### 各コンポーネントの対応

| コンポーネント | 現状 | 変更後 |
|--------------|------|--------|
| `~/.config/fish/` | dotfiles/configs/fish/ への dir symlink | 実ディレクトリ |
| `~/.config/fish/config.fish` | dir symlink 経由 | dotfiles への file symlink |
| `~/.config/fish/conf.d/` | dir symlink 経由 | 実ディレクトリ（各ファイルを個別 symlink） |
| `~/.config/fish/functions/` | dir symlink 経由 | 実ディレクトリ（各ファイルを個別 symlink） |

### 端末固有関数の移管先

以下の 8 関数を dotfiles から削除し、端末固有リポジトリの `configs/fish/functions/` に正式配置する（現在 untracked symlink として存在しているものを確定させる）：

- `a_eks_kubeconfig.fish`
- `a_profile.fish`
- `a_saml2aws.fish`
- `a_sso_login.fish`
- `claude.fish`
- `codex.fish`
- `g_create_pr.fish`
- `prtrack.fish`

### ロードの仕組み

`l_sandbox.fish` は「端末固有リポジトリの `local.fish` を source するだけのブリッジ」であり、ファイル単位 symlink 方式では不要になる。

fish は `~/.config/fish/conf.d/` 内の `.fish` ファイルをすべて自動で source する。端末固有リポジトリの setup script が `local.fish` を直接 symlink すれば、`l_sandbox.fish` は削除できる。

```
# 変更前（ブリッジ経由）
dotfiles/conf.d/l_sandbox.fish  →  source <端末固有リポジトリ>/conf.d/local.fish

# 変更後（直接 symlink）
~/.config/fish/conf.d/local.fish  →  <端末固有リポジトリ>/configs/fish/conf.d/local.fish
```

同様に、端末固有リポジトリ側に setup script を用意して functions も個別 symlink する:

```bash
# 端末固有関数の symlink
for f in <端末固有リポジトリ>/configs/fish/functions/*.fish; do
    ln -sf "$(realpath $f)" ~/.config/fish/functions/$(basename $f)
done

# conf.d の symlink
ln -sf "<端末固有リポジトリ>/configs/fish/conf.d/local.fish" ~/.config/fish/conf.d/local.fish
ln -sf "<端末固有リポジトリ>/configs/fish/conf.d/tmw_direct_repos.conf" ~/.config/fish/conf.d/tmw_direct_repos.conf
```

### 変更が必要なファイル

| ファイル | 変更内容 |
|---------|---------|
| `dotfiles/configs/claude/scripts/check-symlinks.sh` | `fish` のチェックをディレクトリ symlink → ファイル単位 symlink に変更 |
| `dotfiles/configs/fish/conf.d/l_sandbox.fish` | 削除（直接 symlink 方式に置き換えるため不要） |
| 端末固有リポジトリ | setup script 追加（`local.fish` / functions / conf ファイルの個別 symlink 作成） |
| `dotfiles` | setup script 追加（共通 functions の個別 symlink 作成） |

### 検討中の事項

- `completions/` も同様にファイル単位 symlink にするか、ディレクトリ symlink のままにするか
- dotfiles と端末固有リポジトリの setup script をどのリポジトリが管理・実行するか（初回セットアップ時の順序）

## 決定

（未定）

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-012 セクション）
