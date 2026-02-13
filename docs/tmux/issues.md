# tmux 全面移行の課題一覧

tmux セッション一本化（Ghostty タブ廃止）により開発環境の課題を解決するにあたって、tmux 移行時に発生する課題を整理する。

## 課題一覧

| 対応済み | 対応可能 | サマリ | ADR |
|:---:|:---:|:---|:---|
| ✔ | ○ | Cmd キーを tmux で使えない — Cmd は OS レベルで処理されるため tmux に到達しない | [ADR-001](../adr/001-tmux-cmd-key.md) |
| ✔ | △ | tmux 内でリンクをクリックできない — `mouse on` がマウスイベントをインターセプトし、Ghostty に届かない | [ADR-002](../adr/002-tmux-link-click.md) |
| | ○ | 通知クリックで tmux セッションに遷移できない — Ghostty は tmux 内部のセッション状態を認識できない | [ADR-003](../adr/003-tmux-notification-click.md) |
| ✔ | ○ | terminal 上のテキストをコピーできない — `mouse on` がマウス選択をインターセプトし、OS のクリップボードにコピーできない | [ADR-004](../adr/004-tmux-text-copy.md) |
| - | × | tmux セッション内外でペイン移動のキーバインドを共有できない — Ghostty は条件分岐付きキーバインドに非対応 | [ADR-005](../adr/005-tmux-pane-keybind-sharing.md) |

> ○ = 解決可能 / △ = 緩和可能（ワークアラウンド） / × = 対応不可
