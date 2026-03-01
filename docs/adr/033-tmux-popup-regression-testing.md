# ADR-033: tmux popup リグレッションテスト

## ステータス

採用済み

## 関連 ADR

- 依存: [ADR-010](010-dotfiles-regression-testing.md)（bats-core テスト基盤）
- 依存: [ADR-019](019-dotfiles-linux-support-and-e2e-testing.md)（Docker ベース e2e 環境）

## コンテキスト

tmux `display-popup` を使用するスクリプト・キーバインドで繰り返しバグが発生している。過去の修正履歴:

- `display-popup` 内での `$TMUX` 変数ネスティングによる tmux コマンド失敗
- `display-popup` 内からの `switch-client` 失敗
- prtrack popup のソケット管理問題（→ 外部スクリプト化で対処）
- Fish conf.d の読み込み順序による popup 即時終了
- popup が Ctrl+C で閉じられなくなる問題

ADR-010 で bats-core テスト基盤は構築済みだが、popup 固有のテストケースがなく、以下の壊れやすいパターンが未検証:

1. **`$TMUX` 変数のクリア**: popup 内で `TMUX= tmux -S "$SOCK"` としないと nested tmux エラー
2. **popup 内での Fish 関数実行**: `display-popup -E "fish -c '...'"` のパターン
3. **外部スクリプトの引数・環境変数受け渡し**: `prtrack-popup.sh` 等

## 設計案

ADR-010 の既存 bats テスト構成に `popup.bats` を追加する。

### テスト対象

| テスト観点 | 検証内容 |
|---|---|
| `$TMUX` 変数処理 | popup 内で `$TMUX` がセットされた状態から tmux コマンドが実行できる |
| popup 内 Fish 関数実行 | `display-popup -E "fish -c 'tm --sessions-only'"` 相当の起動が成功する |
| prtrack-popup.sh | ソケットパス抽出・セッション作成・detach が正常動作する |
| popup 終了コード | 正常終了・Ctrl+C 終了でホスト側 tmux に影響しない |

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `tests/popup.bats` | dotfiles | 新規作成（popup テストケース） |

## 受け入れ条件

> [issues.md](../issues.md)（ADR-033 セクション）
