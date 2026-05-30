# ADR-071: 元セッション主導の反復レビューループ（review-loop 再設計）

## ステータス
採用済み

## 関連 ADR
- 依存: ADR-070（headless コーディネータ方式を置換する。完了マーカー検知・codex の stdout エコー対策・pane_id 固定の実装知見は継承する）
- 関連: ADR-059（dispatch / orchestrate の連携モード分離 — review-loop は第3モードとして残る）
- 関連: ADR-060（orchestrate のファイルハンドオフ機構 — レビュー結果ファイルの受け渡しに踏襲）

## コンテキスト

ADR-070 で実装した review-loop（`launch` → バックグラウンドの `advance_loop` が実装役・レビュー役の両方を新規プロセスとして生成し `tmux` 上で交互駆動する headless コーディネータ）は受け入れ条件を満たして完成した。しかし**実利用で想定するフローと制御モデルが根本的に噛み合っていない**ことが判明した。

実際に望むフローは次のものである:

1. 一通り実装が終わった段階で起動する
2. 同一 tmux session 内にレビュー用セッションを起動してレビューさせる
3. **実装した本人＝元 coding session** がレビュー結果を受け取って自分で修正する
4. レビュー用セッションが再レビューする（収束まで最大 N 回）

これに対し ADR-070 の実装は次の構図であり、別物である:

| 論点 | ADR-071 で望む形 | ADR-070 の実装 |
|---|---|---|
| 制御の主体 | 元 coding session がループを主導 | バックグラウンドの `advance_loop`（bash）が全制御。元セッションは launch 後に離脱 |
| 実装（修正）役 | 元 coding session（実装文脈を保持する本人） | `advance_loop` が生成する新規 claude プロセス（実装文脈ゼロ。レビュー指摘テキストのみ受領） |
| tmux セッション | 現 session に pane を追加 | 専用 `review-loop-<id>` セッションを新規作成して隔離 |
| 開始フェーズ | 起動直後にまずレビュー（実装は完了済み前提） | round1 は必ず実装役の実装から開始 |
| ロール | 実装役＝元セッション、レビュアー＝その逆エージェント（自動決定） | `--implementer`/`--reviewer` で claude↔codex を対称に入替可能 |
| 起動引数 | ユーザー向け引数なし（引数レス起動） | 位置引数（タスク/観点）必須 + 複数オプション |

最も効いている乖離は **「修正するのは実装した本人」** という一点である。ADR-070 は実装文脈を持たない新規 claude にレビュー指摘の文字列だけを渡して直させる設計で、実装意図を活かした反映ができない。これは review-loop というより「タスク記述とレビュー観点を投げると別空間で勝手に実装・修正する全自動ジェネレータ」であり、当初の利用イメージとは異なるコンセプトの実装だった。

そこで **ADR-070 の中核決定（headless コーディネータによる対称な claude↔codex 交互駆動）を変更し**、制御の主体を元セッションに反転させる。

## 設計案

### 案A: 元セッション主導 + レビュアーをサブプロセスとして起動（採用）

制御の主体を bash の `advance_loop` から**元 coding session（review-loop skill を起動した Claude 自身）**に移す。bash スクリプトは「レビュアーを1ターン起動する」「レビュー完了マーカーを待つ」だけの薄いユーティリティに縮小し、ループ制御・修正・収束判定は元セッションが SKILL.md の手順として実行する。

- **実装（修正）役 = 元セッション（私）に固定。** 実装役を別プロセスとして生成しない。ADR-070 の `--implementer` によるロール入替は廃止する。
- **レビュアーは実装役（元セッション）の逆エージェントに自動決定する。** 元セッションが claude なら codex が、codex なら claude がレビューする。これにより「実装したのとは異なるモデルの目で見る」という cross-agent レビューの本質を維持する。レビュアーを選ばせるユーザー向け引数（`--reviewer`）は設けない。元セッションは自分のエージェント種別を知っているため、SKILL.md の手順を実行するエージェント自身が「自分の逆」を選んで `review-once` を呼ぶ。
- **レビュアーは同一 tmux session に新規 window/pane で起動する。** codex レビュアーは `codex exec -s read-only`（headless、stdout をレビュー結果ファイルにリダイレクト捕捉）、claude レビュアーは TUI のため verdict を指定ファイルに書かせる。専用 tmux session は作らない。
- **ユーザー向けの起動引数を持たない（引数レス起動）。** ADR-070 の位置引数（タスク/観点）・`--implementer`・`--reviewer`・`--max-rounds`・`--base` をすべて廃止する。レビュー観点・レビュー基点（base）・最大ラウンド数などを調整したい場合は skill 起動時の自然言語指示として元セッションが受け取り、内部的に `review-once`/`wait-review` のフラグへ変換する。これらのフラグ（reviewer 種別・base・round 番号・出力先）は SKILL.md 手順から呼ぶ**内部インターフェース**であり、人間が直接渡す引数ではない。
- **レビュー完了待ちは「tmux pane 非同期起動 + マーカー待ち + 完了通知で再開」**とする。元セッションはレビュアーを pane で起動した後、`wait-review` を **background 実行**してレビュー結果ファイルに `REVIEW_RESULT` 行が現れるまで待つ。マーカー検知＝background プロセス終了で元セッションが再開する。Claude Code はターンベースで `advance_loop` のような常駐ループを持てないため、この非同期待ち＋再開が制御反転の要となる。
- **起動直後の最初の動作はレビュー**（実装は完了済み前提）。round1 = レビューから開始する。
- **ループ・収束判定・修正は元セッションが担う。** 再開した元セッションがレビュー結果ファイルを読み、`REVIEW_RESULT: APPROVED` なら収束終了、`CHANGES_REQUESTED` なら自分で差分を修正して次ラウンドのレビュアーを起動する。最大 N ラウンド（既定 3）で打ち切る。

ADR-070 から継承する実装知見（再設計後も有効）:
- 完了検知はプロセス終了や capture-pane ではなく**エージェントが書く完了マーカーファイル**（レビュー結果ファイルの `REVIEW_RESULT` 行）に依存する。
- レビュアープロンプトに判定パターン `REVIEW_RESULT: <verdict>` をリテラルで含めない（codex exec はプロンプトを stdout にエコーするため誤検知する）。selftest に回帰ガードを残す。
- tmux-sidebar 等の pane 自動追加による send-keys 誤爆を防ぐため、起動時に pane_id を固定する。
- 現在の worktree（レビュー対象ブランチ）上で動き、新規 worktree は作らない。
- `claude -p` / `--print` は使わない（レビュアーが claude のとき。subscription 課金を維持）。

ライブ検証で判明した追加知見:
- codex exec の出力捕捉は `2>&1` で stderr を合流させない。codex は hook/進捗ログ（`hook: PostToolUse` 等）を stderr に大量に出すため、合流させるとレビュー結果ファイルがそれらで汚染される（完了検知・収束判定は最終行の `REVIEW_RESULT` で行うため誤動作はしないが、レビュー本文が読めなくなる）。stdout のみを `round-N-review.md` に、stderr は `round-N-review.md.log` に分離する。selftest に回帰ガード（`2>&1` 非混入 / `.log` 分離）を置く。

なお、レビュアーが claude になるのは**元セッションが codex のときのみ**である。この場合 read-only sandbox による強制がないため「コードを変更しない」はプロンプト指示への依存となる（codex レビュアーは `-s read-only` で機構的に保証される）。cross-agent の目を入れる利点を優先してこの非対称を許容する。

### 案B: ADR-070 の fire-and-forget アーキを部分修正して流用（却下）

`advance_loop` を残したまま「round1 をレビューから開始する」「専用 session を作らず現 session に window を足す」等の部分修正で寄せる。

**却下理由**: 最大の乖離である「修正役＝実装文脈を持つ元セッション」が満たせない。`advance_loop` は別プロセスとして実装役を駆動する構造で、元セッション（=launch を呼んだ Claude 自身）をループ内の実装役として組み込めない。部分修正では当初の利用イメージに到達しないため、制御主体の反転（案A）が必要。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/skills/review-loop/SKILL.md` | dotfiles | 全面改訂。`argument-hint` を削除（引数レス起動）。元セッション主導のループ手順（自分の逆エージェントでレビュー起動 → background 待ち → 再開 → 自己修正 → 反復）に書き換え |
| `configs/claude/skills/review-loop/review-loop.sh` | dotfiles | 縮小再編。`advance_loop`・実装役駆動・専用 tmux session 作成を削除。サブコマンドを `review-once`（現 session に reviewer pane を起動）/ `wait-review`（マーカー待ち）/ `cleanup` / `selftest` に再構成。`rl_build_reviewer_prompt` / `rl_resolve_base_ref` / `rl_review_converged` / マーカー待ち / pane 操作は流用 |
| `docs/adr/070-cross-agent-review-loop.md` | dotfiles | ステータスを `廃止（ADR-071 で置換）` に更新（実装済み）|
| `docs/reference.md` | dotfiles | 連携モード表の review-loop の記述を元セッション主導モデルに更新（実装後）|

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-071 セクション）
