# ADR-049: prtrack を tmux popup から常駐 session に変更する

## ステータス

採用済み（ESC → `switch-client -l` バインディングは 2026-04-17 に撤回）

## 撤回された決定

- **ESC → `switch-client -l`** — 常駐 session への切替自体は有効のまま、prtrack session 内で ESC を `switch-client -l` にリマップする設計を取りやめ、ESC 本来のキー送出に戻した。理由は prtrack ツール側が ESC を UI 操作（リスト解除・モード終了等）に使うため、session 切替への横取りがツール操作を阻害していたこと。session を離れるには `prefix+m`（`switch-client -l`）や Cmd+1〜9 のウィンドウ切替を使う。

## 関連 ADR

- 依存: [ADR-001](001-tmux-cmd-key.md)（Ghostty CSI → tmux user-keys のシーケンス変換基盤）
- 関連: [ADR-033](033-tmux-popup-regression-testing.md)（prtrack-popup.sh のテスト観点を部分変更）

## コンテキスト

ADR-033 採用時の prtrack は `display-popup` でオーバーレイ表示し、ESC で `detach-client` してポップアップを閉じる設計だった。

実際に使用した結果、以下の問題が明らかになった:

1. **スクロール履歴が消える**: popup を閉じるたびに prtrack のターミナル出力が失われる
2. **操作モデルの非対称性**: 他の tmux session は `switch-client` で行き来するのに、prtrack だけがオーバーレイという異質な操作感
3. **ESC キーの横取り**: prtrack session 内での ESC がすべて popup 閉じに吸われ、prtrack 自身の UI 操作と競合するリスク

「popup は一時表示に適しているが、継続的に参照するツールには常駐 session の方が自然」という判断のもと変更する。

## 設計案

### 案A: 常駐 session に変更し Cmd+g で switch-client（採用）

- prtrack session を常時起動したままにする
- Cmd+g で session が存在しなければ作成・prtrack 起動、存在すれば直接 switch
- prtrack session 内で ESC → `switch-client -l`（直前の session に戻る）
- cmd+s の session 一覧からは `__tm_candidates.fish` の `string match -v prtrack` で引き続き除外

### 案B: popup を維持したまま状態保持する（却下）

popup の `-d` オプション（detach on exit を無効化）で prtrack session を保持しつつ、popup 再表示時に同セッションを attach する方式。実現可能だが操作モデルが複雑で、案A の方がシンプル。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/tmux/tmux.conf` | dotfiles | `display-popup` → `run-shell`、ESC binding: `detach-client` → `switch-client -l` |
| `configs/ghostty/prtrack-popup.sh` | dotfiles | `prtrack; tmux detach-client` の detach-client 削除、`exec tmux attach` → `tmux switch-client` |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-049 セクション）
