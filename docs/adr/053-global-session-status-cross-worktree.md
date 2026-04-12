# ADR-053: 全 worktree 横断 Claude セッション状態集約

## ステータス
Draft

## 関連 ADR
- 依存: ADR-007（claude-pane-state.sh による pane 状態管理）
- 依存: ADR-051（Go 製 tmux-sidebar ツール — 表示先として使用）
- 関連: ADR-052（orchestrate skill — 現状はセッション内のみ表示）

## コンテキスト

現状の `claude-pane-state.sh` は pane ごとに `/tmp/claude-pane-state/pane_N` ファイルへ状態を書き込む（ADR-007）。しかし状態を読み出して表示するスクリプト（`claude-sessions-status.sh`）は単一の orchestrate/spawn セッション内のワーカーしか対象にしていない。

並列度が上がり複数 worktree で Claude が同時に動く構成になると、「どの worktree で何が動いているか」の俯瞰ビューが存在しない。

ADR-051（Go 製 tmux-sidebar）の表示コンテンツとして全 Claude pane の状態を提供するためには、worktree をまたいだ状態集約レイヤーが必要になる。

## 設計案

### 案A: 既存スクリプト拡張（採用）

`/tmp/claude-pane-state/` 以下の全ファイルを走査し、pane ID から tmux の session・window・pane 情報を逆引きして表示する。

```
[session:window]  running 12m  (role: planner)
[session:window]  idle
[other:window]    ask
```

**変更が必要なファイル**:

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/tmux/scripts/claude-sessions-status.sh` | dotfiles | 全 pane 集約モードを追加（引数なしで全 worktree 表示） |

### 案B: tmux-sidebar ツール内に実装（却下）

Go バイナリ内で `/tmp/claude-pane-state/` を直接読む。sidebar tool と状態集約が密結合になりテストしづらい。スクリプトとして独立させる方が再利用性が高い。

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-053 セクション）
