# Worktree Creator - Reference

## Git Worktreeとは

Git worktreeは、同一リポジトリで複数のブランチを**同時にチェックアウト**できる機能です。

### ディレクトリ構成例

```
project/                      # メインworktree (mainブランチ)
├── .worktrees/
│   ├── user-auth/             # feature/user-auth ブランチ
│   └── dashboard-redesign/    # feature/dashboard-redesign ブランチ
```

## よくあるユースケース

### 1. 複数機能の並行開発

planモードで複数の機能を計画した場合、それぞれのworktreeで並列開発が可能。

```bash
# 機能A用のworktree
bash .claude/skills/create-worktree/scripts/create_worktree.sh feature-a

# 機能B用のworktree（別ターミナルで）
bash .claude/skills/create-worktree/scripts/create_worktree.sh feature-b
```

### 2. ホットフィックス

メイン開発を中断せずに緊急修正が可能。

```bash
bash .claude/skills/create-worktree/scripts/create_worktree.sh hotfix-critical-bug
```

### 3. PRレビュー

自分の作業を中断せずに他のPRを確認。

```bash
git worktree add .worktrees/review-pr-123 origin/feature/some-pr
```

## Git Worktreeコマンドリファレンス

### worktree一覧表示

```bash
git worktree list
```

### worktree追加（既存ブランチ）

```bash
git worktree add <path> <branch>
```

### worktree追加（新規ブランチ）

```bash
git worktree add -b <new-branch> <path> <start-point>
```

### worktree削除

```bash
git worktree remove <worktree-path>
```

### worktree修復（ロック状態から復帰）

```bash
git worktree repair
```

### 強制削除（未コミットの変更がある場合）

```bash
git worktree remove --force <worktree-path>
```

## トラブルシューティング

### worktreeが既に存在する場合

```bash
# 状態確認
git worktree list

# 削除
git worktree remove .worktrees/<feature-name>

# 強制削除
rm -rf .worktrees/<feature-name>
git worktree prune
```

### 環境変数ファイルをコピーし忘れた場合

```bash
# ルートから手動コピー
cp .env .worktrees/<feature-name>/
cp modules/backend/.env .worktrees/<feature-name>/modules/backend/
```

### ブランチが既に存在する場合

スクリプトは既存のブランチを使用してworktreeを作成します。
新規ブランチを作成したい場合は、まず既存ブランチを削除してください。

```bash
git branch -d feature/<feature-name>
```

### worktreeがロックされている場合

```bash
git worktree unlock .worktrees/<feature-name>
```

## ベストプラクティス

### 1. 命名規則

- 機能: `feature-<name>`
- バグ修正: `fix-<name>`
- ホットフィックス: `hotfix-<name>`
- リファクタリング: `refactor-<name>`

### 2. 作業完了後のクリーンアップ

PRがマージされたら、worktreeとブランチを削除：

```bash
# worktree削除
git worktree remove .worktrees/<feature-name>

# ブランチ削除（リモートで削除済みの場合）
git branch -d feature/<feature-name>
```

### 3. 定期的なpruning

不要なworktree参照を削除：

```bash
git worktree prune
```

## 環境変数ファイル一覧

このプロジェクトでコピーされる環境変数ファイル：

| パス | 説明 |
|------|------|
| `.env` | ルートレベルの環境変数 |
| `.envrc` | direnv設定 |
| `modules/frontend/.env` | フロントエンド基本設定 |
| `modules/frontend/.env.local` | ローカル開発用 |
| `modules/frontend/.env.dev` | 開発環境用 |
| `modules/frontend/.env.prd` | 本番環境用 |
| `modules/frontend/.env.test` | テスト用 |
| `modules/backend/.env` | バックエンド設定 |
| `modules/agent/.env` | AIエージェント設定 |

## 関連ドキュメント

- [Git Worktree公式ドキュメント](https://git-scm.com/docs/git-worktree)
- [AGENTS.md](../../../AGENTS.md) - プロジェクト開発ガイドライン
