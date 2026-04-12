# ADR-056: tmux-sidebar を全リポジトリ統合管理 UI として使用する

## ステータス
採用済み（改訂: 2026-04-12）

## 関連 ADR
- 依存: ADR-051（Go 製 tmux-sidebar ツール — UI の実装基盤）
- 依存: ADR-053（全 worktree 横断状態集約 — sidebar に表示するデータ）
- 依存: ADR-054（dispatch skill — sidebar から呼び出すエントリポイント）
- Supersedes: 初版（dispatch keybinding 追加のみの設計）

## コンテキスト

ADR-051 で Go 製 tmux-sidebar ツールを開発中。現状の設計は「全セッションのウィンドウ一覧表示 + Enter で移動」という監視 UI にとどまっている。

別途 `cmd+shift+s` → tmux popup → `tmw_pick` によるリポジトリ選択 UI が存在するが、これは sidebar と重複した懸念（リポジトリ/セッション一覧）を持つ別ツールとして分離している。

- **監視**: 現在どの worktree で何が動いているか → sidebar で解決
- **起動**: 新しいタスクをどこから開始するか → popup で解決（重複・分散）
- **移動**: 動いているセッションへのジャンプ → sidebar の Enter で解決済み

### 設計判断

sidebar を「並列作業の統合管理 UI」として位置づけ、起動・監視・移動をすべて sidebar に集約する。`tmw_pick` popup は sidebar に統合して廃止する。

**統合の前提条件**: sidebar が ghq 管理下の全リポジトリ（未起動セッションを含む）を表示できること。現状は active tmux session のみ表示しており、セッションのないリポジトリへの dispatch 起動に対応できない。

## 設計

### 表示内容

| 状態 | 表示例 |
|---|---|
| dispatch 実行中 | `[dotfiles@auth-fix]   running 12m   (parallel/2)` |
| 通常セッション起動中 | `[dotfiles@main]       idle` |
| permission ask 待ち | `[myapp@feature-x]     ask` |
| 未起動 repo | `dotfiles              —` |
| 未起動 repo | `tmux-sidebar          —` |

ghq 管理リポジトリと active tmux session をマージして表示する。active session は状態バッジ付き、未起動 repo はセッションなしとして区別表示する。

### キーバインド

| キー | 動作 |
|---|---|
| `Enter` | active session: switch-client で移動 / 未起動 repo: session 作成 + 移動 |
| `n` | 選択中の repo に対して dispatch 起動（task description を入力 → `/dispatch --repo <repo> "<desc>"` を実行） |
| `d` | 選択中の dispatch session を cleanup（`/dispatch cleanup <session-id>` 相当） |

### 廃止するもの

- `cmd+shift+s` → `tmw_pick` popup パターン
- `tmw_pick.fish`（または大幅に簡略化）

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `ishii1648/tmux-sidebar`（別リポ） | tmux-sidebar | ghq 統合・未起動 repo 表示・`n`/`d` キーバインド |
| `configs/tmux/tmux.conf` | dotfiles | `cmd+shift+s` の binding 変更（popup 廃止） |
| `configs/fish/functions/tmw_pick.fish` | dotfiles | 廃止または sidebar との役割整理 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-056 セクション）

## 実装 Issue
- ishii1648/tmux-sidebar#2
