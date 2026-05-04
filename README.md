# dotfiles

開発環境の共通設定を管理するリポジトリ。端末固有の設定は含まない。

## セットアップ

### 前提条件

- **macOS**: [Homebrew](https://brew.sh) と Python3 (PyYAML) がインストールされていること。`setup.sh` が fish / tmux / neovim / jq / aqua / docker / colima / docker-compose を自動インストールする（colima は `--profile linux` 以外で対象。Docker サンドボックス用）。
- **Linux**: 事前にパッケージのインストールが必要。Docker テスト用の `tests/Dockerfile` を参照。

### 事前設定（初回のみ）

```bash
# 1. SSH 鍵ペアを生成（認証用・署名用）
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github -C "your_email@example.com"
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github_sign -C "your_email@example.com"

# 2. GitHub に pub 鍵を登録
#    - Authentication key: ~/.ssh/id_ed25519_github.pub
#    - Signing key:        ~/.ssh/id_ed25519_github_sign.pub
#    https://github.com/settings/keys

# 3. overlay manifest にユーザー情報と鍵パスを設定
cp scripts/setup-manifest.local.yml.example scripts/setup-manifest.local.yml
# エディタで user_name / user_email / 鍵パスを自分の環境に合わせて編集
```

### 実行

```bash
bash scripts/setup.sh
```

マニフェスト（`scripts/setup-manifest.yml`）に定義された全コンポーネントのセットアップが一発で完了する。Git ユーザー情報・SSH 鍵の設定（`~/.ssh/config` 追加・`user.signingkey` 設定・`ssh-add` 登録）も含まれる。

### オプション

```bash
# 状態チェックのみ（変更しない）
bash scripts/setup.sh --dry-run

# リモート環境用セットアップ（ghostty/codex を除外）
bash scripts/setup.sh --profile remote

# Linux 環境用セットアップ（ghostty/codex を除外、Docker e2e テストで使用）
bash scripts/setup.sh --profile linux

# 端末固有設定（端末固有リポジトリの setup script を実行）
bash <端末固有リポジトリ>/setup.sh
```

プロファイル別のコンポーネントは `scripts/setup-manifest.yml` の `profiles:` を参照。

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

# 2. remote プロファイルでセットアップ（fish, nvim, tmux, claude, aqua, git, vim + tmux テンプレートコピー）
bash scripts/setup.sh --profile remote
```

### tmux ネスト対応

ローカル PC からリモートの tmux にネスト接続する際、`tms` 関数を使うとパススルーモードが自動で切り替わる。

```fish
tms lab           # SSH先の tmux セッション "work" に接続（パススルー自動ON）
tms lab dev       # セッション名を指定
```

F12 キーで手動トグルも可能（`~/.tmux.local.conf` に `configs/tmux/tmux.local.conf.example` の F12 設定をコピーしておく）。

## Claude Code / Codex CLI

`configs/claude/` 配下の設定・skill・statusline は `~/.claude/` に symlink される。skill は `dispatch` / `orchestrate` / `session-log` / `codex-sync` などを同梱しており、`codex` プロファイルでは Codex CLI 側 (`~/.codex/skills/`) にも同じ skill 実体が symlink される。

並列開発の運用フロー（dispatch/orchestrate ランチャー、tmux-sidebar 連携、worktree 管理）は [docs/reference.md](docs/reference.md) を参照。

### Docker サンドボックス

Docker コンテナ内で Claude Code を `--dangerously-skip-permissions` 付きで安全に自律実行する。詳細は [docs/claude-docker-sandbox.md](docs/claude-docker-sandbox.md) を参照。

## 端末固有設定

端末固有の設定（社内ツール・AWS 認証・端末固有 keybind・Git ユーザー情報等）は端末固有リポジトリで管理する。dotfiles には含めない。

| ツール | 配置先 | 初期配布元 |
|--------|--------|---------|
| Git (full/remote) | `~/.gitconfig` | `configs/git/gitconfig.macos` を `copies: if_missing` で配布 |
| Git (linux) | `~/.gitconfig` | `configs/git/gitconfig` を `copies: if_missing` で配布 |
| Claude Code | `~/.claude/settings.json` | `configs/claude/settings.json` を `copies: if_missing` で配布。`hooks` / `statusLine` / `env` は setup 時に自動同期 |
| Ghostty | `~/.config/ghostty/local.conf` | `configs/ghostty/local.conf.example`（手動コピー） |
| tmux (remote) | `~/.tmux.local.conf` | `configs/tmux/tmux.remote.conf.example` を `copies: if_missing` で配布 |
| tmux (full) | `~/.tmux.local.conf` | `configs/tmux/tmux.local.conf.example`（手動コピー、F12 トグル等） |
| Neovim | `configs/nvim/lua/local.lua` | `configs/nvim/lua/local.lua.example`（手動コピー） |

`setup.sh --dry-run` で validate チェックが実行され、共通設定のキーが `~/.gitconfig` や `~/.claude/settings.json` に存在するか検証される（WARN 出力のみ、失敗しない）。
