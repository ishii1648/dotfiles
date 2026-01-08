# PR And Cleanup - Reference

## コマンドライン引数

| 引数 | 説明 | デフォルト |
|------|------|------------|
| `--pr-only` | PR作成のみ（worktree削除なし） | false |
| `--cleanup-only` | worktreeクリーンアップのみ | false |
| `--title <title>` | PRタイトル | インタラクティブ入力 |
| `--body <body>` | PR本文 | インタラクティブ入力 |
| `--base <branch>` | ベースブランチ | main |
| `--draft` | ドラフトPRとして作成 | false |
| `--force` | 未コミット変更があっても続行 | false（非推奨） |
| `--help` | ヘルプメッセージを表示 | - |

## 内部処理フロー

### 1. 環境検証フェーズ
```bash
1. worktreeディレクトリ内かチェック
   - git rev-parse --git-dir で .git/worktrees/<name> を確認
2. 現在のブランチ名取得
   - git branch --show-current
3. リポジトリルート取得
   - git rev-parse --show-toplevel
4. worktreeパス算出
   - pwd で現在ディレクトリ取得
```

### 2. 変更チェックフェーズ
```bash
1. 未コミット変更チェック
   - git status --porcelain
   - 出力が空でなければエラー
2. push状態チェック
   - git rev-list origin/<branch>..HEAD
   - unpushedコミットがあれば警告（継続可能）
```

### 3. PR作成フェーズ
```bash
1. gh pr create 実行
   - --title / --body 指定がなければインタラクティブ
   - --base でベースブランチ指定（デフォルト: main）
2. PR URL取得
   - gh pr view --json url -q .url
3. 成功確認
   - 終了コード 0 を確認
```

### 4. クリーンアップフェーズ
```bash
1. リポジトリルートに移動
   - cd $REPO_ROOT
2. worktree削除
   - git worktree remove <worktree-path>
3. mainブランチにチェックアウト
   - git checkout main
4. 完了メッセージ表示
```

## エラーハンドリング戦略

### レベル1: 即座に中断（CRITICAL）
- worktree外で実行
- git リポジトリでない
- 未コミットの変更がある（--force 未指定時）
- gh CLI が未インストール
- --pr-only と --cleanup-only を同時指定

### レベル2: 警告して継続（WARNING）
- リモートブランチと差分がある（unpushed commits）
- リモートブランチが存在しない

### レベル3: ロールバック（ROLLBACK）
- PR作成失敗時: worktree削除をスキップ
- worktree削除失敗時: 手動削除方法を表示

## 使用例

### ケース1: 基本的な使い方
```bash
cd .worktrees/feature-x
bash ../../.claude/skills/pr-and-cleanup/scripts/pr_and_cleanup.sh
# → PR作成（インタラクティブ） → worktree削除 → mainに戻る
```

### ケース2: タイトル・本文を事前指定
```bash
bash ../../.claude/skills/pr-and-cleanup/scripts/pr_and_cleanup.sh \
  --title "feat(frontend): Add user authentication" \
  --body "Implements Firebase Auth integration"
```

### ケース3: ドラフトPR作成
```bash
bash ../../.claude/skills/pr-and-cleanup/scripts/pr_and_cleanup.sh --draft
```

### ケース4: PR作成のみ（worktree保持）
```bash
bash ../../.claude/skills/pr-and-cleanup/scripts/pr_and_cleanup.sh --pr-only
# → PR作成のみ、worktreeは残る
```

### ケース5: クリーンアップのみ（PR作成済み）
```bash
# 別の方法でPR作成済みの場合
bash ../../.claude/skills/pr-and-cleanup/scripts/pr_and_cleanup.sh --cleanup-only
# → worktree削除のみ
```

### ケース6: カスタムベースブランチ
```bash
# develop ブランチにPR作成
bash ../../.claude/skills/pr-and-cleanup/scripts/pr_and_cleanup.sh --base develop
```

### ケース7: 未コミット変更を無視（非推奨）
```bash
# 緊急時のみ使用
bash ../../.claude/skills/pr-and-cleanup/scripts/pr_and_cleanup.sh --force
```

## トラブルシューティング

### Q: 未コミットの変更があると言われる
```bash
# 変更を確認
git status

# コミットする
git add .
git commit -m "commit message"

# または stash
git stash
```

### Q: PR作成は成功したがworktree削除に失敗
```bash
# 手動でworktreeを削除
cd /path/to/repo-root
git worktree remove .worktrees/<feature-name>

# 強制削除
git worktree remove --force .worktrees/<feature-name>
```

### Q: worktree外で実行してしまった
```bash
# worktreeディレクトリに移動
cd .worktrees/<feature-name>

# 再実行
bash ../../.claude/skills/pr-and-cleanup/scripts/pr_and_cleanup.sh
```

### Q: gh CLI の認証が必要と言われる
```bash
# GitHub CLIの認証
gh auth login

# 認証状態確認
gh auth status
```

### Q: ローカルブランチも削除したい
```bash
# PR作成・worktree削除後、手動でブランチ削除
git branch -d feature/<name>

# または clean_gone スキルを使用（マージ済みブランチ一括削除）
# /clean_gone
```

### Q: リモートブランチも削除したい
```bash
# GitHub上で「Automatically delete head branches」を有効化
# Settings → General → Pull Requests → チェック

# または手動削除
git push origin --delete feature/<name>
```

### Q: ベースブランチが main でない場合
```bash
# --base オプションでベースブランチ指定
bash pr_and_cleanup.sh --base develop
bash pr_and_cleanup.sh --base master
```

### Q: PR作成時にエラーが出る
```bash
# gh CLI のバージョン確認
gh --version

# 最新版にアップデート
# macOS: brew upgrade gh
# Linux: apt update && apt upgrade gh

# リポジトリのリモート確認
git remote -v

# リモートが正しく設定されているか確認
gh repo view
```

## ベストプラクティス

### 1. 定期的なworktreeクリーンアップ
- PR作成後は必ずworktreeを削除
- 不要なディスク使用を避ける
- `.worktrees/` ディレクトリを定期的に確認

### 2. ブランチ削除タイミング
- **ローカルブランチ**: PRマージ後に手動削除またはclean_goneスキル使用
- **リモートブランチ**: GitHub設定で自動削除を有効化推奨

### 3. worktree命名規則
- create-worktree で作成したものと統一
- `.worktrees/<feature-name>` 形式を推奨

### 4. コミットメッセージ
- Conventional Commits 形式を推奨
- PR作成前に `git log` で確認
- 例: `feat(frontend): add feature`, `fix(backend): fix bug`

### 5. PR作成前のチェックリスト
- [ ] すべての変更がコミット済み
- [ ] テストが通っている
- [ ] リンター/フォーマッターが通っている
- [ ] コミットメッセージがConventional Commits形式
- [ ] PRタイトル・本文を準備済み

### 6. worktree開発の推奨フロー
```bash
# 1. worktree作成
bash .claude/skills/create-worktree/scripts/create_worktree.sh feature-name

# 2. 開発作業
cd .worktrees/feature-name
# 開発・テスト・コミット

# 3. push（オプション、gh pr createが自動pushする）
git push origin feature/feature-name

# 4. PR作成＆クリーンアップ
bash ../../.claude/skills/pr-and-cleanup/scripts/pr_and_cleanup.sh

# 5. PRマージ後のクリーンアップ（オプション）
# /clean_gone
```

## セキュリティ考慮事項

### コマンドインジェクション対策
- ユーザー入力は適切にクォートで保護
- eval実行時は安全性を確保

### 機密情報の露出防止
- PR本文に環境変数やトークンを含めない
- ログ出力に機密情報を含めない

## パフォーマンス

### 処理時間の目安
- 環境検証: < 1秒
- 変更チェック: < 1秒
- PR作成: 2-5秒（ネットワーク次第）
- worktree削除: < 1秒
- 合計: 通常5-10秒程度

### 大規模リポジトリでの注意点
- `git status` は通常高速だが、数万ファイルある場合は数秒かかる可能性
- worktree削除は O(1) 処理で高速

## 関連ドキュメント

- [SKILL.md](SKILL.md) - 基本的な使い方
- [create-worktree スキル](../create-worktree/SKILL.md) - worktree作成
- [AGENTS.md](../../../AGENTS.md) - プロジェクト開発ガイドライン
- [GitHub CLI Documentation](https://cli.github.com/manual/) - gh コマンドリファレンス
- [Git Worktree Documentation](https://git-scm.com/docs/git-worktree) - git worktree公式ドキュメント
