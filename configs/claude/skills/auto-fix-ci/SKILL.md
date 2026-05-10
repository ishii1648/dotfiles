---
name: auto-fix-ci
description: PR push 後の GitHub Actions CI を Monitor tool で継続監視し、失敗ジョブのログを取得して原因診断 → 修正 → 再 push のループを自動実行する。`git-ship` 完了直後に自動連結されるほか、「ci 直して」「fix ci error」「auto-fix-ci」「PR の CI 見て」「CI 監視して」などのトリガーで起動。
---

# auto-fix-ci

PR を push した後の CI を見守り、失敗があれば原因を特定して修正・再 push を繰り返す。すべて pass するか、ユーザー介入が必要な失敗に達するまでループする。

## 前提条件

実行前に以下を確認する。満たさなければ実行しない：

1. `feat/`, `fix/`, `docs/`, `chore/` のいずれかで始まるブランチ上にいる（`main` 上では実行しない）
2. そのブランチ向けに open PR が存在する（`gh pr view --json number` で取得可能）
3. `gh` CLI が認証済みで、対象 repo にアクセスできる
4. working tree がクリーン（push 済みで未コミット変更がない）

## コアフロー

### Step 1: PR 番号を特定

```bash
gh pr view --json number -q '.number'
```

取得した番号を以降 `<PR>` として扱う。

### Step 2: Monitor tool で CI を watch

**Monitor tool を呼ぶ。** 直接 sleep ループや poll を Bash で回さない（Monitor が cache 効率と通知配信を担保する）。

Monitor の `command` には以下を渡す（`<PR>` は実数で置き換える）:

```bash
prev=""
while true; do
  s=$(gh pr checks <PR> --json name,bucket 2>/dev/null) || { echo "gh failed, retrying"; sleep 30; continue; }
  cur=$(jq -r '.[] | select(.bucket!="pending") | "\(.name): \(.bucket)"' <<<"$s" | sort)
  comm -13 <(echo "$prev") <(echo "$cur")
  prev=$cur
  jq -e 'all(.bucket!="pending")' <<<"$s" >/dev/null && { echo "ALL_DONE"; break; }
  sleep 30
done
```

- `description`: `"CI checks for PR <PR>"`
- `timeout_ms`: 900000（15 分）。長い test suite を走らせる repo なら 1800000 に上げてもよい
- `persistent`: false

各 check が pending → 確定状態に遷移するたび 1 行（`<name>: pass|fail|cancel|skipping`）が通知され、すべて確定したら `ALL_DONE` で exit する。

### Step 3: 結果判定

`ALL_DONE` 通知を受けたら最終状態を確定する:

```bash
gh pr checks <PR>
```

- 全 check が `pass` → **終了**。PR URL を出して報告して完了。
- `fail` がある → Step 4 へ。
- `cancelled` / `skipping` のみ → 状況を見て手動再実行か終了を判断。

### Step 4: 失敗ログ取得と原因診断

各失敗 check について URL から `<run-id>` と `<job-id>` を抽出（URL 形式: `.../actions/runs/<run-id>/job/<job-id>`）し:

```bash
gh run view <run-id> --job <job-id> --log-failed | tail -80
```

を取得して読む。複数失敗ジョブがある場合は **並列に取得**（依存関係がないため）。

#### よくある失敗パターン
- **golangci-lint バージョン不整合**: `go.mod` の go directive を上げると古い golangci-lint が target できなくなる → action の version を上げ、`.golangci.yml` を新 syntax に migrate
- **govulncheck stdlib vuln**: 検出された vuln の `Fixed in:` バージョンを見て `go.mod` の go directive を bump
- **Docker build go version mismatch**: `Dockerfile` の golang base image を `go.mod` の directive と合わせる
- **gofmt drift**: `gofmt -w` で再整形
- **go mod tidy drift**: `go mod tidy` で go.mod / go.sum を更新
- **transient runner failure（network / 5xx）**: `gh run rerun <run-id> --failed` で再実行のみ

### Step 5: 修正 → commit → push

1. 修正をローカルで適用し、可能ならローカルで再実行して緑になることを確認（例: `go vet ./... && go build ./... && go test -race ./...`）
2. 関連ファイルだけ stage（`git add -A` は使わない）
3. `contextual-commit` skill を呼んで commit を作成
4. `git push`

### Step 6: Step 2 に戻る

新しい push で CI が再走するので、再度 Monitor で watch する。

## ループ終了条件

- **成功**: 全 check pass → PR URL を出して終了
- **試行回数上限**: 同一 PR に対する自動 fix push が **5 回** に達した → ユーザーに報告して停止
- **同じエラーの繰り返し**: 直前の修正と同じ症状が連続 2 回出た → 自動修正不能と判断、ユーザーに報告して停止
- **手動介入必須の失敗**: secrets 不足、外部サービス障害、権限エラー、`required reviewers` 未充足など → 状況を報告して停止
- **ローカル再現で破綻**: ローカル環境で修正が再現できない（CI 固有の環境差） → 報告して停止

## ガードレール

- **destructive action 禁止**: `git push --force`, `git reset --hard`, branch 削除, PR close は行わない
- **`--no-verify` 禁止**: pre-commit hook が落ちたら根本原因を調べる
- **推測による fix 禁止**: ログから根本原因が読み取れない場合は修正せずユーザーに報告
- **scope crawl 禁止**: CI 緑化に必要最小限の変更のみ。「ついでに refactor」は別 PR
- **secrets を log に出さない**: ログ取得時は `tail` で末尾だけに絞り、誤って secrets を session に流さない

## 報告フォーマット

完了時は以下のいずれかで報告する：

- 成功: `CI 全 check 緑。PR: <URL>`
- 試行上限: `自動 fix を 5 回試したが緑にならず停止。最後の失敗: <job> / <要約>`
- 介入必須: `手動対応が必要な失敗を検知して停止。<job>: <理由>`

## 例

git-ship が `https://github.com/owner/repo/pull/57` を返した直後:

1. PR 番号 57 を取得
2. Monitor で watch → `lint: fail`, `govulncheck: fail`, `build: fail` が連続通知
3. それぞれの `--log-failed` を並列取得し診断:
   - lint: golangci-lint v1.64 が Go 1.25 target 不可
   - govulncheck: stdlib に GO-2026-XXXX
   - build: Dockerfile が古い base image
4. 3 件まとめて 1 commit で修正（go.mod bump + golangci-lint v2 移行 + Dockerfile bump）
5. push
6. Monitor で再 watch → 全 pass で終了
