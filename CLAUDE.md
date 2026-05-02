# Claude Code 設定

> 開発プロセスは [docs/development.md](docs/development.md)、コンポーネント・ツール一覧は [docs/reference.md](docs/reference.md) を参照。

## ルール

- 実装前に受け入れ条件を `docs/issues.md` に書くこと
- ファイル検索結果から選択する際は、現在の worktree パス内のファイルを選択する
- グローバル `~/.claude/` は参照専用。編集が必要な場合は `$PWD/configs/claude/` を編集（プロジェクトローカルの `$PWD/.claude/` は通常通り参照・編集可）

## 実装完了時の自動コミット

コード実装タスクが完了した際は `git commit` まで自動で行う。git remote が設定されている場合は `git push` も自動で行う（PR 作成は不要）。master ブランチに直接コミットしてよい。
