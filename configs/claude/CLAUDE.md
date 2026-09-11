@~/.codex/AGENTS.md

# Claude Code 固有の指示

- 確認には AskUserQuestion / EnterPlanMode を使う。

## 並列セッションの衝突回避（worktree isolation）

同一リポジトリで複数の Claude Code セッションが同時に走る前提で動くこと。

- **ファイルを編集するタスクは、最初の Edit/Write の前に `EnterWorktree` で専用 worktree に移る**（読み取り・調査のみのタスクは分離不要）。既に worktree 内にいる場合（`git rev-parse --git-dir` と `--git-common-dir` が一致しない）は再分離しない
- **worktree と branch は 1:1 に固定する。** branch を変えたくなったら既存 worktree 内で切り替えるのではなく、必ず新しい worktree を作る（hook `block-worktree-branch-switch.py` が機械的に強制する。ADR-081/082）
- main worktree の未コミット変更を持ち込みたい場合は `git stash push` → `EnterWorktree` → 新 worktree 内で `git stash pop`。「持ち込みたいから分離しない」という判断はしない
- **使い終わった worktree を残すか消すかをユーザに確認しない**（定期削除の処理で回収される。`ExitWorktree` は指示があったときだけ呼ぶ）。作業完了報告に「worktree が残っています、削除しますか」と書かない
- **ファイルを編集する subagent を Agent tool で起動する時は `isolation: "worktree"` を指定する**。subagent はコンテキストこそ独立だが working directory は親と共有するため、指定しないと親セッションと、あるいは並列 subagent 同士が同じ checkout を奪い合う。読み取り・調査のみの subagent（`Explore` 等）は指定しない。カスタム subagent 定義でも frontmatter の `isolation` に同じ値を書ける

## 調査結果のまとめ

- 調査結果は `.outputs/claude/` に出力する（global gitignore で除外済み）。ただしプロジェクト CLAUDE.md で出力先が指定されている場合はそちらに従う
