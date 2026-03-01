# dotfiles

開発環境の共通設定を管理するリポジトリ。端末固有の設定は含まない。

## セットアップ

### 前提条件

- **macOS**: [Homebrew](https://brew.sh) がインストールされていること。`setup.sh` が fish / tmux / neovim / jq / aqua を自動インストールする。
- **Linux**: 事前にパッケージのインストールが必要。Docker テスト用の `tests/Dockerfile` を参照。

### 実行

```bash
bash scripts/setup.sh
```

マニフェスト（`scripts/setup-manifest.yml`）に定義された全コンポーネントのセットアップが一発で完了する。

### オプション

```bash
# 状態チェックのみ（変更しない）
bash scripts/setup.sh --dry-run

# リモート環境用セットアップ（ghostty を除外）
bash scripts/setup.sh --profile remote

# Linux 環境用セットアップ（ghostty を除外、Docker e2e テストで使用）
bash scripts/setup.sh --profile linux

# 端末固有設定（端末固有リポジトリの setup script を実行）
bash <端末固有リポジトリ>/setup.sh
```

### e2e テスト

Docker でクリーンな Linux 環境でのセットアップ完走を検証できる。

```bash
docker build -t dotfiles-e2e -f tests/Dockerfile .
```

GitHub Actions でも push / PR 時に自動実行される。

## SSH 先（リモート環境）でのセットアップ

SSH 先のマシンに dotfiles をデプロイする場合は `remote` プロファイルを使用する。

```bash
# 1. dotfiles を clone
git clone <repo> ~/dotfiles && cd ~/dotfiles

# 2. remote プロファイルでセットアップ（fish, nvim, tmux, claude, aqua + tmux テンプレートコピー）
bash scripts/setup.sh --profile remote
```

### tmux ネスト対応

ローカル PC からリモートの tmux にネスト接続する際、`tms` 関数を使うとパススルーモードが自動で切り替わる。

```fish
tms lab           # SSH先の tmux セッション "work" に接続（パススルー自動ON）
tms lab dev       # セッション名を指定
```

F12 キーで手動トグルも可能（`~/.tmux.local.conf` に `configs/tmux/tmux.local.conf.example` の F12 設定をコピーしておく）。

## GitHub SSH 鍵セットアップ

`setup.sh` は GitHub への SSH 認証・コミット署名の設定を半自動化できる。`scripts/setup-manifest.local.yml` に鍵パスを設定すると、セットアップ時に `~/.ssh/config` 追加・`user.signingkey` 設定・`ssh-add` 登録が実行される。

```bash
cp scripts/setup-manifest.local.yml.example scripts/setup-manifest.local.yml
# エディタで鍵パスを自分の環境に合わせて編集
```

未設定の場合は SSH セットアップを skip する。`--dry-run` で実行予定のコマンドを事前確認できる。

## 端末固有設定

端末固有の設定（社内ツール・AWS 認証・端末固有 keybind・Git ユーザー情報等）は端末固有リポジトリで管理する。dotfiles には含めない。

どの端末固有リポジトリを使うかは `terminal-repo.local` に定義する（`terminal-repo.local.example` を参照）。端末固有リポジトリの `setup.sh` を実行すると以下が配置される。端末固有リポジトリを持たない環境では `.example` テンプレートから手動作成する。

| ツール | 配置先 | 初期配布 |
|--------|--------|---------|
| Git | `~/.gitconfig` | `configs/git/gitconfig` を `copies: if_missing` で配布。端末固有設定は直接編集 |
| Claude Code | `~/.claude/settings.json` | `configs/claude/settings.json` を `copies: if_missing` で配布。端末固有設定は直接編集 |
| Fish (tmw) | `~/.config/fish/conf.d/tmw_direct_repos.conf` | `configs/fish/conf.d/tmw_direct_repos.conf.example` |
| Ghostty | `~/.config/ghostty/local.conf` | `configs/ghostty/local.conf.example` |
| tmux | `~/.tmux.local.conf` | `configs/tmux/tmux.local.conf.example` |
| Neovim | `configs/nvim/lua/local.lua` | `configs/nvim/lua/local.lua.example` |

`setup.sh --dry-run` で validate チェックが実行され、共通設定のキーが `~/.gitconfig` や `~/.claude/settings.json` に存在するか検証される（WARN 出力のみ、失敗しない）。
