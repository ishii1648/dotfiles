# dotfiles

開発環境の共通設定を管理するリポジトリ。端末固有の設定は含まない。

## セットアップ

```bash
# 1. fish 共通設定（ファイル単位 symlink を作成）
bash configs/fish/setup.sh

# 2. symlink の状態確認
bash configs/claude/scripts/check-symlinks.sh

# 3. 端末固有設定（端末固有リポジトリの setup script を実行）
bash <端末固有リポジトリ>/setup.sh
```

## ローカルオーバーライド

端末・環境ごとに異なる設定は git 管理外の local ファイルで上書きする。
`.example` テンプレートを参考に作成する。

| ツール | ローカルファイル | テンプレート |
|--------|-----------------|-------------|
| Git | `~/.gitconfig.local` | `.gitconfig.local.example` |
| Fish (tmw) | `~/.config/fish/conf.d/tmw_direct_repos.conf` | `configs/fish/conf.d/tmw_direct_repos.conf.example` |
| Ghostty | `~/.config/ghostty/local.conf` | — |
| tmux | `~/.tmux.local.conf` | `configs/tmux/tmux.local.conf.example` |
| Neovim | `configs/nvim/lua/local.lua` | `configs/nvim/lua/local.lua.example` |

## 端末固有設定

端末固有の設定（社内ツール・AWS 認証・端末固有 keybind 等）は端末固有リポジトリで管理する。dotfiles には含めない。端末固有リポジトリの `setup.sh` を実行すると必要な symlink が作成される。

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
