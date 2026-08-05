# ADR-086: herdr の workspace 新規作成時に claude session を自動起動する

## ステータス

採用済み

## 関連 ADR

- 依存: [ADR-076](076-herdr-migration-from-tmux.md)（herdr への移行。plugin system・`agent start` CLI の存在はこの移行が前提）
- 依存: [ADR-077](077-new-workspace-ghq-picker.md)（拡張対象の `configs/herdr/new-workspace.sh` を実装した ADR）

## コンテキスト

`prefix+p`（`configs/herdr/new-workspace.sh`、ADR-077）で新しい repo の workspace を作ると、新規 pane はシェルプロンプトで止まったままになり、そこで毎回手動で `claude` を起動している。

herdr 0.7.5 の CLI を調査した結果、以下が判明した：

- `herdr workspace create` は socket API のレスポンスをそのまま JSON で stdout に出力する。実測（`--cwd /tmp --label test-auto-claude-probe --no-focus`）:
  ```json
  {"id":"cli:workspace:create","result":{"root_pane":{"pane_id":"wF:p1", ...}, "type":"workspace_created", "workspace":{...}}}
  ```
  `.result.root_pane.pane_id` で新規 pane の ID が直接取れる（追加の `api snapshot` 問い合わせは不要）
- `herdr agent start <NAME> --kind claude --pane <ID>` で、既存 pane（シェルプロンプト状態）に claude を起動できる。`<NAME>` は `[a-z][a-z0-9_-]{0,31}` に従う任意のラベルで、**live agent 間で一意である必要がある**（公式ドキュメント: "Names are unique among live agents"）
- herdr には `[[events]] on = "workspace_created"` 形式の plugin event hook 機構もあり、`workspace_created` は API プロトコルスキーマの `EventKind` enum にも存在し、実測した `workspace create` レスポンスの `"type":"workspace_created"` とも表記が一致する（プラグイン経由なら組み込みの `new_workspace`（`prefix+shift+n`）を含む全ての workspace 作成経路を捕捉できる）

## 設計案

### 案A: `configs/herdr/new-workspace.sh` に直書きする（採用）

`workspace create` 呼び出し直後に、そのレスポンス JSON から `pane_id` を取り出し、同じスクリプト内で `herdr agent start` を呼ぶ。

採用理由:

- 実際に「space を追加する」運用上の主経路は `prefix+p`（このスクリプト）であり、組み込みの `prefix+shift+n`（cwd 継承のみで repo を選べない）は日常的に使っていない
- 既存スクリプトの延長で数行の追加に収まり、プラグイン一式（`herdr-plugin.toml` の新規作成・`herdr plugin link` での有効化）を新設するコストがかからない
- `workspace create` のレスポンスから `pane_id` を直接取れるため、案Bのような別プロセス起動・イベント経由の非同期処理を挟まずに済み、実装・デバッグが単純

### 案B: plugin event hook（`on = "workspace_created"`）で捕捉する（見送り）

`herdr-plugin.toml` に `[[events]] on = "workspace_created"` を宣言し、任意の workspace 作成経路（組み込み `new_workspace` を含む）を横断的に捕捉する。

見送り理由:

- 組み込み `new_workspace`（`prefix+shift+n`）は cwd 継承で作るだけの用途として温存しており（ADR-077）、そちら経由でも自動起動したいという要求は今回ない
- plugin システム自体が本 dotfiles での実績ゼロで、`herdr-plugin.toml` のフィールド仕様・`command` 実行時の環境変数（`HERDR_PLUGIN_EVENT_JSON` 等）を今回のスコープで検証するのは過剰
- 案Aで要件（`prefix+p` 経由の自動起動）を満たせる。案Bが必要になるのは「組み込み `new_workspace` でも自動起動したい」という要求が出た時点で十分

## 設計上の判断

- **agent の `NAME` は `pane_id` から導出する**: `NAME` は live agent 間で一意である必要があり、複数 workspace で同時に claude を起動する運用がある以上、固定文字列（`claude` 等）は使えない。新規 pane の `pane_id`（例 `wF:p1`）は作成直後の時点で必ず一意なので、コロンを除去し小文字化した `claude-wfp1` のような名前を組み立てる
- **`agent start` の失敗は fatal にしない**: `workspace create` は既に成功しており、workspace 自体は使える状態になっている。claude の自動起動に失敗しても（herdr 側の一時的な不調、pane がまだプロンプトに達していない等）、ユーザーはそのまま手で `claude` を起動すれば足りる。既存の `die()`（popup を閉じずエラー表示してキー入力待ち）は使わず、ログに warn を残すだけで popup は通常どおり閉じる
- **既存 workspace への `focus` 分岐では起動しない**: 同じ repo の workspace が既にある場合は `herdr workspace focus` のみを行う分岐が既存実装にある。既存 workspace には他の作業状態が残っている可能性があるため、新規作成時（`workspace create` 実行時）のみ claude を自動起動する

## 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/herdr/new-workspace.sh` | `workspace create` のレスポンス JSON から `pane_id` を取り出し、`herdr agent start <name> --kind claude --pane <pane_id>` を追加で呼ぶ |

## 実機投入後に判明した問題と対処

初回実装では `agent start` を `--timeout`（デフォルト 30 秒）の待機ロジックに任せれば pane 起動直後の競合は吸収されると判断し、追加の待機を入れなかった。実際に `Cmd+Shift+S` から使ったところ、毎回 `{"error":{"code":"agent_pane_busy","message":"agent target pane wK:p1 is not an available shell"}}` で失敗した（`~/.local/state/herdr/new-workspace.log` で確認）。

原因調査:

- 同じ `workspace create --focus` → 即 `agent start` の順序を、popup の外（このセッションの Bash ツール）から手動で再現したところ、`/tmp` でも実際に問題が起きた `aws-infra` repo でも**毎回即成功**し、再現しなかった
- 差分は「`type = "popup"`（モーダル端末）の中から呼んでいるか」のみに見える。popup がまだ端末を専有している間は新規 pane 側のシェルが対話可能状態に達しない、popup 固有のタイミング問題と推測されるが、herdr のドキュメントに `agent_pane_busy` の説明や回避策の記載はなく、確証は取れていない
- `--timeout` は「pane が対話可能になるまで待つ」仕様だが、`agent_pane_busy` は待機に入らず即座にエラー応答を返しており、`--timeout` ではこの失敗パターンを吸収できないことが実測で判明した（設計時の想定が誤りだった）

対処: `agent start` の呼び出し自体を最大 10 回・0.5 秒間隔でリトライするループに変更した（対症療法。herdr 側の根本原因は未確認）。

### リトライがユーザーに再確認され、popup のクローズ遅延が新たに判明

claude 自動起動は成功したが、リトライループを popup の終了前（= スクリプトの exit 前）に同期的に待っていたため、repo 選択直後に閉じるはずの popup が最大 5 秒程度遅延して閉じるようになった。

対処: リトライループ（`launch_claude_retry`）を `&` でバックグラウンド化し、`disown` して popup の待機対象から外した。スクリプト側は `workspace create` の成否のみを見届けて即 exit し、popup は repo 選択直後に閉じる。バックグラウンド化の効果はスタンドアロンのシェルスクリプトで実測済み（親プロセスは即座に exit し、バックグラウンド側は独立して完了する）。

残る未検証事項: herdr がこの popup を閉じる際にプロセスグループごと終了させる実装だった場合、`trap '' HUP` による SIGHUP 無視だけでは巻き込まれて途中終了する可能性がある（`setsid` 相当の完全なセッション分離ではない）。macOS には `setsid` コマンドが無いため、この対策は見送っている。実機で claude が起動しない場合はこの経路を疑う。

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-086 セクション）
