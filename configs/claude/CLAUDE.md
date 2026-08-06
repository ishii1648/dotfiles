# Claude Code ガイドライン
- ユーザが意見を求めた場合、忖度せず批判的に検討したうえで回答すること

## 人間への確認を最小化
質問・承認要求の前に必ず自己解決を試みること。どうしても必要な場合は作業開始前に AskUserQuestion / EnterPlanMode でまとめて確認する：
- テストを実行して検証する
- ブラウザや出力で結果を確認する
- ゴールから逆算して次ステップを自己判断する
- 物理的に不可能なもの（SMS認証等）のみ人間に依頼

## ユーザ環境
- シェルは **fish** を使用している。コマンド例を示す際は fish 構文で記述すること（heredoc `<<EOF` は使用不可、代わりに `printf` + `tee` を使う）
- macOS (BSD) 環境。GNU 専用フラグを使わない（例: `cat -A` は無効 → `cat -e` / `cat -v` を使う）

## ツール呼び出しの規律（重要・再発防止）
過去に「同一コマンドの重複送信」と「BSD 非対応フラグ混入」が連鎖し、作業が崩壊した。並列の巻き添えキャンセルは既知バグ。以下を厳守する：
- **read-only（Read/Grep/Glob/参照系 Bash）は並列OK。** read-only の巻き添えキャンセルは修正済。
- **Edit/Write/破壊的 Bash と「失敗しうる Bash」は同一バッチに混ぜない。** 1 つの非0 exit が無関係な兄弟呼び出しを `Cancelled: parallel tool call errored` で連鎖キャンセルする（mutating 系は未修正）。
- 非0 exit が想定される Bash（`pkill` / `grep -c` / `curl` プローブ / `gh ... checks` 等）は末尾に `|| true` を付ける。
- 同一処理の冗長コピーを並列にしない。「保険」で同じコマンドを複数並べない（重複送信→連鎖崩壊）。
- 巻き添えキャンセル後は「成功したつもりの Edit/Write が未適用」を疑い、再実行前に `git diff` で着地を確認する。
- ファイル編集・状態確認は `git diff --stat` / `git diff` を**唯一の真実**として扱う。表示層が古い/捏造出力（重複エコー・`詳細は省略`・存在しない diff 等）を返すことがあるため、Edit や python の `OK` 出力・直後の Read 表示を鵜呑みにしない。
- 大きな anchor で Edit が滑る時は `python3` で `count==1` を assert してから置換し、同一コマンド内で `git diff --stat` を出して着地を確認する。
- 中断されたアクションを無断で再試行しない（特に push 等の外向き操作）。ユーザが別タスクへ誘導したら、そのタスクを終えてから再開可否を確認する。
- `~/.claude/CLAUDE.md` は dotfiles へのシンボリックリンク。編集は実体 `~/ghq/github.com/ishii1648/dotfiles/configs/claude/CLAUDE.md` に対して行う。

## 並列セッションの衝突回避（worktree isolation）
同一リポジトリで複数の Claude Code セッションが同時に走る前提で動くこと。ファイルの上書き合戦・`git` index lock の競合・自動コミットによる他セッション変更の巻き込みを防ぐ。

**不変条件（worktree と branch は 1:1）**: default worktree（main worktree、`git rev-parse --git-dir` と `--git-common-dir` が一致するディレクトリ）は常に default branch のままにする。linked worktree もそれぞれ作成時の branch に固定し、途中で別 branch へ switch/checkout しない（PreToolUse hook `block-worktree-branch-switch.py` が両方を機械的に強制する。ADR-081/082 参照）。branch を変えたくなったら既存 worktree 内で切り替えるのではなく、必ず新しい worktree を作る。

- **ファイルを編集するタスクは、最初の Edit/Write の前に `EnterWorktree` で専用 worktree に移る。** 読み取り・調査のみのタスクは分離不要。
- **main worktree の未コミット変更を新しい worktree に持ち込みたい場合は、先に `git stash push` してから `EnterWorktree` し、新 worktree 内で `git stash pop` する**（stash はリポジトリ共有でどの worktree からも参照できる）。「持ち込みたいから分離しない」という判断はしない — 上記の 1:1 不変条件を壊すため。
- 既に worktree 内にいる場合（`git rev-parse --git-dir` と `--git-common-dir` が一致しない）は再分離しない。
- サブエージェントに並列でファイルを書かせる場合は `Agent(isolation: "worktree")` を使う。
- main worktree で作業せざるを得ない場合、**ステージはパスを明示する**。`git add -A` / `git commit -a` は他セッションの編集中ファイルを巻き込む。
- **作業完了時に worktree を残すか消すかをユーザに確認しない。** 使い終わった worktree は定期削除の処理で回収されるため、都度の確認は不要（`ExitWorktree` は指示があったときだけ呼ぶ）。作業完了報告に「worktree が残っています、削除しますか」と書かない。

## セカンドオピニオンは codex-advise を使う
built-in `advisor` ツールは server-side tool で `permissions.deny` の対象外（deny しても
"matches no known tool" 警告が出るだけで効かない）。`~/.claude/settings.json` の
`env.CLAUDE_CODE_DISABLE_ADVISOR_TOOL: "1"` で無効化済み。設計判断・実装方針のセカンドオピニオンが
必要な場合は `codex-advise` skill（Codex/GPT-5 への相談、openai-codex plugin 経由）を使う。
codex-advise が使えない状況（openai-codex 未導入・未ログイン等）でも advisor には戻さない。その場合は不足を
ユーザに伝えて判断を仰ぐ。

## 調査結果のまとめ
- 調査結果は`.outputs/claude/`に出力すること（global gitignoreで除外済み）
- ただし、プロジェクト CLAUDE.md で調査ドキュメントの出力先が指定されている場合はそちらに従う

