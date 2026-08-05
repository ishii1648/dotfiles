# ADR-088: space / tab を開いたときに default branch を自動で pull する

## ステータス

Draft

## 関連 ADR

- 依存: [ADR-087](087-new-tab-workspace-at-default-worktree.md)（新しい tab / workspace を default worktree で開く。pull の対象ディレクトリはここで解決した default worktree）
- 依存: [ADR-077](077-new-workspace-ghq-picker.md)（Cmd+Shift+S の repo ピッカー。もう 1 つの呼び出し元）
- 関連: [ADR-086](086-herdr-new-workspace-auto-claude-launch.md)（同じくバックグラウンドで走らせる後処理。popup を待たせない形を踏襲）
- 関連: [ADR-082](082-pin-every-worktree-to-single-branch.md)（default worktree は常に default branch という不変条件。pull してよい前提の根拠）

## コンテキスト

ADR-077 / ADR-086 / ADR-087 で「repo を選ぶ → space / tab が default worktree で開く → claude が起動する」までは自動化された。しかし実際に作業を始める前には毎回手で `git pull origin <default branch>` を叩いており、ここが自動化のチェーンから漏れている。

ADR-082 の不変条件により default worktree は常に default branch のままなので、「開いた直後に default branch を最新にする」操作は安全に自動化できる。

## 設計案

### 案A: 開いた直後にバックグラウンドで `pull --ff-only` する（採用）

`configs/herdr/pull-default-branch.sh` を追加し、space / tab を default worktree で開いた直後に呼び出し元スクリプトからバックグラウンドで起動する。

採用理由:

- 呼び出し元は既に 2 系統（ピッカーの `new-workspace.sh` と ADR-087 の `new-default-worktree.sh`）あり、スクリプトを分けて共有するのが素直
- バックグラウンド化は ADR-086 で popup のクローズ遅延を踏んだときと同じ理由（ネットワーク往復を UI の待ち時間にしない）
- `--ff-only` なら merge commit を作らず履歴も書き換えないため、失敗しても副作用が無い

### 案B: 呼び出し元スクリプトに直接 pull を書く（却下）

却下理由: 同じロジックが 2 箇所（将来さらに増える可能性がある）に重複する。ガード条件（default worktree か、default branch に居るか、origin があるか）がそれなりの量になるため、コピーは維持できない。

### 案C: pane のシェル起動時に fish 側で pull する（却下）

却下理由: ADR-087 の案 C と同じ問題。pane を開くたびに走ってしまい、pane 分割や `herdr worktree open` など「最新化したくない」経路まで巻き込む。シェルの起動も遅くなる。

## 設計上の判断

- **`--ff-only` 固定** — merge commit を作らせない。fast-forward できない場合（ローカルが先行している・分岐している・dirty で衝突する）は何もせず失敗するだけで、ユーザーの作業を壊さない
- **default worktree でのみ実行する** — linked worktree で pull すると、その worktree の作業ブランチに default branch を取り込むことになり ADR-082 の運用を壊す。`git-dir` と `git-common-dir` の一致で判定する
- **現在のブランチが default branch のときだけ実行する** — ADR-082 の不変条件では常に一致するはずだが、崩れている場合に `origin/<default>` を取り込むのは意図と異なるため skip する
- **失敗は呼び出し元に伝播させない** — 最新化できなくても space / tab 自体は使える。バックグラウンドで走らせ、結果は `~/.local/state/herdr/pull-default-branch.log` に残すだけにする
- **claude の起動とは順序を持たせない** — pull を待ってから claude を起動すると起動が体感で遅くなる。claude はファイルを遅延読みするため、先に pull が終わっている必要は無い。両者を独立にバックグラウンドで走らせる
- **同時実行のロックは取らない** — tab を短時間に複数開くと同じ repo に対して pull が並行し、片方が `index.lock` で失敗する。ただし失敗しても副作用が無く、どれか 1 つが成功すれば目的は達成されるため、ロック機構は持たない（stale lock の後始末という新しい失敗モードを増やさない方を選ぶ）
- **default branch の検出は既存実装に揃える** — `git symbolic-ref refs/remotes/origin/HEAD` → `init.defaultBranch` の順。`gw_add.fish` / `block-worktree-branch-switch.py` と同じ。ブランチ名に `/` を含む場合も壊れないよう、末尾要素ではなく prefix を剥がして取り出す
- **pane には何も出力しない（不可視であることを受け入れる）** — pull は pane のシェルに入力するのではなく、popup スクリプトが起動する独立プロセスとして走る。pane の TTY には繋がっておらず、`git pull` の実行も出力も画面には一切現れない。理由は (1) claude の起動と同じ pane を奪い合わない (2) ネットワーク往復の間 popup のクローズや claude 起動を待たせない、の 2 点。**代償として「動いているかどうかがユーザーから見えない」**ことを受け入れる。この代償は実際に 2 回顕在化した — SIGHUP による即死（後述）が症状として「何も起きない」だったこと、および利用者から「pull が実行されているように見えない」と問われたこと
- **可観測性はログに一本化する** — pane に出さない以上、確認手段はログだけになる。したがって「ログに必ず 1 行残す」ことが設計の必須要件になる。成功は `pulled <branch>`、意図的なスキップは `skip: <理由>`、失敗は `warn:` を必ず出力し、stderr も `/dev/null` に捨てずログへ落とす（ログの読み方は [reference.md](../reference.md) に記載）
- **`cd` せず `git -C <path>` で操作する** — 対象ディレクトリはパス引数で渡す。pane の cwd とも呼び出し元スクリプトの cwd とも独立に動かせるため、popup の cwd 継承（`[terminal] new_cwd = "follow"`）の影響を受けず、`cd` の失敗という分岐も持たなくて済む

## 実装中に判明した既存バグ

`pull --ff-only` が初回だけ必ず失敗する現象をテストで踏んだ。原因は本 ADR の設計ではなく、herdr スクリプト共通のログ処理にあった。

`log()` の中でだけ `mkdir -p "$(dirname "$LOG_FILE")"` していると、happy path で最初に `$LOG_FILE` へ触れるのが `git ... >>"$LOG_FILE"` のリダイレクトになる。ログディレクトリが未作成の初回実行ではこのリダイレクト自体が失敗し、**コマンドを実行しないまま失敗扱い**になる（2 回目以降はディレクトリが出来ているため成功し、気付きにくい）。

同型のバグが ADR-087 の `new-default-worktree.sh` にも入っていた（`herdr tab create` が初回だけ失敗する）。実機で発覚しなかったのは、`~/.local/state/herdr/` が既存スクリプトによって既に作られていたため。両方とも `LOG_FILE` 定義直後に `mkdir -p` する形に修正した。

## 実機投入後に判明した問題: バックグラウンド起動が SIGHUP で即死する

実装直後の実機確認（clusterops を選択）で、workspace 作成と claude 起動は成功するのに pull だけが**一切走らない**（`pull-default-branch.log` に 1 行も残らない）事象が出た。スクリプト単体を同じ引数で直接実行すると正常に pull できるため、スクリプトではなく呼び出し方の問題と切り分けた。

原因は **herdr が popup を閉じるときプロセスグループへ SIGHUP を送ること**。`&` + `disown` だけでは背景プロセスは SIGHUP を受けて即死し、スクリプトの 1 行目に到達する前に消えるためログすら残らない。

同じ形で起動している `launch_claude_retry`（ADR-086）が無事だったのは、**関数の冒頭で `trap '' HUP` している**から。この差が唯一の違いだったことから仮説を立て、プロセスグループへ SIGHUP を送る再現実験で「素の外部コマンドは死亡 / `trap '' HUP` 付きは生存」を確認した。ADR-086 に「未検証」として残していた懸念（herdr がプロセスグループごと終了させる実装だった場合に巻き込まれる）が、実際に起きていたことになる。

対処:

- 呼び出しを `( trap '' HUP; exec <script> <arg> ) &` の形にした。サブシェル（既に動いている bash）で SIG_IGN にしてから `exec` すると、その disposition は exec 後のプロセスにも引き継がれるため、fork 直後に SIGHUP が飛んできても死なない。`nohup` も同じ効果を狙えるが、`nohup` 自身が外部コマンドなので「exec 前に撃たれる」レースが残る
- stderr を `/dev/null` ではなくログへ落とすようにした。今回は「ログが無い」以外の手掛かりが無く切り分けに時間がかかったため

## 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/herdr/pull-default-branch.sh` | 新規。ガードを通ったうえで `git pull --ff-only origin <default branch>` を実行する |
| `configs/herdr/new-workspace.sh` | workspace 作成後にバックグラウンドで呼ぶ |
| `configs/herdr/new-default-worktree.sh` | tab / workspace 作成後にバックグラウンドで呼ぶ。あわせてログディレクトリ作成の初回バグを修正 |
| `nix/symlinks.nix` | `~/.local/bin/herdr-pull-default-branch` を追加 |
| `scripts/setup-manifest.yml` | 同上（`nix_managed: true`） |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-088 セクション）
