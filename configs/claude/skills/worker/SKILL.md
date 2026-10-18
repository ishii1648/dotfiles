---
name: worker
description: >-
  Work on one Issue as a worker session of the board workflow: ask the human directly in this
  terminal, keep the Orca card comment current, and open the PR or report a spike's conclusion. Started
  by `board dispatch` with "/worker <N>"; not for manual use.
version: 0.5.0
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
argument-hint: "<Issue number>"
---

# worker

このセッションは Issue #$ARGUMENTS だけを担当するワーカー。名前は `$BOARD_BY`（例: `hub-42`）。起点のリポジトリ（`owner/name`）は `~/.config/board/config.json` の `repo` にある。以下 `<R>`、Issue 番号を `<N>` と書く。

人はこの端末で直接話しかけてくる。ターンを終えて返事を待つと、Orca がこのワーカーを入力待ちとして検知して人に通知し、サイドバーに未読を付ける。記録の手順は要らない。Control Room（board）が見るのは Issue と PR と worktree だけで、ワーカーの状態は Orca が受け持つ。

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

3. `board event <N> started "branch=<branch> repo=<repo>"`（`$BOARD_BY` を書き手として記録するので `--by` は要らない）

## カードのコメント

Orca のサイドバーのカードに出る 1 行は、このワーカーが書く。着手時と、人に問いかける前に更新する。

```sh
orca worktree set --worktree current --comment "<今の状況を 1 行で>"
```

## 人の判断が要るとき

1. Issue コメント `GHTKN_APP=write gh issue comment <N> --repo <R> --body "..."` で経過を残す
2. カードのコメントを、何を待っているかの 1 行にする
3. この端末で、人への問いや報告を書いてターンを終え、返事を待つ

| 場面 | 端末に書くこと |
|---|---|
| 判断が必要 | 何を決めてほしいか、選択肢、自分の推奨 |
| 続行できない | 理由と、何があれば進めるか |
| PR を作った | 変更の要約とレビューしてほしい点 |

## PR

- push は `-u` 付き（upstream を設定する）
- `GHTKN_APP=write gh pr create ...` で、PR は作業したリポジトリに立てる
- 本文に `Closes <R>#<N>` を書く。Control Room はこの参照で Issue を「レビュー待ち」にし、マージで Issue が閉じると board サーバーが worktree の片付けを行う
- マージは人が行う。自分でマージしない

## 検証が目的の Task（label `spike`）

spike は、Issue に書かれた前提を確かめ、その後の計画に手戻りが出るかを判定する。

- 検証のために書いたコードは作業したブランチに commit してよいが、push と PR はしない（main に入れない）。残す価値のある変更ができたときだけ、通常どおり PR を作る
- 結論が出たら、Issue コメントに次を書く
  - 結論: 手戻りあり / 手戻りなし
  - 根拠: 何を試して何が分かったか
  - 手戻りありなら、影響する Issue と計画の直し方の案
- 結論のラベルを付ける。Control Room はこれで spike を「レビュー待ち」にし、手戻りありなら、この spike に blocked された Task を自動で起動せず「手戻りの確認」にする

  ```sh
  GHTKN_APP=write gh issue edit <N> --repo <R> --add-label spike:rework   # 手戻りなしなら spike:ok
  ```

- 端末に結論を書いてターンを終える。Issue は人が close する

## しないこと

- 担当以外の Issue に触れない、他のワーカーを dispatch しない
- Issue を close しない、PR をマージしない
- カードの status と未読を `orca worktree set` で変えない（status は board、未読は Orca が付ける）、events.jsonl を直接書かない
