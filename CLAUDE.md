# Claude Code 設定

## ディレクトリ構成

`~/.claude/` 内の以下のディレクトリは、このリポジトリへのシンボリックリンクです：

| シンボリックリンク | 実態 |
|-------------------|------|
| `~/.claude/hooks` | `.config/claude/hooks` |
| `~/.claude/commands` | `.config/claude/commands` |
| `~/.claude/skills` | `.config/claude/skills` |

編集する際は `.config/claude/` 配下のファイルを編集してください。

## Worktree作業時のルール

このリポジトリはgit worktreeを使用しています。worktreeで作業中にメインリポジトリのファイルを誤って編集しないよう、以下のルールに従ってください。

- ファイル編集は**常に現在の作業ディレクトリ（$PWD）を基準**にする
- 編集時は`$PWD`配下のパスを使用し、メインリポジトリの絶対パスは使用しない
- ファイル検索結果から選択する際は、現在のworktreeパス内のファイルを選択する
- `~/.claude/`配下は参照専用。編集が必要な場合は`$PWD/.config/claude/`を編集

### パス確認

- メインリポジトリ: `/Users/sho-ishii/ghq/github.com/ishii1648/dotfiles`
- worktree配置先: `/Users/sho-ishii/ghq/github.com/ishii1648/dotfiles/.worktrees/<branch-name>`
- 編集対象は常に`$PWD`配下であることを確認してから編集する
