# dotfiles

開発環境の共通設定を管理するリポジトリ。端末固有の設定は含まない。

## セットアップ

### 前提条件

- **macOS**: [Homebrew](https://brew.sh) と Python3 (PyYAML) がインストールされていること。`setup.sh` が fish / neovim / jq / aqua / docker / colima / docker-compose を自動インストールする（colima は `--profile linux` 以外で対象。Docker サンドボックス用）。herdr は公式 install script で導入・更新される。
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

### Nix (home-manager) レイヤ — Spike 中

[ADR-084](docs/adr/084-nix-home-manager-package-symlink-layer.md) により、**静的 symlink の配置とパッケージ導入**を home-manager に移行中。Phase A では既存 `setup.sh` を削らずに**共存**させており、Nix を入れなくても `setup.sh` 単独で従来通りセットアップできる。

```bash
# 前提: Nix 本体のインストール（https://nixos.org/download / Determinate Systems installer）

# 初回（home-manager コマンドがまだ無い場合）
nix run home-manager/master -- switch --flake .#sho@darwin -b hmbk

# 2 回目以降（programs.home-manager.enable により ~/.nix-profile/bin に入る）
home-manager switch --flake .#sho@darwin

# symlink 定義が setup.sh 側と一致しているか、Nix と aqua でコマンド名が衝突していないかの検証
python3 nix/check-parity.py
```

> **注意**: Determinate Nix は `~/.nix-profile/bin` を **PATH の最先頭**に置く（aqua は 7 位、Homebrew は 19 位）。`home.packages` に入れたパッケージは aqua と Homebrew を無条件に上書きするため、**aqua が提供するコマンド名と衝突させないこと**。`nix/check-parity.py` が実機で検査する。

責務分担:

| レイヤ | 担当 | 対象 |
|---|---|---|
| Nix (`flake.nix` / `nix/`) | 宣言 | 静的 symlink の配置、OS レベルのパッケージ（Phase A では neovim / jq / ghostty-bin） |
| `scripts/setup.sh` | 手続き | mutable な設定ファイル（`~/.claude/settings.json` の managed-keys sync、`~/.gitconfig` の copies）、外部インストーラ（herdr / codex / aqua）、マシン固有 state（SSH 鍵・`chsh`） |
| aqua (`aqua.yaml`) | 宣言 | バージョンが外部要件で決まる CLI（terraform / kubectl / helm 等） |

Nix が管理する symlink は `mkOutOfStoreSymlink` で dotfiles clone の実体を指すため、`configs/` を編集した内容は `home-manager switch` なしで即反映される。その代わり config 内容の store による再現性は得られない（ADR-084 設計案 A-2）。

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

# 2. remote プロファイルでセットアップ（fish, nvim, claude, herdr, aqua, git, vim）
bash scripts/setup.sh --profile remote
```

### リモート接続

リモートマシンのセッションには `herdr --remote <ssh-target>` でアタッチする（tmux のネスト構成と F12 パススルーは herdr 移行に伴い不要になった、[ADR-076](docs/adr/076-herdr-migration-from-tmux.md) 参照）。

## Claude Code / Codex CLI

`configs/claude/` 配下の設定・skill・statusline は `~/.claude/` に symlink される。skill は `codex-sync` などを同梱しており、`codex` プロファイルでは Codex CLI 側 (`~/.codex/skills/`) にも同じ skill 実体が symlink される（`dispatch` / `orchestrate` / `review-loop` / `session-log` は herdr 移行に伴い廃止、[ADR-076](docs/adr/076-herdr-migration-from-tmux.md) 参照）。

worktree 管理は [docs/reference.md](docs/reference.md) を参照。

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
| Neovim | `configs/nvim/lua/local.lua` | `configs/nvim/lua/local.lua.example`（手動コピー） |

`setup.sh --dry-run` で validate チェックが実行され、共通設定のキーが `~/.gitconfig` や `~/.claude/settings.json` に存在するか検証される（WARN 出力のみ、失敗しない）。
