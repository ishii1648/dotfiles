# ADR-061: popup ランチャーのトップレベルモードを claude / codex に再構成する

## ステータス
廃止（ADR-069 で置換）

> popup ランチャーの実装が `dispatch_launcher.fish` から upstream `tmux-sidebar new`（`internal/picker`）に移管された。トップレベル claude / codex 二値モード・`tab` でのモード切替・`ghq list` 候補ソースという本 ADR の方針は upstream picker に同一仕様で実装されているが、起動経路と実装ロケーションが完全に変わったため本 ADR は廃止扱い。

## 関連 ADR
- 依存: ADR-056（dispatch/orchestrate popup ランチャー — 本 ADR が Step 1 のモード設計を上書き）
- 関連: ADR-054（dispatch skill — claude モードの実体）
- 関連: ADR-059（dispatch/orchestrate 分離 — claude モードの Step 2 で利用）
- 関連: ADR-062（codex モードの dispatch 化 — フェーズ2 仕様）

## コンテキスト

`cmd+shift+s` の popup ランチャー（`dispatch_launcher.fish`）は ADR-056 採用後に Step 1 が拡張され、現在は `tab` でトップレベルモードを **repos / PRs** に切替できる：

- `repos` モード: ghq リポジトリ一覧を表示し、選択 → Step 2（dispatch / orchestrate のサブモード切替 + プロンプト入力）へ
- `PRs` モード: PR worktree 一覧を表示し、選択 → 直接セッション切替 + Claude 起動

しかし運用上、`PRs` モードの利用頻度が低く、トップレベルの一等地を占有する価値が薄い。一方で **codex CLI を popup ランチャーから素早く起動したい** というニーズが新たに出てきた（リポジトリを選んでメインで開くだけのケース）。

トップレベルモードは「どの AI エージェントを起動するか」で揃えた方が概念的に整理しやすく、将来 codex 側の起動オプション（worktree、prompt 投入など）を拡張しても破綻しない。

### ADR-056 の決定変更

ADR-056 の Step 1 設計（リポジトリ選択のみ）と、その後追加された PRs モードの両方を、claude / codex の二値モードに置き換える。Step 2（claude モード時の dispatch/orchestrate 切替）は ADR-056/059 の設計を維持する。

## 設計

### トップレベルモード

| モード | 動作 |
|---|---|
| `claude`（デフォルト） | 既存の repos モード相当。ghq リポジトリ一覧 → Step 2（dispatch/orchestrate） |
| `codex` | ghq リポジトリ一覧 → 選択リポジトリのメインディレクトリで tmux session を作成・切替し、`codex` CLI を起動（worktree 作成なし、prompt 投入なし） |

- どちらのモードも候補ソースは同じ `ghq list`（worktree ディレクトリは除外）
- `tab` でモード切替、ヘッダーにアクティブモードをハイライト表示
- 既存の `PRs` モードは廃止する（PR worktree 一覧の表示・切替フローを popup ランチャーから除去）

### codex モードの初期実装（フェーズ 1）

選択したリポジトリに対して以下を実行：

1. session 名を `basename($selected)` で決める（例: `dotfiles`）
2. session が無ければ ghq パスを cwd として新規作成
3. `codex` を `send-keys` で投入
4. `tmux switch-client -t <session>` で切替

worktree 作成・prompt 投入・モード切替（dispatch 相当）は **行わない**。将来の仕様拡張は別 ADR で扱う。

### キーバインドとフロー

```
Step 1（fzf）
┌─────────────────────────────────────┐
│ tab: switch  claude / codex         │
│ > dotfiles                          │
│   sandbox-ishii1648                 │
│   ...                               │
└─────────────────────────────────────┘

claude モード: Step 2 へ（既存）
codex モード: 直接 session 切替 + codex 起動
```

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/fish/functions/dispatch_launcher.fish` | dotfiles | Step 1 のモードを claude/codex に変更。codex 選択時に `codex` 起動フローを追加。PRs モードのコードを削除 |
| `configs/fish/functions/__dl_repo_candidates.fish` | dotfiles | claude/codex どちらでも `ghq list` を返すように調整（PR worktree 取得分岐の削除） |
| `configs/fish/functions/__dl_fzf_toggle.fish` | dotfiles | トグル先を `repos`/`PRs` から `claude`/`codex` に変更 |
| `docs/adr/056-dispatch-orchestrate-popup-launcher.md` | dotfiles | ステータスを `部分廃止（ADR-061 で一部変更）` に更新し、Step 1 設計が ADR-061 で上書きされた旨を注記 |

> 上記ファイル一覧は現状の dispatch_launcher.fish 構成からの推定。実装時に補助関数の正確なファイル名・分割粒度を確認する。

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-061 セクション）
