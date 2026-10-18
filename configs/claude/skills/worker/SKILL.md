---
name: worker
description: >-
  Work on one Issue as a worker session of the board workflow: record progress for the Control
  room, ask the human directly in this terminal, and open the PR (research results included). Started
  by `board dispatch` with "/worker <N>"; not for manual use.
version: 0.3.0
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
argument-hint: "<Issue number>"
---

# worker

このセッションは Issue #$ARGUMENTS だけを担当するワーカー。名前は `$BOARD_BY`（例: `hub-42`）。起点のリポジトリ（`owner/name`）は `~/.config/board/config.json` の `repo` にある。以下 `<R>`、Issue 番号を `<N>` と書く。

人はこの端末で直接話しかけてくる。人は Control room（board）で全体を見ていて、確認待ちになったこのワーカーを「開く」ボタンや通知から開く。`board event` を記録しないと Control room に出ないので、状態が変わるたびに必ず記録する。

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

3. `board event <N> started "branch=<branch> repo=<repo>"`

`board event` は `$BOARD_BY` を書き手として記録するので `--by` は要らない。

## 人の判断が要るとき

1. `board event <N> <type> "<1 行の要約>"` を記録する（Control room とカードに確認待ちとして出て、人に通知が届く）
2. Issue コメント `GHTKN_APP=write gh issue comment <N> --repo <R> --body "..."` で経過を残す
3. この端末で、人への問いや報告を書いてターンを終え、返事を待つ

| 場面 | type | 端末に書くこと |
|---|---|---|
| 判断が必要 | `question` | 何を決めてほしいか、選択肢、自分の推奨 |
| 続行できない | `blocked` | 理由と、何があれば進めるか |
| PR を作った | `pr`（`--url <PR の URL>` を付ける） | 変更の要約とレビューしてほしい点 |

要約は 1 行に収め、詳細は端末と Issue コメントに書く。

## 返事を受けたら

人の返事で作業に戻るときは、まず記録する。

```sh
board event <N> answer "<回答の要約>"       # 質問への回答
board event <N> unblocked "<解決の要約>"    # blocked が解けた
board event <N> revise "<指摘の要約>"       # PR へのレビュー指摘
```

## PR

- push は `-u` 付き（upstream を設定する）
- `GHTKN_APP=write gh pr create ...` で、PR は作業したリポジトリに立てる
- 本文に `Closes <R>#<N>` を書く。マージ時に Issue が閉じ、board サーバーが worktree の片付けを行う
- マージは人が行う。自分でマージしない

## 調査が成果物の Task（label `research`）

- 結果は調査の対象にかかわらず、起点のリポジトリの今いる worktree の `docs/<topic>/` に Markdown で書く。`<topic>` は Issue の内容を表す kebab-case の名前にし、同じ topic のディレクトリが既にあればそこに追記・更新する
- 結論は `docs/<topic>/README.md` に置き、詳細は同じディレクトリの別ファイルに分ける
- commit して通常の Task と同じく PR を作り、`pr` を記録する。人がマージすると受け入れになり、Issue が閉じる

## しないこと

- 担当以外の Issue に触れない、他のワーカーを dispatch しない
- Issue を close しない、PR をマージしない
- カードの状態を `orca worktree set` で変えない、events.jsonl を直接書かない
