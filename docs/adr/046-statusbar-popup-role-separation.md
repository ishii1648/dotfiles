# ADR-046: statusbar と popup の役割分離

## ステータス

Draft

## 関連 ADR

- 関連: ADR-045（statusbar の実装基盤。Claude 常時俯瞰 UI の設計）
- 関連: ADR-007（`/tmp/claude-pane-state/` による状態検知の基盤）

## コンテキスト

ADR-045 で statusbar に Claude ウィンドウの常時俯瞰 UI を実装した。同時に、`prefix+s` の popup（`tm --sessions-only`）でも `__tm_claude_state.fish` を通じて Claude 状態バッジ（`[running]` / `[perm]` / `[idle]` 等）を表示している。

この状態には以下の問題がある：

1. **Claude 状態ロジックの重複**: statusbar 側（`claude-sessions-status.sh`、bash）と popup 側（`__tm_claude_state.fish`、fish）に同一ロジックが2箇所存在する
2. **stale 検出の不一致**: `__tm_claude_state.fish` は `pane_current_command` でシェルかどうかを確認して stale ファイルを削除するが、`claude-sessions-status.sh` にはこのロジックがない。statusbar が「Claude が終了しているのに `[idle]` を表示し続ける」可能性がある
3. **役割が不明確**: statusbar と popup の両方で Claude 状態を確認できるため、どちらを使えばよいか分かりにくい

## 設計案

### 案A: 役割を明確に分離する（採用）

- **popup（`prefix+s`）**: tmux セッション操作ハブに専念する（セッション切り替え・削除・新規作成）。Claude 状態バッジを削除する
- **statusbar**: Claude Code の状態確認とナビゲーションに専念する

popup から Claude バッジを削除することで `__tm_claude_state.fish` が不要になり、ロジックの重複が解消される。また `claude-sessions-status.sh` に stale 検出ロジックを追加して statusbar の信頼性を高める。

**操作の使い分け:**

| 操作 | 使用 UI |
|------|---------|
| Claude の状態確認 | statusbar（常時表示） |
| Claude ウィンドウへの切り替え | `prefix+1~9` / カーソルモード |
| tmux セッションの切り替え（全セッション） | `prefix+s`（popup） |
| tmux セッションの削除 | `prefix+s`（popup）→ X キー |
| tmux セッションの新規作成 | `prefix+s`（popup）→ ghq 選択 |

### 案B: popup に Claude バッジを残す（却下）

現状維持。stale 検出のみ bash 側に追加する。

**却下理由:** statusbar で常時確認できる情報を popup にも表示する冗長さが残る。ロジックの重複も解消されない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/fish/functions/__tm_claude_state.fish` | dotfiles | 削除（`git rm`）。popup から参照されなくなるため不要 |
| `configs/fish/functions/__tm_candidates.fish` | dotfiles | Claude バッジ追加コード（約50行）を削除。`__tm_claude_state` の呼び出しを除去 |
| `configs/tmux/scripts/claude-sessions-status.sh` | dotfiles | stale 検出ロジックを追加（`pane_current_command` がシェルの場合に state ファイルを削除） |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-046 セクション）
