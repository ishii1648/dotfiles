# ADR-052: オーケストレーション機能を dotfiles skill として実装する

## ステータス

Superseded by [ADR-076](076-herdr-migration-from-tmux.md)（orchestrate を廃止）

## 関連 ADR

- 関連: ADR-007（`/tmp/claude-pane-state/` の状態ファイル仕様を継続利用）
- 関連: ADR-046（`prefix+s` popup を Claude セッション表示の現行 UI として継続利用）
- 関連: ADR-051（将来的な tmux-sidebar への移行先として参照）

## コンテキスト

マルチエージェントオーケストレーションを実行した際に、各ワーカーの進捗を確認する UI が存在しない。現在の Claude セッション表示は `prefix+s` の tmux popup（ADR-046/ADR-007）を使っており、これをオーケストレーション進捗の表示起点とする。

tmux-sidebar（ADR-051 で設計した Go 製ツール）は現時点では未実装のため前提にしない。将来 tmux-sidebar が実装された際に、同じデータソースを引き続き利用できる形で設計する。

オーケストレーション機能の実装形式として以下を検討した：

1. **ECC スラッシュコマンド採用**（`commands/orchestrate.md` をそのまま使う）
2. **dotfiles skill として独自実装**（`.claude/skills/orchestrate/` に実装する）
3. **cmux `omc`**（manaflow-ai/cmux）— macOS ネイティブアプリ（Ghostty ベース）

## 設計案

### 案A: dotfiles skill として独自実装（採用）

ECC の `/orchestrate` の設計（ワークフロータイプ・tmux/worktree モード・ハンドオフ文書）を参考にしつつ、`configs/claude/skills/orchestrate/skill.md` として dotfiles に組み込む。`configs/claude/setup.sh` 経由で `~/.claude/skills/orchestrate` に symlink し、Claude Code から呼び出せるようにする。

ECC スラッシュコマンドをそのまま採用しない理由：
- ECC リポジトリへの外部依存が生まれる（dotfiles の自己完結性を損なう）
- slash command は Claude Code に標準搭載の skill 機構より粗粒度で、引数バリデーション・トリガー条件の定義が難しい
- dotfiles 内の他の skill（`adr-ship` 等）と統一した形式で管理したい

**ワークフロータイプ:**

| タイプ | エージェントチェーン |
|--------|---------------------|
| `feature` | planner → tdd-guide → code-reviewer → security-reviewer |
| `bugfix` | planner → tdd-guide → code-reviewer |
| `refactor` | architect → code-reviewer → tdd-guide |
| `security` | security-reviewer → code-reviewer → architect |
| `custom` | 任意のエージェント列 |

**tmux/worktree 実行モード:**

tmux ペインを複数作成し、各ペインで独立した Claude Code プロセスを起動する。各ワーカーは別の git worktree で動作し、ハンドオフ文書（`HANDOFF: prev-agent -> next-agent`）で引き継ぎを行う。

**tmux popup との統合方針（現行）:**

オーケストレーション状態ファイル（各ワーカーの pane_state）を `prefix+s` popup スクリプト（ADR-007 の `claude-pane-state.sh` ベース）で読み込み、ワーカー一覧をオーバーレイ表示する。

**想定表示（prefix+s popup 内）:**

```
[running 2m]  planner      ←  worker: planner  (pane 3)
[idle]        reviewer     ←  worker: code-reviewer
[ask]         tester       ←  worker: tdd-guide
```

**将来の tmux-sidebar への移行（ADR-051 実装後）:**

ADR-051 の Go 製 tmux-sidebar が実装された際は、同じ状態ファイルをサイドバーの orchestration view で読み込む形に移行する。データソースが同一のため移行コストは低い。

### 案B: ECC スラッシュコマンドをそのまま採用（却下）

`everything-claude-code` の `commands/orchestrate.md` をそのまま `.claude/commands/` に配置する案。ECC リポジトリへの追跡管理が必要になり、dotfiles の自己完結性を損なう。また slash command は skill より粗粒度で、引数バリデーション・他 skill との統一感が乏しい。

### 案C: cmux `omc`（却下）

manaflow-ai/cmux は Ghostty ベースの macOS ネイティブターミナルアプリ。**tmux 環境内では動作しない**。cmux は tmux シムを使用するが前提が Ghostty ネイティブアプリであり、tmux セッション内からは呼び出せない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/skills/orchestrate/skill.md` | dotfiles | 新規作成: orchestrate skill の定義 |
| `configs/claude/setup.sh` | dotfiles | `~/.claude/skills/orchestrate` → `configs/claude/skills/orchestrate` の symlink 作成を追加 |
| `configs/tmux/scripts/claude-sessions-status.sh` | dotfiles | ワーカーの pane_state を読んでワーカー行を追加表示 |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-052 セクション）
