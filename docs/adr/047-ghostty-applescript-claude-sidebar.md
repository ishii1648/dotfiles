# ADR-047: Ghostty AppleScript による Claude セッションサイドバー

## ステータス

Spike完了

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

## Spike 結果

### 検証した内容

`ghostty-tmux-init.sh` に `osascript` 呼び出しを追加し、`split direction left with configuration conf`（`command` プロパティに `claude-session-monitor` を指定）で左ペインを生成して実際に Ghostty を再起動した。

### 判明したこと

**左ペインにも tmux が起動し、statusbar が二重表示になった。**

- `split ... with configuration conf` の `command` プロパティは Ghostty config の `command = ~/.local/bin/ghostty-tmux-init` に**上書きされる**。
  左ペインも `ghostty-tmux-init.sh` → tmux を起動したため、監視スクリプトは動かなかった。
- Ghostty config に `command =` が設定されている場合、全ての新規 split に適用される。
  AppleScript の `surface configuration.command` はこれを Override しない（少なくとも 1.3 では）。

### 残る可能性

1. **`input text` でコマンドを後送する**: split 後に `input text "claude-session-monitor\n" to leftTerm` でシェルにコマンドを打ち込む。ただし、デフォルトコマンドが tmux なので、tmux が起動してしまう前にコマンドが届かない可能性が高い。
2. **Ghostty config から `command =` を削除し、AppleScript で全レイアウトを組む**: 起動時に shell が開いた状態にして、AppleScript で `input text "ghostty-tmux-init\n"` を右ペインに、`input text "claude-session-monitor\n"` を左ペインに送る。ただし起動タイミングの制御が難しい。
3. **Ghostty の `initial-command` を使う**: `command =` の代わりに初回ウィンドウのみに適用される設定があれば、split には適用されない。Ghostty 1.4 での API 変更後に再確認する価値あり。

### 結論

案A（`ghostty-tmux-init.sh` から `osascript` で分割）は **Ghostty config の `command =` と根本的に相性が悪く、そのままでは実現不可**。
