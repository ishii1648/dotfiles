# Claude Code ガイドライン

- ユーザが意見を求めた場合、忖度せず批判的に検討したうえで回答すること
- 確認が必要な場合は、作業の途中で小刻みに聞かず、着手前に AskUserQuestion / EnterPlanMode でまとめて聞くこと
- 中断された外向きの操作（push 等）を無断で再試行しない。ユーザが別タスクへ誘導したら、それを終えてから再開の可否を確認する

## ユーザ環境

- シェルは **fish**。コマンド例も fish 構文で書く（heredoc `<<EOF` は使えないので `printf` + `tee` を使う）
- macOS (BSD) 環境。GNU 専用フラグを使わない（例: `cat -A` は無効 → `cat -e` / `cat -v`）
- `~/.claude/` は参照専用。編集は dotfiles の実体 `~/ghq/github.com/ishii1648/dotfiles/configs/claude/` に対して行う（ADR-084）

## 並列セッションの衝突回避（worktree isolation）

同一リポジトリで複数の Claude Code セッションが同時に走る前提で動くこと。

- **ファイルを編集するタスクは、最初の Edit/Write の前に `EnterWorktree` で専用 worktree に移る**（読み取り・調査のみのタスクは分離不要）。既に worktree 内にいる場合（`git rev-parse --git-dir` と `--git-common-dir` が一致しない）は再分離しない
- **worktree と branch は 1:1 に固定する。** branch を変えたくなったら既存 worktree 内で切り替えるのではなく、必ず新しい worktree を作る（hook `block-worktree-branch-switch.py` が機械的に強制する。ADR-081/082）
- main worktree の未コミット変更を持ち込みたい場合は `git stash push` → `EnterWorktree` → 新 worktree 内で `git stash pop`。「持ち込みたいから分離しない」という判断はしない
- main worktree で作業せざるを得ない場合、**ステージはパスを明示する**（`git add -A` / `git commit -a` は他セッションの編集中ファイルを巻き込む）
- **使い終わった worktree を残すか消すかをユーザに確認しない**（定期削除の処理で回収される。`ExitWorktree` は指示があったときだけ呼ぶ）。作業完了報告に「worktree が残っています、削除しますか」と書かない

## 調査結果のまとめ

- 調査結果は `.outputs/claude/` に出力する（global gitignore で除外済み）。ただしプロジェクト CLAUDE.md で出力先が指定されている場合はそちらに従う
