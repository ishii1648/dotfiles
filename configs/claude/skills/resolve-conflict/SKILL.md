---
name: resolve-conflict
description: PRのconflictをrebaseで解消する。conflict検出、rebase実行、手動解消、ビルド・テスト検証、force pushまでを自動化する。「conflict解消して」「rebaseして」「PRがconflictしてる」と言われた時に使用する。
user_invocable: true
---

# Resolve Conflict - Rebaseによるconflict解消

## 概要

PRブランチをrebaseしてconflictを解消する。merge commitを作らずクリーンな履歴を維持する。

## ワークフロー

### 1. 状態確認

```bash
# 現在のブランチとPR状態を確認
git branch --show-current
gh pr view --json mergeable,mergeStateStatus,baseRefName,headRefName

# ベースブランチの最新を取得
git fetch origin <baseRefName>
```

- `mergeable: CONFLICTING` であることを確認
- 作業ツリーがcleanであることを確認（未コミット変更がある場合は先にcommit or stash）

### 2. mainとの差分確認

```bash
# mainに入った新しいコミットを確認
git log --oneline <分岐点>..origin/main

# conflictが予想されるファイルを事前確認
git diff --name-only origin/main...HEAD
```

### 3. Rebase実行

```bash
git rebase origin/main
```

conflictが発生した場合、以下のメッセージが表示される:
```
CONFLICT (content): Merge conflict in <file>
```

### 4. Conflict解消

各conflictファイルに対して:

1. **ファイルを読む** - `Read`ツールでconflictマーカーを含むファイル全体を確認
2. **両方の変更を理解する**:
   - `<<<<<<< HEAD` ~ `=======`: ベースブランチ（main）の変更
   - `=======` ~ `>>>>>>> <commit>`: 自分のブランチの変更
3. **解消方針を決定**:
   - 両方の変更が独立 → 両方を統合（最も一般的）
   - 同じ箇所の競合 → 意図を理解して正しい方を選択 or マージ
4. **`Edit`ツールでconflictマーカーを含むブロック全体を置換**

### 5. ビルド・テスト検証

```bash
# ビルド確認
make build

# テスト実行
make test
```

- 失敗した場合はrebase中のまま修正を続ける
- **rebase中は新しいcommitを作らない**（`git add` + `git rebase --continue`で進める）

### 6. Rebase完了

```bash
# 解消したファイルをステージング
git add <resolved-files>

# rebaseを続行
git rebase --continue
```

複数コミットでconflictがある場合、各コミットで手順4-6を繰り返す。

### 7. Force Push

```bash
# rebase後はforce pushが必要（--force-with-leaseで安全に）
git push --force-with-lease origin <branch-name>
```

## 注意事項

- **必ず`--force-with-lease`を使う**（`--force`は他人のpushを上書きするリスクがある）
- rebase中に問題が発生したら `git rebase --abort` で元に戻せる
- conflictが多すぎる場合はユーザーに相談する

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| conflictなし | "Already up to date" で正常終了 |
| 未コミット変更あり | stash or commitを促す |
| テスト失敗 | rebase中のまま修正、`git add` + `git rebase --continue` |
| rebase中断したい | `git rebase --abort` で元に戻す |
