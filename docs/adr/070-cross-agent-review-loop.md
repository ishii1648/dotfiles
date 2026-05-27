# ADR-070: headless コーディネータによる claude↔codex 反復レビューループ

## ステータス
Draft

## 関連 ADR
- 関連: ADR-059（dispatch / orchestrate の分離 — 本 ADR は第3の連携モードを追加する）
- 関連: ADR-060（orchestrate v4 のエージェントチェーン — wait-for + ファイルハンドオフ機構を踏襲する）
- 関連: ADR-065（dispatch の codex attached client 待機 — codex 起動の癖を回避する背景）

## コンテキスト

`/dispatch` は別セッションへの**片方向**起動・送信のみを提供する。`/orchestrate` は planner→tdd→reviewer のように各エージェントが1回ずつ走る**線形チェーン**で、各段は1回実行して終了し、ハンドオフ文書で次へ引き継ぐ。

しかし「claude が実装 → codex がレビュー → claude が指摘を反映 → codex が再レビュー → 収束まで」のような**同一ペアの反復（循環）フロー**を自動化する手段がない。現状この往復は人間が手動で中継している（capture-pane ポーリング・手動コピペ）。

加えて制約として、`claude -p` / `--print`（headless モード）は料金体系が変更され subscription 外の従量課金になったため、ループで繰り返し叩く用途では使わない。interactive な `claude < file`（stdin redirect、EOF で終了）は subscription 内で完結し、dispatch.sh / orchestrate.sh が既に採用している。

## 設計案

### 案B': headless コーディネータ（採用）

新規 skill `review-loop` を追加し、実装役とレビュー役を `tmux wait-for` で交互に駆動する。

**ロールは固定しない。** 既定は実装役=claude / レビュー役=codex だが、`--implementer` / `--reviewer`（各 `claude|codex`）で入れ替えられる。エージェントごとの非対称性を起動コマンド生成（`rl_build_agent_cmd`）に集約して吸収する:
- claude はどのロールでも interactive `--session-id`/`--resume`（文脈保持・subscription）。レビュー役のときは TUI 出力を捕捉できないため verdict を指定ファイルに書かせる（プロンプトで指示）。
- codex はどのロールでも headless `codex exec`。レビュー役は `-s read-only`（stdout 捕捉）、実装役は `-s workspace-write`（worktree 編集）。
- 収束判定はレビュー出力ファイル（codex は stdout リダイレクト、claude はファイル書き出し）の `REVIEW_RESULT:` 最終行を読む（agent 非依存）。

以下は既定（claude→codex）を例にした駆動の説明である。

- **claude（実装役）**: `claude --resume <session-id> < prompt_file; tmux wait-for -S <signal>` で interactive 起動する。`-p` は使わず subscription 内に収める。`--resume` でラウンド間の文脈（実装意図・前回の議論）を保持する。プロセス終了＝完了シグナルとなるため、idle 推測も send-keys 注入も不要。
- **codex（レビュー役）**: `codex exec review` / `codex review`（headless）で現在の作業ツリーの diff をレビューさせ、指摘をファイルに捕捉する。codex exec も終了時に `tmux wait-for -S <signal>` で完了通知する。
- **コーディネータ**: orchestrate の `advance_loop` 同様、バックグラウンドで `tmux wait-for <signal>` をゼロコスト待機し、各ラウンドの出力ファイルを読んで「継続 / 終了」を判定し、次のロールを起動する。
- **ハンドオフ**: 各ラウンドで codex の指摘と claude の応答をファイル（`reviews/round-N-codex.md` 等）に残す。
- **終了条件**: codex の指摘がゼロ／承認マーカー検出、または最大 N ラウンド（既定 3）到達で収束終了する。
- 同一 worktree 上で claude の編集と codex のレビューを**逐次**実行するため競合しない（並行編集なし）。新規 worktree は作らず、レビュー対象ブランチの現在の worktree で動く。

### 案A: 永続セッション + mailbox + send-keys 注入（却下）

claude / codex を対話 TUI として常駐させ、ファイル mailbox（inbox per pane）にメッセージをキューし、Stop hook で inbox を drain して相手 pane が idle のとき send-keys で注入する。通知は PostToolUse/Stop Hook → アイドル検知 → 人間フォールバックの3層。

**却下理由**:
- send-keys 注入とアイドル検知の脆弱性 — これはユーザが実際に手動中継に陥った直接の原因（送っても気づかない／capture-pane ポーリングの完了検知が不安定）。構造化レビューループに同じ脆さを持ち込む。
- ラウンドを重ねると常駐セッションのコンテキストが無制限に膨張する。
- プロセス終了という明確な完了シグナルがなく、決定論的にテストできない。
- codex TUI の起動の癖（ADR-065 の OSC 11 / stdin redirect 非対応）を抱え続ける。

mailbox/IPC 方式は「人間が多数セッションを緩く監督し、対等なセッション同士が ad-hoc に『終わった』『どうなった』と突く」用途には適する。だが終了条件が明確で離散的なレビューループにはオーバースペックかつ脆い。両者は用途が異なるため統合しない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/skills/review-loop/SKILL.md` | dotfiles | 追加（skill 定義） |
| `configs/claude/skills/review-loop/review-loop.sh` | dotfiles | 追加（コーディネータ本体: launch / advance ループ / cleanup） |
| `~/.claude/skills/review-loop` | 配布先 | 追加（dotfiles 実体への symlink、setup.sh / codex-sync 経由） |
| `docs/reference.md` | dotfiles | 連携モード表に review-loop を追記（実装後） |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-070 セクション）
