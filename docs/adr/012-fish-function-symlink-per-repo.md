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
| `l_sandbox.fish` | dotfiles | 共通（ブリッジ） | sandbox-ishii1648 の `local.fish` を source する |
| `local.fish` | sandbox-ishii1648 | 端末固有 | AWS 設定・SSL 証明書・Company secrets・GPG 初期化 |
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
| `claude.fish` | dotfiles（untracked symlink） | 端末固有 | Claude Code ラッパー（fdev secrets 使用） |
| `codex.fish` | dotfiles（untracked symlink） | 端末固有 | Codex CLI ラッパー（fdev secrets 使用） |
| `g_create_pr.fish` | dotfiles（untracked symlink） | 端末固有 | GitHub PR 作成（社内ツール goose 使用） |
| `prtrack.fish` | dotfiles（untracked symlink） | 端末固有 | PR Track CLI（fdev secrets 使用） |

### 問題の根本原因: ディレクトリ全体の symlink

`check-symlinks.sh` が期待する状態:

```
~/.config/fish  →  dotfiles/configs/fish/   （ディレクトリごと symlink）
```

この設計のため、sandbox-ishii1648 の setup script が `~/.config/fish/functions/` に symlink を作成すると、その実体が `dotfiles/configs/fish/functions/` 内に書き込まれる。dotfiles リポジトリに管理対象外の untracked files が恒常的に現れる。

```
sandbox setup:
  ln -s sandbox-ishii1648/.../claude.fish  ~/.config/fish/functions/claude.fish
                                            ↓（~/.config/fish は dotfiles/configs/fish への symlink）
  実体:  dotfiles/configs/fish/functions/claude.fish  ← git status に ?? として現れる
```

### 課題のスコープ

fish 固有の問題に見えるが、本質は **「端末固有の設定・スクリプトを dotfiles に含めない」** というポリシーの欠如である。

- fish functions の symlink 混入は現在の顕在症状
- 今後 claude scripts や他のコンポーネントにも同様の問題が起きる可能性がある

## 決定

（未定）

### 設計案

**方針: ディレクトリ全体 symlink → ファイル単位 symlink への移行**

`~/.config/fish` のディレクトリ全体 symlink をやめ、各ファイルを個別に symlink する方式に切り替える。`~/.config/fish/functions/` は実ディレクトリとし、各 `.fish` ファイルがそれぞれのリポジトリへ個別に symlink する。

```
# 共通関数（dotfiles 管理）
~/.config/fish/functions/tm.fish
  → dotfiles/configs/fish/functions/tm.fish

# 端末固有関数（sandbox-ishii1648 管理）
~/.config/fish/functions/claude.fish
  → sandbox-ishii1648/configs/fish/functions/claude.fish
```

#### 各コンポーネントの対応

| コンポーネント | 現状 | 変更後 |
|--------------|------|--------|
| `~/.config/fish/` | dotfiles/configs/fish/ への dir symlink | 実ディレクトリ |
| `~/.config/fish/config.fish` | dir symlink 経由 | dotfiles への file symlink |
| `~/.config/fish/conf.d/` | dir symlink 経由 | 実ディレクトリ（各ファイルを個別 symlink） |
| `~/.config/fish/functions/` | dir symlink 経由 | 実ディレクトリ（各ファイルを個別 symlink） |

#### 端末固有関数の移管先

以下の 8 関数を dotfiles から削除し、sandbox-ishii1648/configs/fish/functions/ に正式配置する（現在 untracked symlink として存在しているものを確定させる）：

- `a_eks_kubeconfig.fish`
- `a_profile.fish`
- `a_saml2aws.fish`
- `a_sso_login.fish`
- `claude.fish`
- `codex.fish`
- `g_create_pr.fish`
- `prtrack.fish`

#### ロードの仕組み（conf.d を経由しない方式）

`l_sandbox.fish` → `local.fish` で `fish_function_path` に追加する現在の方式と、ファイル単位 symlink 方式は並存できる。ただし二重管理を避けるためどちらか一方に統一する。

**推奨: ファイル単位 symlink 方式に統一**（`fish_function_path` 追加は廃止）

sandbox-ishii1648 側に setup script（または Makefile）を用意し、以下を実行する:

```bash
for f in sandbox-ishii1648/configs/fish/functions/*.fish; do
    ln -sf "$(realpath $f)" ~/.config/fish/functions/$(basename $f)
done
```

dotfiles 側の setup script（check-symlinks.sh 等）でも共通 functions を個別 symlink する。

#### 変更が必要なファイル

| ファイル | 変更内容 |
|---------|---------|
| `dotfiles/configs/claude/scripts/check-symlinks.sh` | `fish` のチェックをディレクトリ symlink → ファイル単位 symlink に変更 |
| `sandbox-ishii1648` | setup script 追加（端末固有 functions の個別 symlink 作成） |
| `dotfiles` | setup script 追加（共通 functions の個別 symlink 作成） |
| `dotfiles/configs/fish/conf.d/l_sandbox.fish` | `fish_function_path` 追加を廃止する場合は削除または簡略化 |

### 検討中の事項

- `conf.d/` と `completions/` も同様にファイル単位 symlink にするか、ディレクトリ symlink のままにするか
- dotfiles と sandbox の setup script をどのリポジトリが管理・実行するか（初回セットアップ時の順序）
- `fish_function_path` 方式（`l_sandbox.fish` → `local.fish` 経由）との共存・廃止タイミング

## 結果

（未定）
