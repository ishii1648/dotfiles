# ADR-056: tmux-sidebar をタスク起動・進捗監視の統合 UI として使用する

## ステータス
採用済み

## 関連 ADR
- 依存: ADR-051（Go 製 tmux-sidebar ツール — UI の実装基盤）
- 依存: ADR-053（全 worktree 横断状態集約 — sidebar に表示するデータ）
- 依存: ADR-054（dispatch skill — sidebar から呼び出すエントリポイント）

## コンテキスト

ADR-051 で Go 製 tmux-sidebar ツールを開発中。現状の設計は「全セッションのウィンドウ一覧表示 + Enter で移動」という監視 UI にとどまっている。

一方 ADR-054/055 で `/dispatch` skill が整備されると、「新しいタスクを起動する」という操作も sidebar から行えるようにすることで、tmux popup を使わずに sidebar だけで開発ワークフローを完結できるようになる。

### 課題の整理

- **監視**: 現在どの worktree で何が動いているか → ADR-053 の状態集約で解決
- **起動**: 新しいタスクをどこから開始するか → 現状は tmux popup 経由の手動操作
- **移動**: 動いているセッションへのジャンプ → ADR-051 の Enter で解決済み

## 設計案

### 案A: sidebar に dispatch キーバインドを追加（採用）

tmux-sidebar に新しいキーバインドを追加し、sidebar 内から直接 `/dispatch` を起動できるようにする。

**キーバインド案**:

| キー | 動作 |
|---|---|
| `n` | 新規タスク起動（`docs/issues.md` から fzf で選択 → `/dispatch` 実行） |
| `Enter` | 選択セッション・ウィンドウへ移動（既存） |
| `d` | 選択セッションの cleanup（`/dispatch cleanup` 相当） |

**表示内容の拡張**:

現状（ADR-051 の設計）:
```
[session]  window-name  状態バッジ
```

拡張後:
```
[dotfiles@auth-fix]   running 12m   (dispatch: parallel/2)
[dotfiles@main]       idle
[myapp@feature-x]     ask
```

### 案B: sidebar を読み取り専用にして別 popup でタスク起動（却下）

監視と起動を分離する案。UX の一貫性が低く、tmux popup の問題（都度操作が必要、状態がリセット）を解決できない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `ishii1648/tmux-sidebar`（別リポ） | tmux-sidebar | `n` / `d` キーバインドの追加 |
| `configs/tmux/tmux.conf` | dotfiles | sidebar 起動設定の更新 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-056 セクション）

## 実装 Issue
- ishii1648/tmux-sidebar#2
