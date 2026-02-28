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

`~/.claude/settings.json` に以下の hooks 設定を追加:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/scripts/sync-settings-local.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/scripts/open-plan-pane.sh"
          }
        ]
      }
    ]
  }
}
```

| Hook | 説明 |
|------|------|
| `Stop` | Claudeの応答完了時にworktreeの`.claude/settings.local.json`を親リポジトリに同期する |
| `PostToolUse` (ExitPlanMode) | plan mode 完了時に tmux の右側 pane を開いて最新の plan ファイルを nvim で表示する |
