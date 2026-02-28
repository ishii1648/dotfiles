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

## 端末固有設定

端末固有の設定（社内ツール・AWS 認証・端末固有 keybind・Git ユーザー情報等）は端末固有リポジトリで管理する。dotfiles には含めない。

どの端末固有リポジトリを使うかは `terminal-repo.local` に定義する（`terminal-repo.local.example` を参照）。端末固有リポジトリの `setup.sh` を実行すると以下が配置される。端末固有リポジトリを持たない環境では `.example` テンプレートから手動作成する。

| ツール | 配置先 | テンプレート（dotfiles 側） |
|--------|--------|---------------------------|
| Git | `~/.gitconfig.local` | `.gitconfig.local.example` |
| Fish (tmw) | `~/.config/fish/conf.d/tmw_direct_repos.conf` | `configs/fish/conf.d/tmw_direct_repos.conf.example` |
| Ghostty | `~/.config/ghostty/local.conf` | `configs/ghostty/local.conf.example` |
| tmux | `~/.tmux.local.conf` | `configs/tmux/tmux.local.conf.example` |
| Neovim | `configs/nvim/lua/local.lua` | `configs/nvim/lua/local.lua.example` |

## Claude Code Hooks 設定

`~/.claude/settings.json` に手動で設定する。

| Hook | スクリプト | 説明 |
|------|-----------|------|
| `SessionStart` | `claude-pane-state.sh idle` | ペイン状態を idle に設定 |
| `SessionStart` | `session-index.sh` | セッションインデックスを記録 |
| `UserPromptSubmit` | `claude-pane-state.sh running` | ペイン状態を running に設定 |
| `Notification` (permission_prompt) | `claude-notify.sh` + `claude-pane-state.sh permission` | 権限要求を通知 |
| `Notification` (elicitation_dialog) | `claude-notify.sh` + `claude-pane-state.sh ask` | 質問ダイアログを通知 |
| `Stop` | `claude-pane-state.sh idle` | ペイン状態を idle に戻す |
| `Stop` | `session-index-stop.sh` | セッション終了を記録 |
| `SessionEnd` | `claude-pane-state.sh end` | ペイン状態を end に設定 |
| `PreCompact` | prompt | コンテキスト圧縮前に handover skill を実行するよう指示 |
| `PreToolUse` (Bash) | `redirect-to-tools.py` | 専用ツールへのリダイレクトを促す |
| `PostToolUse` | `claude-pane-state.sh running post` | ツール使用後に running 状態を維持 |
| `PostToolUse` (Bash) | `session-index-post-tool.sh` | ツール出力を記録 |
