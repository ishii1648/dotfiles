---
name: git-ship
description: Automates git workflow from commits to draft PR creation. Use when implementation is complete and uncommitted changes exist on a feature/fix/docs/chore branch. Triggers on "ship changes", "create PR", or "/git-ship".
version: 0.1.0
allowed-tools: Read, Grep, Bash
argument-hint: "[--no-draft] [--no-pr] [--base branch-name] [commit message]"
---

# Git Ship - 自動Git ワークフロー

## 概要

未コミットの変更からPR作成までを自動化するスキル。ブランチ管理、コミット作成、リモートへのプッシュ、ドラフトPR作成を一連のフローで処理する。

**このリポジトリでは、PR説明は日本語で記述される。**

## ワークフロー手順

### 1. 事前チェック

以下のコマンドを実行して状態を確認する：

```bash
# 未コミットの変更を確認
git status
```

- 変更がない場合: "Nothing to commit" で終了
- PRテンプレートの存在確認: `.github/pull_request_template.md` または `.github/PULL_REQUEST_TEMPLATE.md`
- PR作成時にテンプレートがない場合: テンプレート作成を要求して停止

### 2. ブランチ管理

現在のブランチを確認し、必要に応じて新規作成：

```bash
# 現在のブランチを取得
git branch --show-current
```

**mainブランチにいる場合（未コミット変更あり）:**

```bash
# 以下の順序で実行
git stash --include-untracked    # 変更を退避
git pull origin main              # 最新を取得
git switch -c <branch-name>       # 新ブランチ作成
git stash pop                     # 変更を復元
```

ブランチ名のプレフィックス規則:
- `feat/` - 新機能
- `fix/` - バグ修正
- `docs/` - ドキュメントのみ
- `chore/` - メンテナンスタスク

**feature/fix/docs/chore ブランチにいる場合:**
- 現在のブランチを継続（新規作成しない）

### 3. 変更をコミット

```bash
# 全変更をステージング
git add -A

# コミット作成（conventional commits形式）
git commit -m "type: description"
```

コミットメッセージは提供されたものを使用するか、変更内容から生成する。

### 4. リモートにプッシュ

```bash
# 新ブランチをプッシュ
git push -u origin <branch-name>
```

### 5. Pull Request作成（--no-pr でない場合）

#### 5a. 既存PRの確認

```bash
# 既存PRの有無を確認
gh pr view --json number,url,state 2>/dev/null
```

- **PRが存在する場合（終了コード0）**: "Pushed to existing PR: {url}" を表示し、PR作成をスキップ
- **PRが存在しない場合（終了コード1）**: 5b へ進む

#### 5b. 新規PR作成

```bash
# ドラフトPRを作成（デフォルト）
gh pr create --draft --title "タイトル" --body "説明"

# --no-draft オプションの場合はレビュー準備完了として作成
gh pr create --title "タイトル" --body "説明"
```

PRテンプレートに以下を日本語で記入:
- コミットメッセージからのサマリー
- 変更ファイル一覧
- テストファイルが変更された場合はテストケース

### 6. ラベル追加（組織リポジトリの場合）

組織リポジトリの場合、`ai-contribution-level:3` ラベルを付与する:

```bash
# リポジトリの所有者タイプを確認
OWNER_TYPE=$(gh repo view --json owner -q '.owner.type')

# Organization の場合のみラベルを付与
if [ "$OWNER_TYPE" = "Organization" ]; then
  gh pr edit <PR-NUMBER> --add-label "ai-contribution-level:3"
fi
```

## 引数

| 引数 | 説明 |
|------|------|
| `--no-draft` | レビュー準備完了としてPRを作成（デフォルトはドラフト） |
| `--no-pr` | PR作成をスキップし、コミット・プッシュのみ |
| `--base <branch>` | PRのターゲットブランチを指定 |
| `"message"` | カスタムコミットメッセージ |

## 使用例

```bash
/git-ship                     # フル自動化（ドラフトPR作成）
/git-ship --no-draft          # レビュー準備完了のPRを作成
/git-ship --no-pr             # コミット・プッシュのみ
/git-ship "fix: urgent bug"   # カスタムコミットメッセージ
```

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| 変更なし | "Nothing to commit" で正常終了 |
| テンプレートなし | PR作成を停止し、テンプレート作成を要求 |
| プッシュ失敗 | リモート設定を確認するようメッセージ表示 |
| PR既存 | 既存PRのリンクを表示 |

## ベストプラクティス

- 変更をshipする前に必ずテストを実行する
- 「なぜ」を説明する意味のあるコミットメッセージを使用する
- 最終確定前に生成されたPR説明をレビューする
