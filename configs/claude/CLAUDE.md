# Claude Code ガイドライン
- 設計や作業計画を開始する際に質問がある場合は、AskUserQuestion または EnterPlanMode を使用して
- SubAgentを使ってできるだけ並列化して進めて
- ユーザが意見を求めた場合、忖度せず批判的に検討したうえで回答すること

## 自律性の原則
複雑な Bash（ループ・パイプ・インラインスクリプト）を実行せず、専用ツールか個別コマンドに分解すること。

- ファイル操作: `Glob` / `Grep` / `Read` / `Edit` / `Write`
- 調査・探索: `Task`（subagent_type=Explore）
- ループ処理: `for`/`while` の代わりに Glob で列挙して個別ツールを呼ぶ
- データ変換: `python3 -c` / `awk` の代わりに `jq` または専用ツール

## 禁止コマンド
- `rm -rf` は絶対に実行しない。ファイル/ディレクトリの削除が必要な場合は `git rm` や `rm`（単体ファイル指定）を使用する

## ネットワーク通信を伴うツールの例外
- coderabbitはネットワーク通信を伴うが実行してOK

## 実装完了時の自動Git操作
タスク完了時に以下の条件を**すべて**満たす場合、`git-ship` skill を自動実行する：

### 実行条件
1. 未コミットの変更がある（git status で変更が検出される）
2. feature/fix/docs/chore ブランチ上にいる（main/master ではない）
3. 操作対象は常に`$PWD`配下であることを確認してから実行する

### 動作
- PRが未作成の場合: commit → push → Draft PR作成
- PRが作成済みの場合: commit → push のみ（既存PRのURLを表示）


## スキル作成・検証
- スキルを新規作成する際は `plugin-dev:skill-development` スキルを使用する
- スキル作成・更新後の品質検証には `plugin-dev:skill-reviewer` エージェント（Task ツール経由）を使用する

## textlint 自動チェック

`.md` ファイルを Write または Edit ツールで変更した後は、`textlint` スキルを自動実行すること。
ただし、スキル・サブエージェント・forked コンテキスト内では実行しない。

## 調査結果のまとめ
- 調査結果をまとめる際に表を使う場合はmarkdownを使うこと
- 調査結果は`.outputs/claude/`に出力すること（global gitignoreで除外済み）
- 日本語で記載すること
