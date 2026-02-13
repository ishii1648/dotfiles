# Claude Code 設定

## ディレクトリ構成

`~/.claude/` 内の以下のディレクトリは、このリポジトリへのシンボリックリンクです：

| シンボリックリンク | 実態 |
|-------------------|------|
| `~/.claude/commands` | `configs/claude/commands` |
| `~/.claude/skills` | `configs/claude/skills` |
| `~/.claude/agents` | `configs/claude/agents` |

編集する際は `configs/claude/` 配下のファイルを編集してください。

## Worktree作業時のルール

このリポジトリはgit worktreeを使用しています。worktreeで作業中にメインリポジトリのファイルを誤って操作しないよう、以下のルールに従ってください。

### 全操作共通ルール

- **全ての操作（Read/Glob/Grep/Edit/Write）は常に`$PWD`配下のパスを使用**
- メインリポジトリの絶対パス（`$HOME/ghq/github.com/<user>/<repo>/`）は使用禁止
- ファイル検索結果から選択する際は、現在のworktreeパス内のファイルを選択する
- `~/.claude/`配下は参照専用。編集が必要な場合は`$PWD/configs/claude/`を編集

### 読み取り・探索操作の注意

- **Read**: `file_path`は必ず`$PWD`配下を指定
- **Glob/Grep**: `path`を省略するとCWD（worktree）が対象になる。明示的に指定する場合は`$PWD`配下を使用

### パス確認

- メインリポジトリ: `$HOME/ghq/github.com/<user>/<repo>`
- worktree配置先: `$HOME/ghq/github.com/<user>/<repo>@<branch-name>`
- 編集対象は常に`$PWD`配下であることを確認してから編集する

## 実装完了時の自動PR作成

コード実装タスクが完了した際は、以下の条件を**すべて**満たす場合に `git-ship` skill を自動実行してDraft PRを作成する：

### 実行条件
1. 未コミットの変更がある（git status で変更が検出される）
2. feature/fix/docs/chore ブランチ上にいる（main/master ではない）
3. 実装タスクである（調査、質問回答、コードレビューのみの場合は対象外）

### 対象外のケース
- 質問への回答のみ
- コードベースの調査・探索のみ
- 既存コードの説明のみ
- PRレビューやコメント対応のみ
- 操作対象は常に`$PWD`配下であることを確認してから実行する
