# ADR-050: tmux split-window + Fish スクリプトによる Claude セッションサイドバー

## ステータス

部分廃止（ADR-051 で一部変更）

- **変更された決定** — 「案C: Rust/Go 自前実装（却下）」→ ADR-051 で Go 実装を採用
- **引き続き有効な決定** — `split-window -hfb` によるサイドバー配置・`@pane_role = "sidebar"` による識別・`after-new-window` フックによる自動生成・`prefix+e` で toggle という構成全般

## 関連 ADR

- 依存: ADR-007（`/tmp/claude-pane-state/` による状態検知の基盤。継続利用）
- 関連: ADR-045（tmux statusbar 方式で同じ問題を解決しようとした先行 ADR）
- 関連: ADR-046（「popup で十分」として statusbar を撤廃した ADR。本 ADR で廃止）
- 関連: ADR-047（Ghostty AppleScript サイドバーの Spike。技術的制約で断念済み）

## コンテキスト

ADR-046 の決定（「popup で十分」）を変更する。

ADR-045 → ADR-046 → ADR-047 と段階的に「Claude セッション常時俯瞰」を検討してきた。

- ADR-045: tmux statusbar に常時表示 → 表示・操作領域コストが大きく ADR-046 で撤廃
- ADR-046: popup（`prefix+s`）に集約 → 常時表示を諦める方向へ
- ADR-047: Ghostty AppleScript でサイドバーを実現 → `command =` との相性問題で Spike 断念

tmux-agent-sidebar（https://github.com/hiroppy/tmux-agent-sidebar）の調査で、`split-window -hfb` によるサイドバー pane + `after-new-window` フックによる自動生成という実現方式が判明した。同プラグインは Rust (Ratatui) で TUI を実装しているが、自前で Fish スクリプトを使えば外部依存なしに同等の仕組みが実現できる。

ADR-007 の `/tmp/claude-pane-state/` はデータソースとして維持し、hooks の変更は不要。

## 設計案

### 案A: Fish スクリプト + tmux split-window -hfb（採用）

- `split-window -hfb -l 20% -t {leftmost_pane}` でサイドバー pane を左端に作成
- サイドバー pane 内で Fish スクリプトが常駐し、1 秒ポーリングで `/tmp/claude-pane-state/` を読んで状態を表示
- `tput cup 0 0` でカーソルを左上に戻してから上書きすることでちらつきを抑制
- `after-new-window` フックで各ウィンドウに自動生成
- `@pane_role = "sidebar"` で識別し toggle（表示/非表示）を実装
- セッション切り替え時も各ウィンドウに pane が存在するため常時表示が維持される

### 案B: tmux-agent-sidebar プラグイン（却下）

TPM + Rust binary の外部依存が増え dotfiles のポータビリティが下がる。ADR-007 の hooks も書き換えが必要になる。

### 案C: Rust / Go 自前実装（却下）

dotfiles にビルドチェーンを持ち込むコストに見合う品質差がない。Fish スクリプトで `tput cup 0 0` + ANSI カラーによる実用品質は達成できる。差分描画やマウス操作が必要になった時点で移行を検討する。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/tmux/tmux.conf` | dotfiles | ADR-058 セクション（`prefix+1~9` claude-session-switch、`User13` / `claude-nav` カーソルモード）を削除し、`after-new-window` フックを追加 |
| `configs/fish/functions/claude-sidebar.fish` | dotfiles | 新規作成（サイドバー pane 内で動く常駐表示スクリプト） |
| `configs/fish/functions/claude-sidebar-toggle.fish` | dotfiles | 新規作成（toggle: `@pane_role = "sidebar"` の pane を kill または split-window で作成） |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-050 セクション）
