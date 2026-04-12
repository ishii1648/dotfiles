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
| Claude Code skills | `configs/claude/skills/` | dispatch・orchestrate・spawn など |
| aqua 設定 | `aqua.yaml` | CLIツールバージョン管理 |

### 管理対象外（別リポジトリ）

| コンポーネント | 管理場所 |
|---|---|
| claudedog | `ishii1648/claudedog` — Claude Code の人の介入率を追跡・可視化する計測ツール |
| tmux-sidebar | `ishii1648/tmux-sidebar` — 全 session・worktree 状態の監視 UI（Go 製 TUI） |

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

## 並列スケール開発アーキテクチャ

10-20 並列の Claude Code エージェントを同時に稼働・監視する構成。実装済みコンポーネントと設計中コンポーネントを以下に示す。

| 役割 | コンポーネント | 実装状況 | 関連 ADR |
|---|---|---|---|
| タスク起動の統合エントリポイント | `/dispatch` skill | 実装済み | [ADR-054](adr/054-dispatch-skill-unified-entry-point.md) |
| タスク並列分散実行 | `/spawn` skill | 実装済み | — |
| 全 session・worktree の監視 UI | tmux-sidebar (`ishii1648/tmux-sidebar`) | 実装済み（sidebar→dispatch 連携は設計中） | [ADR-051](adr/051-go-tmux-sidebar-tool.md), [ADR-056](adr/056-sidebar-as-dispatch-and-monitor-ui.md) |
| stacked PR の依存グラフ表現・自動 rebase | monitoring agent | 設計中（Draft） | [ADR-057](adr/057-stacked-prs-dependency-management.md) |

dispatch 実行の識別子はセッション名（`dispatch-YYYYMMDD-HHMMSS` 形式）で、ブランチ・worktree・tmux セッションすべてがこのキーでスコープされる（例: `dispatch/<session-name>/<worktree-name>`）。

**既知の設計上の制限（今後の ADR で対処予定）:**
- cleanup は `--force` 強制削除のみで、部分起動失敗時のロールバック手順は未定義
- セッション状態の永続化なし（tmux セッション消滅後の復元は不可）
- ライフサイクル管理・障害時のセマンティクスは ADR-057 以降で設計する

目標アーキテクチャ（monitoring agent は未実装）:

```
/dispatch skill
  └─ meta planner: タスク分解 → worktree + Claude session 起動
        ↓
tmux-sidebar: 全 session 状態を表示・操作 UI として統合 (ADR-056)
        ↓
monitoring agent: PR マージ順管理・rebase 自動化 (ADR-057)
```

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
