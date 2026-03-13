# ADR-047: Ghostty AppleScript による Claude セッションサイドバー

## ステータス

Spike中

## 関連 ADR

- 関連: ADR-045（tmux statusbar 方式で同じ問題を解決しようとした先行 ADR。廃止済み）
- 関連: ADR-046（statusbar 方式を撤廃し popup に集約した ADR）
- 関連: ADR-007（`/tmp/claude-pane-state/` による状態検知の基盤）

## コンテキスト

ADR-045 で tmux statusbar に Claude セッション一覧を常時表示する方式を試みたが、ADR-046 で撤廃した。撤廃の根本理由のひとつは「tmux の `switch-client` でセッションを切り替えると tmux ペインが消えるため、tmux レイヤー内に常時表示を固定できない」というアーキテクチャ的制約だった。

Ghostty 1.3 で AppleScript サポート（プレビュー）が追加された。Ghostty レベルで画面を左右分割すれば、tmux セッション切り替えとは独立して左ペインを生き続けさせることができる。これは过去に却下した「案D: tmux セッション内サイドバー」の根本問題を回避できる可能性がある。

実現可能性の調査で以下が判明している:
- `split` コマンドに `direction left/right` パラメータがある
- `with configuration` + `command` プロパティで起動コマンドを指定できる
- `focus` コマンドで分割後にフォーカスを元ペインに戻せる
- Ghostty 1.3 はプレビュー機能で、1.4 以降に API 変更が予定されている

## 設計案

### 案A: ghostty-tmux-init.sh から osascript で分割し左ペインで監視スクリプトを起動する（検証対象）

Ghostty の `command =` に設定されている `ghostty-tmux-init.sh` から `osascript` を呼び出して Ghostty ウィンドウを左右に分割する。左ペインで `claude-session-monitor.sh` を起動し、右ペイン（現在のプロセス）で通常通り `tmux new-session -A -s main` を実行する。

```
ghostty-tmux-init.sh 起動（右ペイン）
  ↓
osascript でウィンドウを左右分割
  ├─ 左ペイン（22列）: claude-session-monitor.sh を実行
  └─ 右ペイン: tmux new-session -A -s main（現行と同じ）
```

**AppleScript イメージ:**

```applescript
tell application "Ghostty"
    set currentTerm to focused terminal of selected tab of front window
    set conf to new surface configuration
    set command of conf to "/path/to/claude-session-monitor.sh"
    set leftTerm to split currentTerm direction left with configuration conf
    focus currentTerm
end tell
```

**検証が必要な点:**
- `ghostty-tmux-init.sh` の起動直後（Ghostty ウィンドウ描画前）に `osascript` を呼んでも動作するか
- `window-save-state = always` との組み合わせで Ghostty 再起動時に左ペインが二重生成されないか
- 左ペイン幅（例: 22列）を AppleScript で指定できるか
- 左ペインが tmux セッション切り替え後も消えずに表示され続けるか

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/ghostty/ghostty-tmux-init.sh` | dotfiles | `osascript` 呼び出しを追加（左右分割 + 右ペインフォーカス戻し） |
| `configs/ghostty/scripts/setup-claude-sidebar.applescript` | dotfiles | 新規作成（左右分割 + 監視スクリプト起動） |
| `configs/ghostty/scripts/claude-session-monitor.sh` | dotfiles | 新規作成（`/tmp/claude-pane-state/` を読んでセッション一覧を表示するループ） |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-047 セクション）
