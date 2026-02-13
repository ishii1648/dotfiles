# ADR-005: tmux セッション内外でペイン移動のキーバインドを共有できない

## ステータス

対応不可（受容）

## コンテキスト

Ghostty の `keybind` は1つのキーに対して1つのアクションしか割り当てられず、「tmux セッション内なら `text:\x00h`（tmux ペイン移動）、セッション外なら `goto_split:left`（Ghostty split 移動）」のような条件分岐ができない。

移行前は `Cmd+Shift+J/K` に Ghostty の `goto_split:previous/next` を割り当てていたが、tmux 移行で `text:\x00h/j/k/l` に上書きしたため、tmux 外でのペイン移動が機能しなくなった。

## 決定

対応しない。Ghostty にはプロセス検出や条件分岐のキーバインド機構が存在しないため、同一キーでの両立は不可能。tmux 全面移行により Ghostty のネイティブ split を使わない前提であれば実害はない。

tmux 外でもペイン操作が必要な場合は、Ghostty 起動時に自動で tmux セッションにアタッチする運用（`command = tmux new-session -A -s main`）で「tmux 外」の状態自体をなくすことで回避可能。
