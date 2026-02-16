# Claude Code ガイドライン
- 設計や作業計画を開始する際に質問がある場合は、AskUserQuestion または EnterPlanMode を使用して
- SubAgentを使ってできるだけ並列化して進めて

## ツール使用ルール
- ファイル検索には Bash の `find` ではなく Glob ツールを使用する
- テキスト検索には Bash の `grep`/`rg` ではなく Grep ツールを使用する
- ファイル読み取りには `cat`/`head`/`tail` ではなく Read ツールを使用する
- ファイル編集には `sed`/`awk` ではなく Edit ツールを使用する
- ファイル作成には `echo`/`cat <<EOF` ではなく Write ツールを使用する

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
- **PRが未作成**: commit → push → Draft PR作成
- **PRが作成済み**: commit → push のみ（既存PRのURLを表示）

## 調査結果のまとめ
- 調査結果をまとめる際に表を使う場合はmarkdownを使うこと
- 調査結果は`.outputs/claude/`に出力すること（global gitignoreで除外済み）
- 日本語で記載すること
