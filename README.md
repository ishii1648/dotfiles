# dotfiles

開発環境の設定ファイルを管理するリポジトリ。

## セットアップ

リポジトリからホームディレクトリへシンボリックリンクを作成する。

```bash
# シンボリックリンクの状態チェック
bash configs/claude/scripts/check-symlinks.sh
```

## シンボリックリンク構成

### ホームディレクトリ直下

| シンボリックリンク | ターゲット |
|-------------------|-----------|
| `~/.gitconfig` | `.gitconfig` |
| `~/.tmux.conf` | `configs/tmux/tmux.conf` |

### ~/.config/ 配下

| シンボリックリンク | ターゲット |
|-------------------|-----------|
| `~/.config/fish` | `configs/fish/` |
| `~/.config/nvim` | `configs/nvim/` |
| `~/.config/ghostty/config` | `configs/ghostty/config` |

### ~/.claude/ 配下

| シンボリックリンク | ターゲット |
|-------------------|-----------|
| `~/.claude/CLAUDE.md` | `configs/claude/CLAUDE.md` |
| `~/.claude/agents` | `configs/claude/agents/` |
| `~/.claude/commands` | `configs/claude/commands/` |
| `~/.claude/scripts` | `configs/claude/scripts/` |
| `~/.claude/skills` | `configs/claude/skills/` |
| `~/.claude/statusline.js` | `configs/claude/statusline.js` |

## ローカルオーバーライド

環境固有の設定（メールアドレス、組織名等）は git 管理外の local ファイルで上書きする。
各ツールに `.example` テンプレートを用意している。

| ツール | ローカルファイル | テンプレート |
|--------|-----------------|-------------|
| Git | `~/.gitconfig.local` | `.gitconfig.local.example` |
| Fish | `configs/fish/conf.d/local.fish` | — |
| Fish (tmw) | `configs/fish/conf.d/tmw_direct_repos.conf` | `configs/fish/conf.d/tmw_direct_repos.conf.example` |
| Ghostty | `configs/ghostty/local.conf` | `configs/ghostty/local.conf.example` |
| tmux | `~/.tmux.local.conf` | `configs/tmux/tmux.local.conf.example` |
| Neovim | `configs/nvim/lua/local.lua` | `configs/nvim/lua/local.lua.example` |

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
