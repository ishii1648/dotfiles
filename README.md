# What is this ?
PCで利用する設定ファイル（.vimrc、.zshrc等）を一括管理するリポジトリです。

## 管理方法
リポジトリ管理用ディレクトリで設定ファイルを作成し、必要なディレクトリへシンボリックリンクを張る

```
（例）
ln -s ~/workspace/dotfiles/.zshrc ~/.zshrc
```

※リポジトリ管理用ディレクトリへシンボリックリンクを張ると、ファイル内容をGit管理できないためリポジトリ管理用ディレクトリからリンクを貼るようにする

## シンボリックリンク構成

### ~/.config/ 配下

| シンボリックリンク | ターゲット |
|-------------------|-----------|
| `~/.config/fish` | `.config/fish/` |
| `~/.config/nvim` | `.config/nvim/` |
| `~/.config/ghostty/config` | `.config/ghostty/config` |

### ~/.claude/ 配下

`.config/claude/` 配下の各エントリに対応するシンボリックリンクを作成:

| シンボリックリンク | ターゲット |
|-------------------|-----------|
| `~/.claude/agents` | `.config/claude/agents/` |
| `~/.claude/CLAUDE.md` | `.config/claude/CLAUDE.md` |
| `~/.claude/commands` | `.config/claude/commands/` |
| `~/.claude/scripts` | `.config/claude/scripts/` |
| `~/.claude/skills` | `.config/claude/skills/` |
| `~/.claude/statusline.js` | `.config/claude/statusline.js` |

### シンボリックリンクのチェック

以下のスクリプトで全シンボリックリンクの状態を確認できます:

```bash
bash .config/claude/scripts/check-symlinks.sh
```

## Claude Code Hooks 設定

`~/.claude/settings.json` に以下のhooks設定を追加:

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
    ]
  }
}
```

### Hooks の説明

| Hook | 説明 |
|------|------|
| `Stop` | Claudeの応答完了時にworktreeの`.claude/settings.local.json`を親リポジトリに同期する |

### スクリプトのセットアップ

```bash
ln -s ~/workspace/dotfiles/.config/claude/scripts ~/.claude/scripts
```
