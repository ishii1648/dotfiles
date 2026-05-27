---
name: review-loop
description: >-
  This skill should be used when the user wants to run an iterative cross-review loop between
  claude (implementer) and codex (reviewer), such as "codex にレビューさせて反映するループを回して",
  "review-loop", "/review-loop", "claude 実装 → codex レビュー → 反映を収束まで自動で回して",
  "codex の指摘がなくなるまで直して". Drives claude and codex alternately via tmux wait-for until
  codex approves or max rounds are reached.
version: 0.1.0
allowed-tools: Bash, AskUserQuestion
argument-hint: '"<タスク or レビュー観点>" [--max-rounds N] [--base <ref>]  # 現在の worktree で claude↔codex 反復レビューを回す'
---

# review-loop - claude↔codex 反復レビューループ

## 概要

claude（実装役）と codex（レビュー役）を `tmux wait-for` で交互に駆動し、「claude 実装 → codex レビュー → claude 反映 → codex 再レビュー」を **codex が承認するか最大ラウンドに達するまで** 自動で回す。設計は ADR-070。

- claude は `--session-id`/`--resume` でラウンド間の文脈を保持する（`claude -p` は使わない＝subscription 課金）
- codex は各ラウンド `codex exec -s read-only` で headless にレビューする
- **現在の git worktree（レビュー対象ブランチ）上で動く。新規 worktree は作らない**
- コアロジックは `~/.claude/skills/review-loop/review-loop.sh` に委譲する

線形のエージェントチェーン（planner→tdd→reviewer を1回ずつ）には `/orchestrate`、単発の片方向起動には `/dispatch` を使う。review-loop は**同一ペアの反復（収束）**に特化する。

## ワークフロー

### Step 1: 引数の解析

引数から以下を取得する。

| 引数 | 説明 | 既定 |
|---|---|---|
| `"<タスク or レビュー観点>"`（位置引数・必須） | round1 で claude に実装させるタスク。既に実装済みのものをレビューさせたい場合は「現在のブランチの変更を仕上げて」等のレビュー観点を書く | — |
| `--max-rounds N` | 最大ラウンド数（claude→codex を 1 ラウンドと数える） | 3 |
| `--base <ref>` | レビューの差分基点。省略時は origin/HEAD→main→master を自動解決 | 自動 |

タスク記述が無い場合は AskUserQuestion で確認する。

### Step 2: 前提チェック

- **Bash ツール**で `git rev-parse --show-toplevel` を実行し、リポジトリルートを取得する。tmux セッション内かつ git リポジトリ内であること（`review-loop.sh` 側でも検証する）。
- session-id を生成する: `reviewloop-YYYYMMDD-HHMMSS`（**Bash ツール**で `date +%Y%m%d-%H%M%S`）。

### Step 3: タスクファイルを書き込む

**Write ツール**でタスク記述を `<repo-root>/.outputs/claude/review-loop-task-<session-id>.md` に書き込む（全文のみ）。

### Step 4: launch 実行

**Bash ツール**で `review-loop.sh launch` を実行する。現在のターミナルサイズを引き継ぐため `--inherit-size` を付ける。

```bash
bash ~/.claude/skills/review-loop/review-loop.sh launch "<repo-root>" \
  --session-id "<session-id>" \
  --task-file "<repo-root>/.outputs/claude/review-loop-task-<session-id>.md" \
  --max-rounds <N> [--base <ref>] --inherit-size
```

### Step 5: STATUS に応じて分岐

| STATUS | 対応 |
|--------|------|
| `LAUNCHED` | 完了報告（SESSION_ID, TMUX_SESSION, BASE_REF, MAX_ROUNDS, OUT_DIR を表示） |
| `ERROR` | MESSAGE を表示して終了 |

### Step 6: 完了報告

```
review-loop を起動しました
  session-id: <SESSION_ID>
  tmux session: <TMUX_SESSION>   (確認: tmux attach -t <TMUX_SESSION>)
  base ref: <BASE_REF>
  最大ラウンド: <MAX_ROUNDS>
  出力: <OUT_DIR>/  (round-N-codex.md, SUMMARY.md)

claude→codex を最大 <MAX_ROUNDS> ラウンド自動で回します。
codex が APPROVED を返すか最大ラウンド到達で収束し、SUMMARY.md に結果が出ます。
クリーンアップ: bash ~/.claude/skills/review-loop/review-loop.sh cleanup <SESSION_ID>
```

**元セッションの review-loop skill はここで終了する**（advance ループはバックグラウンドで継続する）。

## cleanup

```bash
bash ~/.claude/skills/review-loop/review-loop.sh cleanup "<session-id>"
```

advance ループの停止・tmux セッション削除・manifest 削除を行う。

## 制約

- tmux セッション内かつ git リポジトリ内でのみ動作する
- claude（実装役）は interactive 起動（`claude -p` 不使用）で subscription 課金を維持する
- codex（レビュー役）は read-only sandbox で起動するため、レビュー中にコードを変更しない
- ネットワーク通信を伴うコマンド前提の処理は持たない（codex のレビューは現在の worktree 差分のみを対象とする）
