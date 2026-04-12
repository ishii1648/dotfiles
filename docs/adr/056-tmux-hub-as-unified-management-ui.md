# ADR-056: tmux-hub を並列作業の監視・操作ハブとして使用する

## ステータス
採用済み（改訂: 2026-04-12）

## 関連 ADR
- 依存: ADR-051（Go 製 tmux-sidebar ツール — 実装基盤。tmux-hub にリネーム予定）
- 依存: ADR-053（全 worktree 横断状態集約 — tmux-hub に表示するデータ）
- 依存: ADR-054（dispatch skill — tmux-hub から呼び出すエントリポイント）
- Supersedes: 初版（tmux-sidebar を管理 UI とする設計 — ツール名・責務を再定義）

## コンテキスト

ADR-051 で Go 製 tmux-sidebar ツールを開発中。当初は「全セッションのウィンドウ一覧表示 + Enter で移動」という監視 UI だったが、dispatch 起動・cleanup など操作系の責務が加わり、"sidebar" という名前が実態と乖離してきた。

操作系は tmux popup に委譲するため、sidebar ペイン自体は状態モニター + セレクターにとどまる。ツール全体としては「監視（sidebar ペイン） + 操作（popup）」の 2 層構造で並列作業を一元管理するハブである。

これを反映し、ツール名を **tmux-hub** にリネームする（リポジトリ・バイナリ・設定参照の変更は段階的に実施）。

### 現在の実装状況（tmux-sidebar）

bubbletea + lipgloss による Go 製 TUI。現在の表示フォーマット:

```
● Sessions
[All] [Waiting]
─────────────────────────
dotfiles
  0: main 🔄3m #42
  1: editor 💬
infra
  ▶ 2: deploy

Tab:filter  ^C:quit
```

- セッション名 → 配下にウィンドウを `N: name badge PR` 形式でインデント表示
- 状態バッジ: 🔄Nm（実行中・経過分数）、💬（permission/ask 待ち）
- PR バッジ: `#N`（draft=灰、open=緑、merged=マゼンタ）
- フィルター: All / Waiting（permission or ask 状態のみ抽出）
- キーバインド: j/k 移動、Enter でウィンドウ切替、Tab でフィルタ切替
- データソース: active tmux session のみ（ghq 統合なし）
- Claude Code 状態: `/tmp/claude-pane-state/` の状態ファイルと連携

### 設計判断

tmux-hub の責務を「監視」と「操作」に明確に分離する:

- **sidebar ペイン** (`cmd+s`): 状態モニター + セッションナビゲーション（既存機能の拡張）
- **popup ランチャー** (`cmd+shift+s`): dispatch / orchestrate の起動 UI（新規）

sidebar からの操作起動（旧 `n` キー）は廃止し、popup ランチャーに一本化する。sidebar は ghq 統合による未起動 repo 表示を追加するが、操作系は持たない。

`tmw_pick` popup は廃止し、popup ランチャーに置き換える。

## 設計

### UI 構造

| レイヤー | キーバインド | 実装 | 責務 |
|---|---|---|---|
| sidebar ペイン | `cmd+s` | tmux-hub が常駐描画 | 状態モニター + セッション移動 |
| popup ランチャー | `cmd+shift+s` | tmux-hub が `display-popup` で起動 | dispatch / orchestrate の起動 |

### sidebar ペイン（監視）

現在の「セッション → ウィンドウ」ツリー表示を拡張し、ghq 管理リポジトリをマージする:

```
● Sessions
[All] [Waiting]
─────────────────────────
dotfiles                          # active session
  0: main 🔄3m #42
  1: editor 💬
dotfiles@auth-fix                 # dispatch worktree session
  0: main 🔄12m
infra                             # active session
  ▶ 0: deploy
tmux-hub                 —        # 未起動 repo（ghq のみ）
myapp                    —        # 未起動 repo（ghq のみ）
```

- active session: 既存の表示（ウィンドウツリー + バッジ + PR）
- 未起動 repo: セッション名レベルのみ表示、`—` マークで区別
- `Enter`: active session は switch-client で移動（既存）/ 未起動 repo は session 作成 + 移動（新規）
- `d`: 選択中の dispatch session を cleanup（`/dispatch cleanup <session-id>` 相当）

### popup ランチャー（操作）

`cmd+shift+s` で tmux popup を表示し、dispatch / orchestrate を起動する:

```
┌─────────────────────────────────────────┐
│  [dispatch] [orchestrate]       j/k 切替│
│─────────────────────────────────────────│
│  ▶ dotfiles                             │
│    tmux-hub                             │
│    myapp                                │
│    infra                                │
│─────────────────────────────────────────│
│  > タスク記述を入力...                  │
└─────────────────────────────────────────┘
```

フロー:
1. `cmd+shift+s` で popup 表示
2. ghq 管理リポジトリ一覧を表示。`j`/`k` で dispatch / orchestrate を切替（デフォルト: dispatch）
3. リポジトリ選択 + `Enter` で入力欄にフォーカス移動
4. prompt 入力 + `Enter` で `/dispatch --repo <repo> "<prompt>"` または `/orchestrate --repo <repo> "<prompt>"` を実行

### リネーム計画

| 対象 | 変更内容 | タイミング |
|---|---|---|
| GitHub リポジトリ | `ishii1648/tmux-sidebar` → `ishii1648/tmux-hub` | ADR-056 の実装開始時 |
| バイナリ名 | `tmux-sidebar` → `tmux-hub` | リポジトリリネームと同時 |
| `configs/tmux/tmux.conf` | sidebar 参照を hub に変更 | バイナリリネーム後 |
| 関連 ADR（051, 053） | tmux-sidebar → tmux-hub の言及を更新 | リネーム完了後 |

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `ishii1648/tmux-hub`（別リポ） | tmux-hub | ghq 統合・未起動 repo 表示・popup ランチャーモード追加 |
| `configs/tmux/tmux.conf` | dotfiles | `cmd+shift+s` を popup ランチャーに変更（`tmw_pick` binding 削除） |
| `configs/fish/functions/tmw_pick.fish` | dotfiles | 廃止 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-056 セクション）

## 実装 Issue
- ishii1648/tmux-sidebar#2（リネーム後: ishii1648/tmux-hub#2）
