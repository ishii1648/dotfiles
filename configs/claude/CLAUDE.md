# Claude Code ガイドライン

- ユーザが意見を求めた場合、忖度せず批判的に検討したうえで回答すること
- 質問・承認要求の前に必ず自己解決を試みること（テストを実行して検証する、出力やブラウザで結果を確認する、ゴールから逆算して次ステップを自己判断する）。それでも必要なら作業開始前に AskUserQuestion / EnterPlanMode でまとめて確認する。物理的に不可能なもの（SMS 認証等）だけを人間に依頼する

## ユーザ環境

- シェルは **fish**。コマンド例も fish 構文で書く（heredoc `<<EOF` は使えないので `printf` + `tee` を使う）
- macOS (BSD) 環境。GNU 専用フラグを使わない（例: `cat -A` は無効 → `cat -e` / `cat -v`）
- `~/.claude/` 配下は nix home-manager が張る symlink 層（ADR-084）。参照専用として扱い、編集は dotfiles の実体 `~/ghq/github.com/ishii1648/dotfiles/configs/claude/` に対して行う（out-of-store symlink なので実体を直せば即反映される）

## ツール呼び出しの規律

- read-only（Read/Grep/Glob/参照系 Bash）の並列呼び出しはよい
- **Edit/Write/破壊的 Bash と「失敗しうる Bash」を同一バッチに混ぜない。** 1 つの非 0 exit が無関係な兄弟呼び出しを巻き添えでキャンセルする（ADR-089）
- 非 0 exit が想定される Bash（`pkill` / `grep -c` / `curl` プローブ / `gh ... checks` 等）は末尾に `|| true` を付ける
- 「保険」で同じコマンドを並列に並べない
- **状態確認は `git diff --stat` / `git diff` を唯一の真実として扱う。** Edit の成功表示・直後の Read・スクリプトの `OK` 出力を鵜呑みにしない。巻き添えキャンセルの後は特に、成功したはずの Edit が未適用であることを疑う
- 大きな anchor で Edit が滑るときは `python3` で `count == 1` を assert してから置換し、同じコマンド内で `git diff --stat` を出して着地を確認する
- 中断された外向きの操作（push 等）を無断で再試行しない。ユーザが別タスクへ誘導したら、それを終えてから再開の可否を確認する

## 並列セッションの衝突回避（worktree isolation）

同一リポジトリで複数の Claude Code セッションが同時に走る前提で動くこと。

- **ファイルを編集するタスクは、最初の Edit/Write の前に `EnterWorktree` で専用 worktree に移る**（読み取り・調査のみのタスクは分離不要）。既に worktree 内にいる場合（`git rev-parse --git-dir` と `--git-common-dir` が一致しない）は再分離しない
- **worktree と branch は 1:1 に固定する。** branch を変えたくなったら既存 worktree 内で切り替えるのではなく、必ず新しい worktree を作る（hook `block-worktree-branch-switch.py` が機械的に強制する。ADR-081/082）
- main worktree の未コミット変更を持ち込みたい場合は `git stash push` → `EnterWorktree` → 新 worktree 内で `git stash pop`。「持ち込みたいから分離しない」という判断はしない
- サブエージェントに並列でファイルを書かせる場合は `Agent(isolation: "worktree")` を使う
- main worktree で作業せざるを得ない場合、**ステージはパスを明示する**（`git add -A` / `git commit -a` は他セッションの編集中ファイルを巻き込む）
- **使い終わった worktree を残すか消すかをユーザに確認しない**（定期削除の処理で回収される。`ExitWorktree` は指示があったときだけ呼ぶ）。作業完了報告に「worktree が残っています、削除しますか」と書かない

## その他

- 設計判断・実装方針のセカンドオピニオンは `codex-advise` skill を使う。built-in `advisor` は無効化済みで、codex-advise が使えない状況でも advisor には戻さず、不足をユーザに伝えて判断を仰ぐ（ADR-089）
- 調査結果は `.outputs/claude/` に出力する（global gitignore で除外済み）。ただしプロジェクト CLAUDE.md で出力先が指定されている場合はそちらに従う
