# ADR-052: tmux-sidebar オーケストレーションビューへの ECC orchestrate 採用

## ステータス

Draft

## 関連 ADR

- 依存: ADR-051（Go 製 tmux-sidebar ツールを実装基盤として前提）
- 関連: ADR-007（`/tmp/claude-pane-state/` の状態ファイル仕様を継続利用）

## コンテキスト

tmux-sidebar（ADR-051 で採用した Go 製ツール）にマルチエージェントオーケストレーションの進捗を表示する機能を追加するにあたり、バックエンドとなるオーケストレーションフレームワークを選定する必要がある。

候補は以下の 2 つ：

1. **ECC `/orchestrate`**（everything-claude-code）— tmux ネイティブのマルチエージェントオーケストレーション
2. **cmux `omc`**（manaflow-ai/cmux）— macOS ネイティブアプリ（Ghostty ベース）のオーケストレーション

## 設計案

### 案A: ECC `/orchestrate`（採用）

`everything-claude-code` の `commands/orchestrate.md` で定義されたスラッシュコマンドを採用する。

**ワークフロータイプ:**

| タイプ | エージェントチェーン |
|--------|---------------------|
| `feature` | planner → tdd-guide → code-reviewer → security-reviewer |
| `bugfix` | planner → tdd-guide → code-reviewer |
| `refactor` | architect → code-reviewer → tdd-guide |
| `security` | security-reviewer → code-reviewer → architect |
| `custom` | 任意のエージェント列 |

**tmux/worktree 実行モード:**

```bash
node scripts/orchestrate-worktrees.js plan.json --execute
```

tmux ペインを複数作成し、各ペインで独立した Claude Code プロセスを起動する。各ワーカーは別の git worktree で動作し、ハンドオフ文書（`HANDOFF: prev-agent -> next-agent`）で引き継ぎを行う。

**tmux-sidebar との統合方針:**

```
tmux-sidebar/
├── internal/
│   ├── state/
│   │   ├── pane_state.go        # 既存: /tmp/claude-pane-state/
│   │   └── orchestration.go     # 追加: orchestration-status.json をパース
│   └── ui/
│       └── model.go             # orchestration view を追加
```

`node scripts/orchestration-status.js` の出力 JSON を `internal/state/orchestration.go` で読み込み、ワーカー全体の状態を一覧表示する。

**想定表示:**

```
[running 2m]  1: planner    ←  worker: planner  (tmux pane)
[idle]        2: reviewer   ←  worker: code-reviewer
[ask]         3: tester     ←  worker: tdd-guide
```

### 案B: cmux `omc`（却下）

manaflow-ai/cmux は Ghostty ベースの macOS ネイティブターミナルアプリ。32 種類の専門エージェントと Autopilot / Ultrapilot（最大5並列）等の実行モードを持つが、**tmux 環境内では動作しない**。cmux は tmux シムを使用するが前提が Ghostty ネイティブアプリであり、tmux セッション内からは呼び出せない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `internal/state/orchestration.go` | `ishii1648/tmux-sidebar` | 新規追加: `orchestration-status.js` の JSON 出力をパース |
| `internal/ui/model.go` | `ishii1648/tmux-sidebar` | orchestration view を追加 |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-052 セクション）
