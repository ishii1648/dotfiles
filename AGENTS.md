# エージェント共通設定

> 開発プロセスは [docs/development.md](docs/development.md)、コンポーネント・ツール一覧は [docs/reference.md](docs/reference.md) を参照。

## ルール

- 実装前に受け入れ条件を `docs/issues.md` に書くこと
- ファイル検索結果から選択する際は、現在の worktree パス内のファイルを選択する
- グローバル `~/.codex/`・`~/.claude/` の dotfiles 管理ファイルは、`$PWD/configs/codex/`・`$PWD/configs/claude/` の実体を編集する。プロジェクトローカルの `.codex/`・`.claude/` は通常どおり参照・編集できる。

## 実装完了時の自動コミット

コード実装タスクが完了した際は `git commit` まで自動で行う。git remote が設定されている場合は `git push` も自動で行う（PR 作成は不要）。デフォルトブランチ（`main`）に直接コミットしてよい。

自動コミット時は **`git add -A` を使わずパスを明示する**（他セッションの編集中ファイルを巻き込まないため）。
