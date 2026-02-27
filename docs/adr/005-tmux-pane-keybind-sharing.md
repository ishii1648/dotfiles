# ADR-005: tmux セッション内外でペイン移動のキーバインドを共有できない

## ステータス

対応不可（受容）

## コンテキスト

Ghostty の `keybind` は1つのキーに対して1つのアクションしか割り当てられず、「tmux セッション内なら `text:\x00h`（tmux ペイン移動）、セッション外なら `goto_split:left`（Ghostty split 移動）」のような条件分岐ができない。

移行前は `Cmd+Shift+J/K` に Ghostty の `goto_split:previous/next` を割り当てていたが、tmux 移行で `text:\x00h/j/k/l` に上書きしたため、tmux 外でのペイン移動が機能しなくなった。

## 設計案

Ghostty にはプロセス検出や条件分岐のキーバインド機構が存在しないため、同一キーでの両立は実現不可能。検討した回避策:

- tmux 外でも tmux 内と同じキーで移動できるようにする → Ghostty の機能不足で実現不可
- tmux 外専用の別キーを割り当てる → 運用が複雑になるため却下
- Ghostty 起動時に自動で tmux にアタッチして「tmux 外」の状態自体をなくす → **採用（運用回避）**

## 決定

対応しない。Ghostty 起動時に `command = tmux new-session -A -s main` で自動アタッチする運用にすることで「tmux 外」の状態自体をなくす。

## 受け入れ条件

（issues.md 導入前の ADR。対応不可として受容）
