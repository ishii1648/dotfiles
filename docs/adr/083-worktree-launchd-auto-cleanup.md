# ADR-083: 作成から72時間超の worktree を launchd で無条件自動削除する

## ステータス
Draft

## 関連 ADR
- 関連: ADR-081（main worktree での branch switch ブロック）— 同 ADR のコンテキストで「リンク worktree が 224 個も放置されていた」cleanup 運用の問題が指摘され、「hook では解決しない、別途定期実行で対処する」と明記されていた。本 ADR はその積み残しに対する具体策
- 関連: ADR-012（fish 関数の per-repo symlink 配布）— 既存の手動削除ルーティン `gw_rm.fish` と同じ配布パターンを踏襲する

## コンテキスト

`configs/fish/functions/gw_rm.fish` として「マージ済み／同一HEAD／remote無し+古い／単純に古い」の4条件で worktree を一括削除する手動ルーティンは既にあるが、**完全に手動実行**であり、実行を忘れると際限なく溜まる（ADR-081 コンテキストで実測 224 個）。

Claude Code の `EnterWorktree`/`ExitWorktree` を使うようになってから worktree の生成頻度自体が上がっており、`.claude/worktrees/` 配下だけでなく `git worktree add` 全般（herdr 経由・手動含む）が対象になる。

ユーザーへのヒアリングの結果、判断基準は明確だった: **経験的に worktree を3日（72時間）以上温存するケースがない**。したがってマージ状態やブランチの生死を判定する必要はなく、単純な経過時間だけで無条件に削除してよいという明示的なリスク許容がある。この単純さを活かし、`gw_rm` のような判定ロジックの移植はせず、時間ベースの新規ルーティンとして切り出す。

## 設計案

**単一の設計**（以下の4つの決定軸はいずれも同じ仕組みの構成要素であり、独立した対立案ではない）。

- **スケジューラ: launchd を採用**（cron は不採用）
  - macOS では cron は legacy 扱いで TCC/Full Disk Access の制約を受けやすい。launchd が現代的な標準
  - 却下: 伝統的な `crontab` — このリポジトリには既に `configs/claude/setup.sh` に launchd agent 導入のパターン（`configs/claude/launchd/*.plist` → `~/Library/LaunchAgents` へコピー → `launchctl load`、`setup.sh --dry-run` での存在チェック）があり、それを踏襲する方が一貫性が保てる
  - 実行頻度は1日1回（72時間しきい値に対し十分な粒度。時刻はシステム負荷の低い深夜帯を想定）

- **経過時間の判定ソース: worktree ディレクトリの birthtime（`stat -f %B`）を採用**
  - git は worktree の「作成日時」を直接保持しない。プロキシ指標が必要
  - 却下: `.git`（gitdir pointer ファイル）の mtime — `git worktree repair` 等の操作で更新されうり、削除判定の基準として不安定
  - 却下: worktree ディレクトリ自体の mtime — ディレクトリ直下へのエントリ追加・削除で更新されるため「作成日時」との乖離が起きうる
  - 却下: ブランチの最初のコミット日時 — 古いブランチに対して後から worktree を作った場合、実際の worktree 作成時刻より大幅に古い時刻を指してしまい誤判定する
  - birthtime は APFS（macOS 標準）でファイル作成時刻をそのまま保持するため、「いつこの worktree ディレクトリが作られたか」に最も忠実

- **対象リポジトリの発見: `ghq list --full-path` で横断的に列挙**
  - 却下: 対象リポジトリを設定ファイルに明示列挙 — 新規 clone のたびにメンテが必要になり、ユーザーの利用実態（ghq 管理下の全リポジトリで worktree を使う）に合わない
  - 各リポジトリで `git worktree list --porcelain` を実行し、`main worktree`（`git rev-parse --git-dir` == `--git-common-dir` のディレクトリ）は判定対象から必ず除外する（`gw_rm.fish` と同じ安全条件）

- **削除条件と削除方法**
  - 経過時間が 72 時間を超えていれば、マージ状態・ブランチ名を一切問わず削除する（`gw_rm` の「マージ済み」「同一HEAD」判定は使わない）
  - `git worktree remove --force` を使う。未コミット・未 push の変更が残っていても強制削除する（「無条件」というユーザー指示の文字通りの解釈。git のデフォルト拒否に頼らない）。**この「未コミット変更ごと強制削除する」点は今回のユーザー指示から実装エージェント側で踏み込んだ解釈であり、実装時に改めてユーザーに確認する**
  - **`locked` な worktree は経過時間を問わず対象外にする** — 実装中に実測したところ、Claude Code の `EnterWorktree` はセッション稼働中の worktree に `git worktree lock --reason "claude session <name> (pid <pid> ...)"` を張っており（`git worktree list --porcelain` の `locked <reason>` 行で確認可能）、かつ `git worktree remove --force` は `-f` 一発で dirty と locked の両方を無視して強制削除できてしまう（`git worktree remove -h` の `-f, --force: force removal even if worktree is dirty or locked` で確認）。72h という時間経過だけでは「今アクティブに使われているか」を判定できず、時間ベース無条件削除の対象からは originally 除外する意図が無かった「今まさに動いている他セッション」を巻き込みうる。ユーザーが許容したリスクは「3日以上放置された古い作業」であり「稼働中のセッション」ではないため、porcelain の `locked` 行を検出したブロックは無条件に skip する（`--force` の二重防御には頼らない）
  - 対応するローカルブランチも `git branch -D` で削除する（`gw_rm.fish` と同挙動）
  - 削除対象・削除結果（成功/失敗、対象パス、経過時間）を `~/.local/state/worktree-cleanup/cleanup.log` に記録する（herdr スクリプト群の `$XDG_STATE_HOME/herdr/*.log` と同じロギング規約）

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/fish/scripts/worktree-auto-cleanup.sh` | dotfiles | 新規: ghq 横断で 72h 超 worktree を検出・強制削除するスクリプト |
| `configs/fish/launchd/com.user.worktree-auto-cleanup.plist` | dotfiles | 新規: 1日1回起動する launchd agent 定義 |
| `configs/fish/setup.sh` | dotfiles | `configs/claude/setup.sh` の launchd agent 導入ブロックと同型の処理を追加 |
| `docs/issues.md` | dotfiles | 受け入れ条件追記 |

## 懸念

- `--force` によりレビュー前の未 push コミットが失われるリスクがある。ユーザーの経験則（3日以上残さない）を前提にした割り切りであり、一般的なベストプラクティス（無人フル自動削除は危険視されることが多い）からは踏み込んだ判断であることを明記しておく
- launchd agent はユーザーが Mac にログインしていない・スリープ中は実行されない（`StartCalendarInterval` の性質上、実行を逃した回はスキップされ次回起動を待つ）。72h という猶予があるため実運用上は許容範囲と判断
- 複数 Mac 端末を使っている場合、端末ごとに独立した launchd agent が動く。worktree はローカルディスク上のものなので端末をまたいだ二重削除等の問題は起きない

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-083 セクション）
