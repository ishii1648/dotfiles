# ADR-056: dispatch/orchestrate popup ランチャー

## ステータス
廃止（ADR-069 で置換）

> popup ランチャーの起動 UI 自体が `tmux-sidebar new`（upstream の `internal/picker`）に移管された。`dispatch_launcher.fish` および関連 helper (`__dl_*`) は ADR-069 採用時に `git rm` され、本 ADR のすべての決定（Step 1/2 の UI 設計、claude モード時の dispatch/orchestrate 切替、`bind S` 経路）は無効化された。Step 2 の dispatch ↔ orchestrate トグルは upstream picker に存在しないため、orchestrate を起動したい場合は claude session を `tmux-sidebar new` で開いてから `/orchestrate` skill を呼ぶ運用に変わった。

## 関連 ADR
- 依存: ADR-054（dispatch skill — ランチャーが呼び出すエントリポイント）
- 依存: ADR-059（dispatch/orchestrate 分離 — ランチャーが両方をサポート）
- 関連: ADR-051（tmux-sidebar — 監視 UI。本 ADR のスコープ外）
- Superseded by (部分): ADR-061（Step 1 を claude/codex モードに再構成）

## コンテキスト

現在、dispatch / orchestrate の起動はターミナルで直接 `/dispatch "..."` や `/orchestrate "..."` を入力する必要がある。リポジトリの選択、実行モード（dispatch vs orchestrate）の判断、prompt の入力が分散しており、起動の手間が大きい。

別途 `cmd+shift+s` → `tmw_pick` によるリポジトリ選択 popup が存在するが、これは tmux session の作成・切替のみで dispatch/orchestrate との連携がない。

当初は tmux-sidebar にこの操作系を統合する案（sidebar 内の `n` キー → popup）を検討したが、以下の理由で分離する:

- sidebar は active session の監視・移動に特化しており、操作起動は責務外
- sidebar と popup は表示領域が完全に別（ペイン vs popup）
- popup ランチャーは Go バイナリでなくても実装可能（fish + fzf 等）
- tmux-sidebar のリネーム（tmux-hub）も不要になる

### 設計判断

dispatch/orchestrate の起動 UI を **独立した popup ランチャー** として実装する。tmux-sidebar は現状のまま監視 UI に専念し、ghq 統合も行わない。

`tmw_pick` popup は廃止し、popup ランチャーに置き換える。

## 設計

### キーバインド

| キー | 動作 |
|---|---|
| `cmd+s` | tmux-sidebar トグル（既存・変更なし） |
| `cmd+shift+s` | popup ランチャーを開く（新規。旧 `tmw_pick` を置換） |

### popup ランチャー（2段階フロー）

**Step 1: リポジトリ選択（fzf）**

```
┌─────────────────────────────┐
│  repo >                     │
│─────────────────────────────│
│  ▶ dotfiles                 │
│    dotfiles-private         │
│    sandbox-ishii1648        │
└─────────────────────────────┘
```

- ghq リポジトリ一覧を fzf でフィルタ選択（worktree ディレクトリは除外）
- リポジトリ選択 + `Enter` で Step 2 に遷移

**Step 2: タスク記述 + モード切替（fish read）**

```
  tab: モード切替  enter: 実行
  dispatch / orchestrate  dotfiles
  ─────────────────────────────
  > タスク記述を入力...
```

- `tab` で dispatch / orchestrate を切替（アクティブなモードがハイライト表示）
- タスク記述を入力して `Enter` で実行
- fish の `read -p` で動的 prompt を使用し、`tab` キーバインドで `commandline -f repaint` を呼ぶことで即時反映

### 実行フロー

1. `cmd+shift+s` で Step 1 popup 表示
2. リポジトリをフィルタ選択
3. `Enter` で Step 2 に遷移
4. タスク記述入力 + `tab` で dispatch/orchestrate 切替
5. `Enter` で実行:
   - tmux ステータスバーに `{mode}: {repo} ... launching` を表示
   - dispatch: `dispatch.sh launch` で worktree 作成 + claude 起動 → 新 session に自動切替
   - orchestrate: tmux session 作成 → claude に `/orchestrate` を投入 → session に自動切替

### 実装方針

popup ランチャーは Go バイナリに依存しない軽量な実装を優先する。fish スクリプト（`dispatch_launcher.fish`）+ fzf で実装。

### 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/fish/functions/dispatch_launcher.fish`（新規） | リポジトリ選択 + dispatch/orchestrate 切替 + タスク記述入力 + 実行 |
| `configs/tmux/tmux.conf` | `bind S` を `dispatch_launcher` に変更（`tmw_pick` binding 削除） |
| `configs/fish/functions/tmw_pick.fish` | 廃止（`git rm`） |
| `configs/fish/functions/__tmw_candidates.fish` | 廃止（`git rm`、`tmw_pick` 専用だったため） |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-056 セクション）

## 実装 Issue
- ishii1648/tmux-sidebar#2 — close 済み（tmux-sidebar から分離したため）
- dotfiles 側の実装 issue は未作成
