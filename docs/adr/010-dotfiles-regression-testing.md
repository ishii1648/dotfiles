# ADR-010: dotfiles リグレッションテスト導入

## ステータス

採用済み

## コンテキスト

fish / tmux / ghostty の設定を追加・更新するたびに既存機能が壊れるケースが増えている。
特に以下のパターンで問題が起きやすい。

- **Ghostty → tmux のキーバインドチェーン**: Ghostty CSI シーケンス → tmux `user-keys[N]` → `bind-key -n UserN` の3層マッピングが、どこか一箇所を変更するだけで全体が機能しなくなる。直近のコミット履歴でも繰り返し修正が発生している
- **Fish 関数間の依存関係**: `tm → __tm_candidates → __tm_claude_state` のように呼び出し連鎖があり、片方を変更すると下流が壊れる
- **tmux display-popup 内の TMUX 変数ネスティング**: ネストされた tmux セッション内での `$TMUX` 変数の扱いが壊れやすく、prtrack-popup.sh で過去に複数回修正
- **シンボリックリンクの参照先不整合**: ファイルをリネーム・移動した際に参照先が切れる

現状は手動確認のみで、設定変更のたびに「なぜか動かなくなった」を人手でデバッグしている。
coding agent による実装・フィードバックループを活用するため、自動実行可能なテストが必要。

### 調査済み事項

- **fzf のテスト可能性**: `fzf --filter` オプションで TTY 不要の純粋 stdin/stdout フィルタとして動作可能。また `tmux send-keys` + `capture-pane` は fzf 公式テストスイートが採用する手法であり、選択 UI を含めた E2E テストも自動化可能
- **Ghostty のテスト可能性**: 外部からのプログラマティック制御 API は未実装。ただし `tmux send-keys` で CSI シーケンスを直接注入することで、Ghostty を介さずに tmux 側の受け取り処理を検証できる

## 設計案

### 案 A: 独自テストランナー（却下）

初期検討では独自のシェルスクリプトベースのテストランナーを検討したが、テスト記述の冗長さと TAP 出力の自前実装コストから却下。

### 案 B: ADR-019 の Docker 環境に bats-core を統合（採用）

ADR-019 で構築済みの Docker ベース e2e テスト環境に bats-core を追加し、2 層構成でリグレッションテストを実行する。

- **Layer 1: 静的解析 + チェーン整合性**
  - `fish -n` / `bash -n` による構文検証
  - Ghostty CSI シーケンス ↔ tmux user-keys の対応検証
- **Layer 2: 統合テスト**
  - fish 関数のロードと `__tm_session_name` の単体テスト
  - テスト専用ソケットでの tmux server 起動・キーバインド登録確認
  - パススルーモードの ON/OFF 状態遷移検証

Dockerfile 内の `RUN bats tests/` で Docker build 時にテストが実行され、失敗すれば build failure として既存の CI ワークフロー（`.github/workflows/e2e.yml`）で検出される。

## 関連 ADR

- **依存**: [ADR-019](019-dotfiles-linux-support-and-e2e-testing.md)（Docker ベース e2e テスト環境）

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-010 セクション）
