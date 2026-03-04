# ADR-040: session-index pr_urls バックフィルを cron バッチ方式に移行する

## ステータス

採用済み

## コンテキスト

ADR-039 で Stop フック終了時に fire-and-forget で `gh pr view` を実行する backfill を実装した。
しかしこの方式には以下の構造的な問題がある。

- 過去分が拾えない: ADR-039 採用以前に記録されたセッション、または Stop フックが正常に発火しなかったセッションの `pr_urls` は永遠に空のまま残る
- 重複 API 呼び出し: 同一 branch で複数セッションが存在する場合、セッション数分だけ `gh pr view` が呼ばれる
- Stop フックの複雑性: session-index.jsonl の読み込み・Popen 起動ロジックが Stop フックに混入している

定期バッチ処理（launchd / cron）で `session-index.jsonl` の全エントリを走査し、`pr_urls` が空のものを repo+branch でまとめて補完する方式に移行することで、これらの問題をまとめて解決できる。

## 設計案

### 案A: launchd / cron で定期バッチ実行（採用）

`configs/claude/scripts/session-index-backfill-batch.py` を新規作成し、定期実行する。

**バッチスクリプトの動作:**

1. `~/.claude/session-index.jsonl` を全走査して `pr_urls` が空のエントリを抽出
2. `(repo, branch)` でグループ化し重複排除
3. 各グループに対して `gh pr view <branch> --json url -q '.url'` を実行（cwd は同グループの最新エントリの cwd を使用）
4. URL が取得できた場合、同グループの全 session_id に対して `session-index-update.py` で補完

**スケジュール登録:**

- macOS: `configs/claude/launchd/com.user.session-index-backfill.plist` を作成し `~/Library/LaunchAgents/` へ配布
  - `StartCalendarInterval`: 毎時実行
  - `RunAtLoad: true`: ログイン時に missed 分を即時補完
- Linux: `configs/claude/scripts/session-index-backfill-batch.py` を crontab で登録（`setup.sh` の claude コンポーネントで案内）

**ADR-039 との関係:**

- `session-index-stop.sh` から backfill ロジック（else ブランチ）を削除し、元のシンプルな形に戻す
- `session-index-backfill.py`（ADR-039 で作成）を削除
- ADR-039 を部分廃止（本 ADR で移行）

### 案B: Stop フック backfill を維持しつつバッチを追加（却下）

却下理由: Stop フックの複雑性が残り、`gh pr view` の重複呼び出しも解消されない。過去分補完はバッチだけで対応できるため、Stop フックのロジックを維持する理由がない。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-040 セクション）

## 関連 ADR

- 部分廃止: [ADR-039](039-session-index-pr-url-backfill-on-stop.md)（Stop フック backfill → 本 ADR のバッチ方式に移行）
- 依存: [ADR-011](011-claude-session-index.md)（session-index の基本設計）
- 依存: [ADR-035](035-claude-session-index-startup-optimization.md)（SessionStart の `gh pr view` 削除）
