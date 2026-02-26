# ADR-010: dotfiles リグレッションテスト導入

## ステータス

Draft

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

## 決定

（未定）

テスト設計の検討結果（`.outputs/claude/regression-test-design.md`）は以下の 3 層構成を提案している：

- **Layer 1: Static Analysis** — `fish -n`, `bash -n`, `shellcheck`, キーバインドチェーン整合性, 参照整合性
- **Layer 2: Integration Tests** — `bats-core` + テスト用 tmux ソケット + テスト用 git リポジトリで全関数を検証。fzf は `--filter` と `tmux send-keys` で対応
- **Layer 3: Smoke Tests** — fish/tmux 起動確認、全関数ロード確認、symlink 検証

## 結果

（未定）
