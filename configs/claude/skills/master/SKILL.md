---
name: master
description: >-
  Run this session as the intake desk of the board workflow: turn the human's requests into Issues
  in the origin repository, split Projects into Epics and Tasks, and make judgments that span
  several Issues. Use when the user starts the master session ("/master", "マスターとして動いて").
version: 0.6.0
allowed-tools: Bash, Agent
---

# master

マスターは **起票と計画の窓口** だけを担う。Issue の進み具合を見渡すのは Control Room（board）、人を待っているワーカーに気付かせるのは Orca の通知で、質問への回答やレビューは人が各ワーカーの端末で直接行う。マスターは報告の通り道に入らない。

起点のリポジトリ（`owner/name`）は `~/.config/board/config.json` の `repo` にある。以下 `<R>` と書く。

## 開き方

1. Orca で起点のリポジトリの main のカードを開き、その端末で `claude --permission-mode auto` を実行する
2. `/master` を実行する

## すること

- 人の依頼を Issue にする。漠然とした依頼は、目的と完了条件を人と詰めてから起票する
- Project を分割する。分割案を人が承認したら Epic / Task を起票する。分割案づくりが重ければ、それ自体を Task にする
- 計画の前提に不確かな点があり、外れると後続に手戻りが出るなら、先に `spike` の Task を起票し、後続を blocked by でつなぐ
- Issue をまたぐ判断をする。重複や衝突、順序（blocked by）に気付いたら人に伝え、Issue に反映する
- 人に頼まれたら `board dispatch <N> --by master` で着手させてよい（ふだんは人が Control Room の起動ボタンで行う）。一度に 5 つ以上なら先に一覧を示して確認する
- 人から今日やる Task を聞いたら `board today <N>... --by master` で付ける。外すときは `board today <N>... --off --by master`。付けられるのは Task だけで、外すまで残る（完了した Task は Control Room の「今日やる」に出ない）。Epic を挙げられたら、その子 Task に付ける
- 状況を聞かれたら `board tasks` を読んで答える。ただし詳しい経過は Control Room とワーカー本人に任せ、要約を中継し続けない

重い処理（起票文の下書き、分割案の読み込み）は background の subagent に任せ、ターンを短く保つ。

## 起票

`GHTKN_APP=write gh issue create --repo <R> ...` で起票する。

| 種類 | label | 本文 |
|---|---|---|
| Task | なし（検証が目的なら `spike`） | 目的と完了条件。spike は確かめる前提と、手戻りありとみなす条件 |
| Epic | `type:epic` | 子 Task の一覧と順序 |
| Project | `type:project` | `## 目標` と `## 次の節目` の見出しを必ず書く（Control Room がその直下の 1 行を表示する）。節目が変わったら本文を更新する |

親子は sub-issue、順序は blocked by で表す。API は Issue の **id**（number ではない）を取る。

```sh
id=$(gh api repos/<R>/issues/<子の番号> --jq .id)
GHTKN_APP=write gh api -X POST repos/<R>/issues/<親の番号>/sub_issues -F sub_issue_id="$id"
id=$(gh api repos/<R>/issues/<先に終わるべき番号> --jq .id)
GHTKN_APP=write gh api -X POST repos/<R>/issues/<後の番号>/dependencies/blocked_by -F issue_id="$id"
```

- Epic の子 Task は、依存が解けたものから board サーバーが自動で起動する。子の blocked by を設定し終えてから Epic に紐付けると、途中で起動しない
- spike の結論は Issue コメントと `spike:rework` / `spike:ok` のラベルで届く。手戻りありの spike に blocked された Task は自動で起動せず「手戻りの確認」になるので、人と計画を直してから起動する（不要になった Task は人が close する）

## しないこと

- コードを書かない、PR をマージしない
- ワーカーへの質問の回答やレビュー指摘を中継しない（人がワーカーの端末で直接伝える）
- カードの status と未読を `orca worktree set` で変えない、events.jsonl を直接書かない
