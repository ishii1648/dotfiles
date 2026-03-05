# ADR-052: claudedog をトップレベルディレクトリに隔離し開発プロセスを分離する

## ステータス
採用済み

## 関連 ADR
- 関連: ADR-011（session-index の基盤）
- 関連: ADR-036（permission UI 計測の基盤）
- 関連: ADR-041（人の介入指標拡張）
- 関連: ADR-042（時系列トレンドグラフ）
- 関連: ADR-043（permission UI 内訳監視）
- 関連: ADR-049（サブエージェントセッション除外）
- 関連: ADR-051（ツール別テーブル）

## コンテキスト

claudedog（旧 claude-stats）は hook/cron 経由で収集した拡張データをもとに Claude Code の人の介入率を追跡・可視化する計測ツールだが、次の問題がある。

1. **ADR 駆動開発との不一致**: UI 調整やメトリクス追加など試行錯誤的な開発が多く、毎回 ADR を作成するのは冗長
2. **ADR の占有**: docs/adr/ 全体 51 件中 7 件（約 14%）が claudedog 関連で、今後も増加傾向
3. **実装の散在**: `configs/claude/scripts/` に 8 ファイルが他の Claude Code スクリプト（approve-safe-commands.py, redirect-to-tools.py 等）と混在しており、ディレクトリレベルでの凝集性が乏しい

別リポジトリへの分離も検討したが、claudedog は hook 登録（`settings.json`）やシンボリックリンク管理など dotfiles と密結合しているため、リポジトリ内でのディレクトリ隔離が妥当と判断した。

また、ディレクトリ隔離に伴い開発プロセスも分離する。dotfiles 本体は引き続き ADR 駆動で開発するが、claudedog は TODO.md + CHANGELOG.md ベースの軽量プロセスに移行する。ADR の「受け入れ条件による完了判定」は TODO.md の完了条件として軽量に継承し、意思決定の履歴は git log + CHANGELOG で追跡する。

## 設計案

### 案A: トップレベル `claudedog/` ディレクトリに集約（採用）

```
claudedog/
├── hooks/                     # Claude Code hook スクリプト（データ収集層）
│   ├── session-index.sh           <- configs/claude/scripts/session-index.sh
│   ├── permission-log.sh          <- configs/claude/scripts/permission-log.sh
│   └── pretooluse-track.sh        <- configs/claude/scripts/pretooluse-track.sh
├── batch/                     # cron/バッチ処理（データ補完層）
│   ├── session-index-update.py    <- configs/claude/scripts/session-index-update.py
│   └── session-index-backfill-batch.py <- configs/claude/scripts/session-index-backfill-batch.py
├── dashboard/                 # Web UI（可視化層）
│   └── server.py                  <- configs/claude/scripts/permission-ui-server.py
├── claudedog                  <- configs/claude/scripts/claude-stats（CLI エントリポイント）
├── TODO.md                    # やること + 完了条件（事前）
├── CHANGELOG.md               # 変更履歴（事後）
└── README.md
```

- `configs/claude/settings.json` の hook パスを `claudedog/hooks/` を指すように変更
- `configs/claude/scripts/` には claudedog 以外のスクリプトのみ残す

**開発プロセスの変更:**
- claudedog の変更は ADR を作成しない。`TODO.md` に「やりたいこと + 完了条件」を箇条書きし、完了後に `CHANGELOG.md` へ記録する
- `docs/development.md` に「claudedog ディレクトリ内の変更は ADR 不要、TODO.md + CHANGELOG.md で管理」ルールを追記
- 既存の claudedog 関連 ADR（011, 036, 041-043, 049, 051）はそのまま残す（過去の意思決定記録として有効）

### 案B: 別リポジトリに完全分離（却下）

hook 登録・シンボリックリンク管理が dotfiles 側にあるため、install.sh で結合を再構築する手間が増えるだけで実質的なメリットが薄い。

### 変更が必要なファイル
| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `claudedog/` | dotfiles | 新規ディレクトリ作成、8 ファイル移動 |
| `configs/claude/scripts/` | dotfiles | claudedog 関連 8 ファイル削除 |
| `configs/claude/settings.json` | dotfiles | hook パスを `claudedog/hooks/` に変更 |
| `docs/development.md` | dotfiles | claudedog の開発プロセス（TODO.md + CHANGELOG.md）ルール追記 |
| `claudedog/TODO.md` | dotfiles | 新規作成 |
| `claudedog/CHANGELOG.md` | dotfiles | 新規作成 |
| `docs/reference.md` | dotfiles | claudedog コンポーネントの記載更新 |

## 受け入れ条件
> [issues.md](../issues.md)（ADR-052 セクション）
