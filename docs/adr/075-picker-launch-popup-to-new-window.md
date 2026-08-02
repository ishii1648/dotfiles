# ADR-075: `tmux-sidebar new` の起動を popup から new-window に変更する

## ステータス

Superseded by [ADR-076](076-herdr-migration-from-tmux.md)（picker を廃止）

## 関連 ADR

- 依存: ADR-069（`prefix+S` を `tmux-sidebar new` の popup 起動に統一した決定 — 本 ADR はその「popup で包む」部分だけを反転する）

## コンテキスト

ADR-069 で `prefix+S` は `display-popup -E -w 80 -h 24 'tmux-sidebar new'` として picker(`tmux-sidebar new`)を popup で起動する経路に統一された。実運用で「tmux popup だと入力補完まわりが不便」という問題が顕在化し、popup 経由の起動をやめたいという要望が出た。

upstream (`ishii1648/tmux-sidebar`) 側で調査した結果、実際の `claude` / `codex` セッション自体は popup 内では動いておらず（`internal/dispatch.Launch` が別の tmux window/session を背景で作って起動する)、popup が包んでいたのは picker の「repo選択 + prompt入力」ステップのみだった。この custom textarea への入力体験が popup 内では快適でない、というのが不便の実質的な所在。

upstream の `tmux-sidebar new` subcommand 自体は window framing に依存しない設計になっており（呼び出し側が `display-popup` / `new-window` / `split-window` のどれで包むかを自由に選べる）、dotfiles 側の bind-key を変更するだけで popup をやめられる。

## 設計案

### 案A: `bind S` を `display-popup -E` から `new-window` に変更する（採用）

- `configs/tmux/tmux.conf` の `bind S display-popup -E -w 80 -h 24 'tmux-sidebar new'` を `bind S new-window 'tmux-sidebar new'` に変更
- Cmd+Shift+S（ghostty `super+shift+s` → prefix+S）の筋肉記憶は温存
- picker は新しい tmux window を丸ごと使う形になり、選択完了 or キャンセルで window ごと破棄される

採用理由:
- 実際の `claude`/`codex` セッション起動ロジックには変更が要らない（起動 UI 層のみの変更）
- 既存の bind-key・muscle memory を壊さない

### 案B: `split-window` で現在の pane を分割して picker を出す（却下）

却下理由: 作業を中断せず画面の一部だけ使える利点はあるが、pane分割・復帰のタイミング管理が増える割に popup の補完問題を解決する上での追加メリットが薄い。

### 案C: picker(custom TUI)自体を廃止し、repo選択だけにした上で実際の `claude`/`fable` セッションへ即座に切り替え、promptはそちらの実TUIで入力させる（却下）

却下理由: 根本的な補完問題の解消にはなるが、既存のprompt事前入力→worktree作成→自動流し込みという一連の自動化フローを大きく作り変える必要があり、影響範囲が大きすぎる。将来的な別 ADR として検討の余地はある。

## 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/tmux/tmux.conf` | dotfiles | `bind S display-popup -E -w 80 -h 24 'tmux-sidebar new'` → `bind S new-window 'tmux-sidebar new'` |
| `main.go` / `docs/spec.md` / `docs/design.md` / `docs/setup.md` / `docs/history.md` | `ishii1648/tmux-sidebar` | popup 前提の記述を new-window 前提に更新（[issues/0022](https://github.com/ishii1648/tmux-sidebar/blob/main/issues/0022-feat-drop-popup-launch.md) 参照） |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-075 セクション）
