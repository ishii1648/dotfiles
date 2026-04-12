# リファレンス

## このリポジトリで管理しているコンポーネント

| コンポーネント | パス | 概要 |
|---|---|---|
| Fish 設定 | `configs/fish/` | シェル設定・カスタム関数・エイリアス |
| Ghostty 設定 | `configs/ghostty/` | ターミナルエミュレータ設定 |
| Neovim 設定 | `configs/nvim/` | エディタ設定（lazy.nvim） |
| tmux 設定 | `configs/tmux/` | マルチプレクサ設定 |
| Claude Code 設定 | `configs/claude/` | CLAUDE.md・スクリプト・statusline |
| Claude Code スクリプト | `configs/claude/scripts/` | 通知・自動承認・リダイレクトなどの補助スクリプト |
| Claude Code skills | `configs/claude/skills/` | dispatch（軽量版）・orchestrate（計画+並列実行）など |
| aqua 設定 | `aqua.yaml` | CLIツールバージョン管理 |

### 管理対象外（別リポジトリ）

| コンポーネント | 管理場所 |
|---|---|
| claudedog | `ishii1648/claudedog` — Claude Code の人の介入率を追跡・可視化する計測ツール |
| tmux-hub | `ishii1648/tmux-sidebar`（→ tmux-hub にリネーム予定） — 並列作業の監視・操作ハブ（Go 製 TUI） |

## ツールスタック

| カテゴリ | ツール | 設定ファイル |
|---------|--------|-------------|
| terminal | Ghostty | `configs/ghostty/config` |
| multiplexer | tmux | `configs/tmux/tmux.conf` |
| editor | Neovim (lazy.nvim) | `configs/nvim/` |
| shell | Fish | `configs/fish/` |
| coding agent | Claude Code | `configs/claude/` |
| package manager | aqua | `aqua.yaml` |
| VCS | Git (SSH署名) | `configs/git/gitconfig` |

## 並列スケール開発アーキテクチャ（独立タスクの並列実行）

> **スコープ**: このセクションは**相互に独立したサブタスクの並列実行**（10-20 エージェント同時稼働）を対象とする。依存関係のある stacked PR 管理は現行スコープ外（後述）。

**現行の実装済みコンポーネント:**

| 役割 | コンポーネント | 実装状況 | 関連 ADR |
|---|---|---|---|
| 軽量タスク起動（1 worktree + 1 worker） | `/dispatch` skill | 実装済み | [ADR-059](adr/059-dispatch-orchestrate-split.md) |
| 計画+並列タスク起動（N worktree + N worker） | `/orchestrate` skill | 実装済み | [ADR-054](adr/054-dispatch-skill-unified-entry-point.md), [ADR-059](adr/059-dispatch-orchestrate-split.md) |
| workflow session log の収集・コミット | Stop hook + `/session-log` skill | 実装済み | [ADR-058](adr/058-workflow-session-log-collection.md) |
| リポジトリ・session の統合管理ハブ | tmux-hub (`ishii1648/tmux-sidebar` → リネーム予定) | 監視・移動は実装済み / ghq 統合・dispatch 起動は設計中 | [ADR-051](adr/051-go-tmux-sidebar-tool.md), [ADR-056](adr/056-tmux-hub-as-unified-management-ui.md) |

dispatch は表示用のセッション名（`<owner>/<repo>` 形式）と、リソースのスコープキーとして使う不変の **session-id**（`<slug>-YYYYMMDD-HHMMSS-XXXX` 形式）を分離する。ブランチ・worktree パスはすべて session-id でスコープされるため、セッション名が衝突しても別の実行のリソースを誤削除しない。

各セッションのマニフェストはリポジトリ外に記録される（エージェントによる改ざんを防ぐため）:
- `/dispatch`: `~/.dispatch/<session-id>/manifest.json`
- `/orchestrate`: `~/.orchestrate/<session-id>/manifest.json`

**最初の副作用（git worktree 作成）より前に全リソースを `created: false` で事前宣言して書き込む**（manifest-first）。cleanup は manifest の `repo_root` を参照して呼び出し元の CWD に依存せずどこからでも動作し、`git worktree list` および `git branch` との reconciliation でクラッシュ直前に作成されたリソースも回収する。

起動時には session-id がユーザに表示される（例: `session 作成: ishii1648/tmux-sidebar [session-id: ishii1648-tmux-sidebar-20260412-152030]`）。

**部分起動中断時の手動復旧手順:**
1. `/dispatch cleanup <session-id>` または `/orchestrate cleanup <session-id>` を実行する（session-id を使うと一意に特定できるため推奨）
2. 原因を確認してから再実行する（新規 session-id で起動）

> 注: 自動再試行・自動調整は未実装。マニフェストはすべての副作用（tmux 作成を含む）より前に書き込まれるため、クラッシュ直後でも session-id でセッションを発見できる。

現行の並列実行アーキテクチャ:

```
/dispatch skill（軽量版）
  └─ 1 worktree + 1 worker Claude を直接起動（planning なし）

/orchestrate skill（計画+並列版）
  └─ meta planner: タスク分解 → N worktree + N worker Claude 起動
     └─ --from-todo: TODO.md ベースの並列実行（旧 spawn 相当）
        ↓
tmux-hub: ghq 全 repo + active session の監視・操作ハブ (ADR-056)
          （ghq 統合・dispatch 起動は設計中 / リネーム予定）
```

**計画中の拡張（現行アーキテクチャのスコープ外）:**

| 役割 | コンポーネント | 状況 | 関連 ADR |
|---|---|---|---|
| stacked PR の依存グラフ表現・自動 rebase | monitoring agent | 設計中（Draft）— 統合インタフェース未確定 | [ADR-057](adr/057-stacked-prs-dependency-management.md) |

### 手動並列作業（従来）

tmux セッション一本化（Ghostty tab 廃止）による構成:

| スコープ | 方法 |
|---------|------|
| リポジトリ単位 | tmux session（`tm` コマンドで管理） |
| リポジトリ内の並列 | git worktree + tmux session（`gw_add` で自動作成） |

Ghostty 起動時に `tmux new-session -A -s main` で main セッションに自動接続する。
各リポジトリは `tm` で ghq 管理下のリポジトリから fzf で選択し、リポジトリ名ベースの tmux session を作成・切替する。
リポジトリ内でブランチ並列作業が必要な場合は `gw_add` で worktree + 専用 tmux session を同時に作成する。

## 主要な運用フロー

### セッション管理 — `tm`

ghq 管理リポジトリと既存 tmux セッションを統合した fzf セレクタ。

- 既存セッション: 緑/黄アイコンで表示、選択で `switch-client`
- 未作成リポジトリ: 選択で新規 session 作成 + 切替
- `X` キーでセッション削除（worktree の場合は worktree + branch も自動削除）
- セッション名は ghq パスから自動生成（例: `github.com/<org>/<repo>` → `<org>_<repo>`）

### Worktree 管理 — `gw_add` / `gw_cd` / `gw_rm`

| コマンド | 概要 |
|---------|------|
| `gw_add <name>` | worktree 作成 + tmux session 作成・切替。`--claude` でセッション内で Claude Code を自動起動 |
| `gw_cd [branch\|path\|/]` | worktree 間を fzf または引数で移動。`/` でメイン worktree に戻る |
| `gw_rm [--dry-run] [--days N]` | マージ済み・古い worktree を一括削除（デフォルト 30 日） |

worktree 配置先: `<リポジトリ>@<worktree名>`（例: `dotfiles@feat-tmux`）

### Worktree ピッカー — `tmw_pick`

`tmw_pick` は ghq リポジトリ一覧から fzf で選択し、デフォルトでメインリポジトリで直接 tmux セッションを開く。
`tmw_worktree_repos.conf` に記載されたリポジトリのみ worktree 名を入力して `gw_add` を呼ぶ（オプトイン）。

### セットアップ

`scripts/setup.sh` + `scripts/setup-manifest.yml` で dotfiles のセットアップを宣言的に管理（ADR-018）。

```bash
scripts/setup.sh                    # full プロファイルで実行
scripts/setup.sh --profile remote   # remote プロファイルで実行
scripts/setup.sh --dry-run          # チェックのみ
```

マニフェストにコンポーネントごとの symlink 定義・セットアップスクリプト委譲を記述。

### ADR 一覧

→ [issues.md](issues.md)（サマリ・対応状況・ADR リンクを一元管理）

## ツール詳細

Neovim プラグイン・Fish カスタム関数・aqua 管理ツールの詳細は → [reference-tools.md](reference-tools.md)
