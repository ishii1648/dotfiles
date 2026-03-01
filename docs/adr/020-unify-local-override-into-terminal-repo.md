# ADR-020: ローカルオーバーライドを端末固有リポジトリに統合する

## ステータス

部分廃止（ADR-027 で一部変更）

> ADR-027 により変更された決定: `.gitconfig.local` を端末固有リポで管理する方針 → copy + validate 方式により `.gitconfig.local` 自体が不要になった。
> 引き続き有効な決定: `local.lua` 等その他のローカルオーバーライドファイルの端末固有リポ統合方針。

## コンテキスト

dotfiles では端末ごとに異なる設定を管理する仕組みが2系統に分かれている。

1. **ローカルオーバーライド**: dotfiles リポジトリ内で `.gitignore` した手動作成ファイル（`.gitconfig.local`、`configs/nvim/lua/local.lua`）
2. **端末固有リポジトリ**: 別リポジトリ（`terminal-repo.local` で定義）の `setup.sh` が symlink するファイル（`tmw_direct_repos.conf`、`~/.tmux.local.conf`、`~/.config/ghostty/local.conf`）

どちらも「端末ごとに異なる設定」という同じ性質を持つが、管理場所と手順が分かれており、README でも別セクションで説明している。ADR-012 で端末固有設定の分離方針を定めたが、ローカルオーバーライドとの使い分け基準は明文化されていない。

### 現状の問題

- 新しい端末をセットアップする際に、端末固有リポジトリの `setup.sh` 実行 **と** `.gitconfig.local` 等の手動作成の2手順が必要
- どの設定がどちらの仕組みで管理されているか README を読まないとわからない
- `.gitconfig.local` と `local.lua` は `.example` テンプレートからコピーして編集する手順だが、端末固有リポジトリに含めてしまえば `setup.sh` 一発で配置できる

## 設計案

ローカルオーバーライドファイルをすべて端末固有リポジトリで管理する方針に統一する。

### 統合対象

| ファイル | 現在の管理 | 統合後の管理 |
|---------|-----------|-------------|
| `~/.gitconfig.local` | dotfiles 内 gitignore + 手動作成 | 端末固有リポジトリ → symlink |
| `configs/nvim/lua/local.lua` | dotfiles 内 gitignore + 手動作成 | 端末固有リポジトリ → symlink |
| `~/.config/fish/conf.d/tmw_direct_repos.conf` | 端末固有リポジトリ | 変更なし |
| `~/.tmux.local.conf` | 端末固有リポジトリ | 変更なし |
| `~/.config/ghostty/local.conf` | 端末固有リポジトリ | 変更なし |

### README の変更

「ローカルオーバーライド」セクションを廃止し、「端末固有設定」セクションに統合する。全ファイルを一覧で表示する。

### .example テンプレートの扱い

`.gitconfig.local.example` と `configs/nvim/lua/local.lua.example` は dotfiles に残す。端末固有リポジトリを持たない環境（例: リモートサーバー）でも手動作成の参考にできるようにするため。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `README.md` | dotfiles | 「ローカルオーバーライド」セクションを廃止し「端末固有設定」に統合 |
| `CLAUDE.md` | dotfiles | 端末固有リポジトリの説明を更新 |
| 端末固有リポジトリの `setup.sh` | 端末固有リポジトリ | `.gitconfig.local` と `local.lua` の symlink 作成を追加 |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-020 セクション）
