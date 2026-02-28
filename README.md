# dotfiles

開発環境の設定ファイルを管理するリポジトリ。端末固有の設定は含まない。

## セットアップ

### 1. fish（共通設定）

ディレクトリ symlink ではなくファイル単位で symlink を作成する。

```bash
bash configs/fish/setup.sh
```

### 2. その他の symlink

```bash
# symlink の状態チェック
bash configs/claude/scripts/check-symlinks.sh
```

### 3. 端末固有設定

端末固有リポジトリの setup script を実行する（[sandbox-ishii1648](https://github.com/C-FO/sandbox-ishii1648) 参照）。

```bash
bash <sandbox>/setup.sh
```

## シンボリックリンク構成

### ホームディレクトリ直下

| シンボリックリンク | ターゲット |
|-------------------|-----------|
| `~/.gitconfig` | `.gitconfig` |
| `~/.tmux.conf` | `configs/tmux/tmux.conf` |

### ~/.config/fish/ 配下（ファイル単位）

`~/.config/fish/` は実ディレクトリ。`configs/fish/setup.sh` で個別 symlink を作成する。

| シンボリックリンク | ターゲット |
|-------------------|-----------|
| `~/.config/fish/config.fish` | `configs/fish/config.fish` |
| `~/.config/fish/conf.d/aliases.fish` | `configs/fish/conf.d/aliases.fish` |
| `~/.config/fish/conf.d/completions.fish` | `configs/fish/conf.d/completions.fish` |
| `~/.config/fish/conf.d/env.fish` | `configs/fish/conf.d/env.fish` |
| `~/.config/fish/conf.d/fzf*.fish` | `configs/fish/conf.d/fzf*.fish` |
| `~/.config/fish/conf.d/path.fish` | `configs/fish/conf.d/path.fish` |
| `~/.config/fish/completions/` | `configs/fish/completions/`（dir symlink） |
| `~/.config/fish/functions/*.fish` | `configs/fish/functions/*.fish`（tracked のみ） |

### ~/.config/ 配下（その他）

| シンボリックリンク | ターゲット |
|-------------------|-----------|
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
| Fish (tmw) | `~/.config/fish/conf.d/tmw_direct_repos.conf` | `configs/fish/conf.d/tmw_direct_repos.conf.example` |
| Ghostty | `~/.config/ghostty/local.conf` | — |
| tmux | `~/.tmux.local.conf` | `configs/tmux/tmux.local.conf.example` |
| Neovim | `configs/nvim/lua/local.lua` | `configs/nvim/lua/local.lua.example` |

## 端末固有設定（sandbox-ishii1648）

端末固有の設定は [sandbox-ishii1648](https://github.com/C-FO/sandbox-ishii1648) で管理する。dotfiles には含めない。

| 種別 | 場所 |
|------|------|
| 端末固有 fish functions | `sandbox-ishii1648/configs/fish/functions/` |
| 端末固有 fish conf.d | `sandbox-ishii1648/configs/fish/conf.d/local.fish` |
| tmux 端末固有 keybind | `sandbox-ishii1648/configs/tmux/tmux.local.conf` → `~/.tmux.local.conf` |
| Ghostty 端末固有 keybind | `sandbox-ishii1648/configs/ghostty/local.conf` → `~/.config/ghostty/local.conf` |

`sandbox-ishii1648/setup.sh` を実行すると上記すべての symlink が作成される。

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
