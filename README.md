# What is this ?
PCで利用する設定ファイル（.vimrc、.zshrc等）を一括管理するリポジトリです。

## 管理方法
リポジトリ管理用ディレクトリで設定ファイルを作成し、必要なディレクトリへシンボリックリンクを張る

```
（例）
ln -s ~/workspace/dotfiles/.zshrc ~/.zshrc
```

※リポジトリ管理用ディレクトリへシンボリックリンクを張ると、ファイル内容をGit管理できないためリポジトリ管理用ディレクトリからリンクを貼るようにする

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
