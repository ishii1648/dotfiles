---
name: adr-loop
description: This skill should be used when the user wants to "implement an ADR",
  "ADRを実装して", "ADR-012 を実装して", "ADRのループを回して",
  "受け入れ条件を満たすまで実装して", "ADR-012 を完了させて",
  "受け入れ条件を検証して修正して", or provides an ADR number/name to implement.
  Runs the implement→verify→fix loop for a specific ADR until all acceptance
  criteria in docs/issues.md pass.
version: 0.1.0
---

# adr-loop

指定された ADR を読み込み、受け入れ条件をすべて満たすまで「実装 → 検証 → 修正」のループを回す。

## 目的

- ADR に定義された設計を実装し、`docs/issues.md` の受け入れ条件を自動検証する
- 条件未達の場合は修正して再検証することでサイクルを自動化する
- 完了時に ADR・issues.md のステータスを更新してコミットする

## ステップ

### Step 1: ADR の特定

#### args が指定されている場合（例: `ADR-012`、`012`、`12`）

- 番号を3桁にゼロ埋めして `$PWD/docs/adr/NNN-*.md` を Glob で特定する
- 該当ファイルが存在しない場合はエラーを報告して終了する

#### args が空の場合

- `$PWD/docs/adr/*.md` を Glob で全ファイル取得
- 各ファイルを Read して `## ステータス` セクションが `Draft` のものを抽出
- Draft ADR が0件の場合は「実装対象の Draft ADR が見つかりません」と報告して終了
- AskUserQuestion で「実装する ADR を選んでください」と番号・タイトルの一覧を提示

### Step 2: コンテキスト収集（並列実行）

以下を並列で実行する：

- ADR ファイルを Read し、`## コンテキスト`・`## 設計案`・`## 決定` セクションの内容を把握する
- `$PWD/docs/issues.md` を Read して該当 ADR セクション（`ADR-NNN` への言及がある箇所）の受け入れ条件（`- [ ]` 行）を抽出する

受け入れ条件が見つからない場合は AskUserQuestion でユーザーに確認し、必要に応じて `docs/issues.md` に追記するか中断するかを選択させる。

### Step 3: 実装

- `## 決定` が `（未定）` または空の場合は `## 設計案` の内容を実装方針とする
- `## 設計案` に複数の案が列挙されている場合は AskUserQuestion でユーザーに選択させる
- 実装前に受け入れ条件の完了基準を明確化し、何を満たせば完了かを確認する
- ADR の設計案にファイル削除が含まれる場合は、削除対象を設計案から特定して `git rm` を使用する
- 実装は `$PWD` 配下のファイルのみを対象とする

### Step 4: 受け入れ条件の検証ループ

以下のループを受け入れ条件がすべて満たされるまで繰り返す：

1. `docs/issues.md` の対応する受け入れ条件（`- [ ]` 行）を1つずつ検証する
2. 検証方法は条件の文言に応じて決定する
   - ファイルの存在確認: Glob / Read
   - コードの内容確認: Grep / Read
   - 「動作する」「実行できる」「起動する」などの文言を含む条件のみ Bash でテスト実行する
     （ネットワーク通信を伴うコマンドは使用しない: aws, curl, terraform 等）
3. 未達の条件があれば修正して Step 4 の先頭に戻る（最大 5 回まで）
4. 5回試みても未達の条件が残る場合は AskUserQuestion でユーザーに確認する
5. すべての条件が通過したらループ終了

### Step 5: 完了処理

Step 4 のループ完了後にのみ以下を順番に実行する（Step 4 ループ中は一切変更しない）：

1. `$PWD/docs/issues.md` の該当 ADR の `- [ ]` をすべて `- [x]` に更新する
2. `docs/issues.md` のサマリ表で該当 ADR を含む行の「対応済み」列を `-` から `✔` に更新する
   （1行に複数 ADR が記載されている場合は、その行の全 ADR が完了済みのときのみ `✔` に更新する）
3. ADR ファイルの `## ステータス` を `採用済み` に更新する
4. 変更ファイルを `git add` してコミットする

**コミットメッセージ:**
```
feat: ADR-NNN 受け入れ条件を達成
```

（NNN は対象 ADR の番号）

## 制約

- 操作対象は常に `$PWD` 配下（worktree 対応）
- `docs/issues.md` の `- [ ]` → `- [x]` 更新と ADR ステータス更新は Step 5 でのみ行う（Step 4 ループ中は変更しない）
- このリポジトリはリモートなしのため `git commit` までで完了（`git push`・PR 作成は不要）
- `rm -rf` は使用禁止。ファイル削除が必要な場合は `git rm` または `rm`（単体ファイル指定）を使用する
