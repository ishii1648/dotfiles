# ADR-056: dispatch/orchestrate popup ランチャー

## ステータス
採用済み（改訂: 2026-04-13）

## 関連 ADR
- 依存: ADR-054（dispatch skill — ランチャーが呼び出すエントリポイント）
- 依存: ADR-059（dispatch/orchestrate 分離 — ランチャーが両方をサポート）
- 関連: ADR-051（tmux-sidebar — 監視 UI。本 ADR のスコープ外）

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

入力エリアがリポジトリフィルタとタスク記述で競合するため、2段階の popup で構成する:

**Step 1: リポジトリ選択 popup**

```
┌─────────────────────────────────────────┐
│  [dispatch] [orchestrate]       j/k 切替│
│─────────────────────────────────────────│
│  > dotf                          filter │
│─────────────────────────────────────────│
│  ▶ dotfiles                             │
│    dotfiles-private                     │
└─────────────────────────────────────────┘
```

- ghq リポジトリ一覧を fzf スタイルでフィルタ選択
- `j`/`k` で dispatch / orchestrate を切替（デフォルト: dispatch）
- リポジトリ選択 + `Enter` で Step 2 に遷移

**Step 2: タスク記述 popup**

```
┌─────────────────────────────────────────┐
│  dispatch > dotfiles                    │
│─────────────────────────────────────────│
│  > タスク記述を入力...                  │
│                                         │
└─────────────────────────────────────────┘
```

- 選択済みのリポジトリとモードをヘッダに表示
- タスク記述を入力して `Enter` で実行
- `/dispatch --repo <repo> "<prompt>"` または `/orchestrate --repo <repo> "<prompt>"` を実行

フロー:
1. `cmd+shift+s` で Step 1 popup 表示
2. リポジトリをフィルタ選択 + dispatch/orchestrate 切替
3. `Enter` で Step 2 popup に遷移
4. タスク記述入力 + `Enter` で実行

### 実装方針

popup ランチャーは Go バイナリに依存しない軽量な実装を優先する。fish スクリプト + fzf、または単純なシェルスクリプトで十分。

### 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| popup ランチャースクリプト（新規） | ghq リポジトリ選択 + dispatch/orchestrate 切替 + prompt 入力 |
| `configs/tmux/tmux.conf` | `cmd+shift+s` を popup ランチャーに変更（`tmw_pick` binding 削除） |
| `configs/fish/functions/tmw_pick.fish` | 廃止 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-056 セクション）

## 実装 Issue
- ishii1648/tmux-sidebar#2 — close 済み（tmux-sidebar から分離したため）
- dotfiles 側の実装 issue は未作成
