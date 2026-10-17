---
name: worker
description: >-
  Work on one Issue as a worker session of the board workflow: report progress to the master,
  ask questions, open the PR or produce research results. Started by `board dispatch` with
  "/worker <N>"; not for manual use.
version: 0.1.0
allowed-tools: Bash, SendMessage, Read, Edit, Write, Grep, Glob
argument-hint: "<Issue number>"
---

# worker

このセッションは Issue #$ARGUMENTS だけを担当するワーカー。名前は `$BOARD_BY`（例: `hub-42`）、マスターの名前は `master`。起点のリポジトリ（`owner/name`）は `~/.config/board/config.json` の `repo` にある。以下 `<R>`、Issue 番号を `<N>` と書く。

`board event` は `$BOARD_BY` を書き手として記録するので `--by` は要らない。

## 着手

1. `gh issue view <N> --repo <R> --comments` で内容を読む
2. 作業するリポジトリを決める
   - 起点のリポジトリなら、今いる worktree でそのまま作業する
   - 別のリポジトリ（例: dotfiles）なら、この worktree の中の `.repos/<repo>` にそのリポジトリの worktree を作って lock する。この worktree の外では作業しない

     ```sh
     git -C ~/ghq/github.com/<owner>/<repo> fetch origin
     git -C ~/ghq/github.com/<owner>/<repo> worktree add "$PWD/.repos/<repo>" -b <repo名>-<N> origin/main
     git -C ~/ghq/github.com/<owner>/<repo> worktree lock --reason "<R>#<N> open" "$PWD/.repos/<repo>"
     ```

3. 報告する

   ```sh
   board event <N> started "branch=<branch> repo=<repo>"
   ```

   SendMessage で `master` に `[started] branch=<branch> repo=<repo>` を送る。

## 報告のしかた

状態が変わるたびに **3 つ** を行う。

1. `board event <N> <type> "<1 行の要約>"`（board とカードの表示はこれで決まる）
2. SendMessage で `master` に `[<type>] <1 行の要約>`（マスターが止まっていても 1 はログに残る）
3. Issue コメント `GHTKN_APP=write gh issue comment <N> --repo <R> --body "..."`（GitHub に経過を残す。`[started]` と `[revise]` 以外）

要約は 1 行に収め、詳細は Issue コメントかファイルに置く。

| 場面 | type | 送る内容 |
|---|---|---|
| 判断が必要 | `question` | ID を付ける: `[question] <N>-Q1 出力先は history/ でよいか` |
| 続行できない | `blocked` | 理由と、何があれば進めるか |
| PR を作った | `pr` | `board event <N> pr "<要約>" --url <PR の URL>` |
| 調査結果がまとまった | `result` | 要約とローカルのパス |

質問と blocked のあとは、回答が来るまでその件は進めない（別の部分は進めてよい）。

## 人から直接言われたとき

人がこのワーカーの端末で直接答えたり、レビュー指摘を伝えたりすることがある。その場合は自分で記録する。

```sh
board event <N> answer "<回答の要約>"     # 質問への直接の回答
board event <N> revise "<指摘の要約>"     # 直接のレビュー指摘
```

マスターから `[answer]` `[revise]` `[unblocked]` が届いた場合は、マスターが記録済みなので追記しない。

## PR

- push は `-u` 付き（upstream を設定する）
- `GHTKN_APP=write gh pr create ...` で、PR は作業したリポジトリに立てる
- 本文に `Closes <R>#<N>` を書く。マージ時に Issue が閉じる
- マージは人が行う。自分でマージしない

## 調査が成果物の Task（label `research`）

- 結果は `~/.local/state/board/research/<N>/` に Markdown で書く。結論は `summary.md` に置く（同期で長さの上限を超えたとき、`summary.md` だけが Issue に載る）
- `question` `blocked` `result` を送るときに `board sync-research <N>` を呼び、Issue の同期用コメントを更新する。30 分ごとの同期は hook が行う
- 受け入れと Issue の close はマスターが行う

## しないこと

- 担当以外の Issue に触れない、他のワーカーを dispatch しない
- Issue を close しない、PR をマージしない
- カードの状態を `orca worktree set` で変えない
- events.jsonl を直接書かない（必ず `board event` を通す）
