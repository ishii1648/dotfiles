# ADR-046: Claude セッション statusbar 表示の撤廃

## ステータス

廃止（ADR-050 で置換）

> ADR-050 で「popup をやめて split-window サイドバーに移行する」と決定し、「popup で十分」という本 ADR の結論が覆された。

## 関連 ADR

- 依存: ADR-045（撤廃対象の実装。statusbar への Claude セッション常時俯瞰 UI）
- 関連: ADR-007（`/tmp/claude-pane-state/` による状態検知の基盤）

## コンテキスト

ADR-045 で `status-format[0]` に Claude セッション一覧を常時表示し、`prefix+1~9` / カーソルモード（`Cmd+c` → `j/k/Enter`）で切り替える UI を実装した。

実際に使用した結果、以下の問題が明らかになった：

1. **恩恵が1点のみ**: 「常時表示」という恩恵しかなく、`prefix+s` popup で十分に代替できる
2. **表示領域の増加**: statusbar が 2 行になり、コンテンツ領域が削られる
3. **操作領域の増加**: カーソルモード・`prefix+1~9` の Claude 専用キーバインドが追加され、キーマップが複雑になる
4. **position の制約**: tmux の `status-position` は全 format に一括適用されるため、Claude バーだけを上部に固定できない
5. **stale 検出の不一致**: popup 側（fish）にある stale ファイル検出ロジックが bash 側には存在しない

「安易に機能追加すべきではない。現状の popup で充分機能している」という判断のもと、statusbar の Claude セッション表示を撤廃する。

## 設計案

### 案A: statusbar の Claude 表示を撤廃し、popup に集約する（採用）

- `status-format[0]`（Claude セッション一覧）を削除し、1 行 statusbar に戻す
- カーソルモード（`Cmd+c` / `claude-nav` テーブル）を削除
- `prefix+1~9` の Claude 専用切り替えバインドを削除
- `claude-sessions-status.sh` / `claude-session-switch.sh` を削除
- Claude セッションの確認・切り替えは引き続き `prefix+s`（popup）で行う

### 案B: statusbar を維持して popup の Claude バッジを削除する（却下）

ロジック重複を解消するためにこの案も検討したが、そもそも statusbar 表示自体の存在意義が薄いため、根本から撤廃する案Aを選ぶ。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/tmux/tmux.conf` | dotfiles | `status 2` → `status 1`、`status-format[0]`（Claude行）削除、`prefix+1~9` Claude バインド削除、`user-keys[13]`（Cmd+c）削除、`claude-nav` キーテーブル削除 |
| `configs/tmux/scripts/claude-sessions-status.sh` | dotfiles | 削除（`git rm`） |
| `configs/tmux/scripts/claude-session-switch.sh` | dotfiles | 削除（`git rm`） |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-046 セクション）
