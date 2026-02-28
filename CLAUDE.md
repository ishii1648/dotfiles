# Claude Code 設定

> 開発プロセスは [docs/development.md](docs/development.md)、コンポーネント・ツール一覧は [docs/reference.md](docs/reference.md) を参照。

## ルール

- 実装前に受け入れ条件を `docs/issues.md` に書くこと
- ファイル検索結果から選択する際は、現在の worktree パス内のファイルを選択する
- `~/.claude/` 配下は参照専用。編集が必要な場合は `$PWD/configs/claude/` を編集

## 端末固有リポジトリ

この端末の端末固有リポジトリは `terminal-repo.local` に定義されている（gitignore 済み）。端末固有の設定やツール、およびすべてのローカルオーバーライドファイル（`.gitconfig.local`、`local.lua` 等）はそちらで管理する。

## 実装完了時の自動コミット

コード実装タスクが完了した際は `git commit` までで完了とする（このリポジトリはリモートが設定されていないため `git push` および PR 作成は不要）。
