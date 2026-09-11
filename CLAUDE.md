@AGENTS.md

# Claude Code 固有の設定

- `configs/claude/settings.json` は symlink ではない。編集したら `configs/claude/setup.sh` を実行するまで `~/.claude/settings.json` に反映されない（ADR-015 / ADR-041。nix が張らない理由は `nix/symlinks.nix` のコメント参照）

## worktree 分離中の自動コミット

worktree 分離中（グローバル CLAUDE.md「並列セッションの衝突回避」参照）はデフォルトブランチへの直コミットにならないため、その worktree のブランチにコミット・push したうえで、**確認せず `main` への merge と push まで自動で行う**。worktree 分離ガードがメイン worktree への git 操作をブロックするため、タスク完了後に `ExitWorktree`（keep）でメイン worktree に戻ってから `git merge <branch> && git push` を実行する。conflict した場合のみ中断してユーザに確認する。
