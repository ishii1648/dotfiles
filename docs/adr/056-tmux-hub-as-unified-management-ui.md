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

tmux-hub を「並列作業の統合管理ハブ」として位置づけ、リポジトリ選択・監視・移動・dispatch 起動を集約する。ただし task description のテキスト入力は sidebar ペインの幅（30〜40 文字）では不便なため、`n` キー押下時のみ `display-popup -w 80%` でフルサイズ popup を呼び出す。

`tmw_pick` popup は廃止し、tmux-hub からの popup 呼び出しに一本化する。`cmd+shift+s` は tmux-hub の表示トグルに変更する。

## 設計

### UI 構造

| レイヤー | 実装 | 責務 |
|---|---|---|
| sidebar ペイン | tmux-hub が常駐描画 | 状態モニター + セッションセレクター |
| popup | tmux-hub が `display-popup` で起動 | テキスト入力（dispatch 起動時の task description） |

### 表示内容（sidebar ペイン）

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

### キーバインドとフロー

既存のキーバインド（j/k/Enter/Tab）に加えて:

| キー | 動作 |
|---|---|
| `Enter` | active session: switch-client で移動（既存）/ 未起動 repo: session 作成 + 移動（新規） |
| `n` | `display-popup -w 80%` でテキスト入力 popup を開き task description を入力 → `/dispatch --repo <selected-repo> "<desc>"` を実行 |
| `d` | 選択中の dispatch session を cleanup（`/dispatch cleanup <session-id>` 相当） |

`n` のフロー:
```
sidebar ペイン (narrow)     popup (80% 幅)
  dotfiles ──── n ────────→ dispatch> タスク記述を入力...
  tmux-hub                             ↓ Enter
  myapp                      /dispatch --repo dotfiles "..."
```

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
| `ishii1648/tmux-hub`（別リポ） | tmux-hub | ghq 統合・未起動 repo 表示・`n`/`d` キーバインド（`n` は popup 呼び出し） |
| `configs/tmux/tmux.conf` | dotfiles | `cmd+shift+s` を tmux-hub トグルに変更（popup binding 削除） |
| `configs/fish/functions/tmw_pick.fish` | dotfiles | 廃止 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-056 セクション）

## 実装 Issue
- ishii1648/tmux-sidebar#2（リネーム後: ishii1648/tmux-hub#2）
