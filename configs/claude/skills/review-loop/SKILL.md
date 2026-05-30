---
name: review-loop
description: >-
  This skill should be used after the current coding session has finished implementing something and
  wants its work cross-reviewed by the other agent and to iterate until it converges, such as
  "codex にレビューさせて反映するループを回して", "review-loop", "/review-loop", "実装できたので
  codex にレビューさせて指摘がなくなるまで直して", "レビュー→修正を収束まで自動で回して".
  The current coding session itself stays as the implementer/fixer: it launches the OPPOSITE agent
  (claude implementer → codex reviewer, codex implementer → claude reviewer) as a reviewer in a pane
  of the SAME tmux session, waits for the verdict, fixes the diff itself, and repeats until APPROVED
  or max rounds. Takes no arguments.
version: 1.0.0
allowed-tools: Bash, Read, Edit, Write
---

# review-loop - 元セッション主導の反復レビューループ

## 概要

**一通り実装が終わった段階**で、いま作業しているこの coding session（＝実装した本人）が主役となって回すレビューループ。あなた（元セッション）が実装役兼オーケストレータとして残り、**自分とは逆のエージェント**をレビュアーとして**同一 tmux session の pane** に起動し、レビュー結果を受け取って**自分で**修正し、収束するまで繰り返す。設計は ADR-071（ADR-070 を置換）。

- **実装・修正役 = あなた（このセッション）に固定**。実装役を別プロセスとして起動しない。
- **レビュアー = あなたの逆エージェント**（あなたが claude なら codex、codex なら claude）。これで「実装したのとは異なるモデルの目」を入れる。
- **同一 tmux session に reviewer pane を追加**する（専用 session は作らない）。
- **引数なしで起動**する。レビュー観点・基点・ラウンド数を調整したい場合はユーザーの自然言語指示として受け取り、内部で `review-once` のフラグに変換する。

`review-loop.sh` は「レビュアーを1ラウンド起動する（`review-once`）」「レビュー完了を待つ（`wait-review`）」だけを担う薄いユーティリティ。**ループ制御・収束判定・修正はあなたがこの手順に従って実行する**。

線形チェーン（planner→tdd→reviewer を1回ずつ）には `/orchestrate`、片方向の単発起動には `/dispatch`。review-loop は**実装済みコードを逆エージェントに反復レビューさせて収束させる**ことに特化する。

## 前提

- tmux セッション内かつ git リポジトリ内であること。
- レビュー対象の差分が base（既定: origin/HEAD→main→master を自動解決）から見えること（コミット済み or 作業ツリーに変更が乗っている）。
- 実装は概ね完了していること（round1 はレビューから始まる。実装フェーズは挟まない）。

## ワークフロー

以下を**あなた自身が**実行する。`SCRIPT=~/.claude/skills/review-loop/review-loop.sh` とする。

### Step 1: 自分の逆エージェントを決める

あなたが **claude** なら `REVIEWER=codex`、**codex** なら `REVIEWER=claude`。これがレビュアーになる。

### Step 2: 前提チェックと初期化（Bash ツール）

- `git rev-parse --show-toplevel` で `REPO_ROOT` を取得。
- `tmux display-message -p '#{session_name}'` が成功すること（tmux 内であること）。
- `date +%Y%m%d-%H%M%S` で `SESSION_ID=reviewloop-<stamp>` を生成。
- ユーザーがレビュー観点を指示している場合のみ、**Write ツール**でその観点を `REPO_ROOT/.outputs/claude/review-loop/<SESSION_ID>/note.md` に書く（任意。なければ作らない）。

### Step 3: round=1 でレビューを起動（Bash ツール）

```bash
bash $SCRIPT review-once "<REPO_ROOT>" --session-id "<SESSION_ID>" --reviewer "<REVIEWER>" --round 1 \
  [--base <ref>] [--note "<REPO_ROOT>/.outputs/claude/review-loop/<SESSION_ID>/note.md"]
```

`--base` / `--note` はユーザー指示があるときだけ付ける。出力の `REVIEW_OUT`（= `round-1-review.md` のパス）を控える。

### Step 4: レビュー完了を待つ（Bash ツールを `run_in_background: true` で）

```bash
bash $SCRIPT wait-review "<REPO_ROOT>" --session-id "<SESSION_ID>" --round <N>
```

**必ず `run_in_background: true` で実行する**（最大 900s ブロックするため）。レビュアーは隣の pane で走っており、完了マーカー（`round-N-review.md` の `REVIEW_RESULT` 行）を検知するとこのコマンドが終了し、あなたが再開される。終了時の出力から `VERDICT`（`APPROVED` / `CHANGES_REQUESTED`）と `STATUS`（`TIMEOUT` なら失敗）を読む。

### Step 5: VERDICT に応じて分岐

| VERDICT / STATUS | 対応 |
|---|---|
| `APPROVED` | 収束。Step 6 へ |
| `CHANGES_REQUESTED` | **Read ツール**で `REVIEW_OUT`（`round-N-review.md`）を読み、妥当な指摘を**あなた自身が**修正する（同意できない指摘は対応せず理由を控える）。修正後、`round` を +1 して Step 3 を `--round <round+1>` で再実行 → Step 4 → Step 5。ただし `round` が最大ラウンド（既定 3）に達していたら打ち切り、Step 6 へ |
| `TIMEOUT` | レビュアーがタイムアウト。pane を確認して原因を報告し、必要なら cleanup して終了 |

### Step 6: 収束・サマリ

**Write ツール**で `REPO_ROOT/.outputs/claude/review-loop/<SESSION_ID>/SUMMARY.md` に結果（収束 or 打ち切り・実行ラウンド数・レビュアー・各 `round-N-review.md` へのリンク）を書き、ユーザーに以下を報告する。

- 結果（`converged` / `exhausted`）と実行ラウンド数
- レビュアー（逆エージェント）と base ref
- 各ラウンドのレビュー結果ファイル
- 後始末コマンド: `bash $SCRIPT cleanup <SESSION_ID>`

## cleanup

```bash
bash ~/.claude/skills/review-loop/review-loop.sh cleanup "<SESSION_ID>"
```

reviewer window と manifest を削除する。**元セッションのある tmux session 自体は閉じない**（reviewer 用に追加した window のみ削除する）。

## 制約

- tmux セッション内かつ git リポジトリ内でのみ動作する。
- 実装・修正役は常に元セッション（あなた）。実装役を別プロセスとして起動しない。レビュアーはあなたの逆エージェントに固定（選択引数なし）。
- レビュアーが codex のときは `-s read-only` sandbox でコード変更が機構的に禁止される。レビュアーが claude になるのは**元セッションが codex のときのみ**で、この場合 sandbox 強制はなく「コードを変更しない」というプロンプト指示に依存する。
- claude をレビュアーに使うとき `claude -p` / `--print` は使わない（subscription 課金を維持）。各ラウンド stateless で新規 session-id で起動し、前回レビューはプロンプトに同梱する。
- 現在の worktree（レビュー対象ブランチ）上で動き、新規 worktree は作らない。
- レビュー結果は `round-N-review.md` の `REVIEW_RESULT` 行で完了検知・収束判定する。
