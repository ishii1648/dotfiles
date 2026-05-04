# ADR-062: popup ランチャーの codex モードを dispatch 化する（フェーズ2）

## ステータス
廃止（ADR-069 で置換）

> codex モードの worktree 作成 + 初期 prompt 投入（フェーズ2 仕様）は upstream `tmux-sidebar new` の `internal/dispatch.Launch` に同等実装される形で移管された（`Launcher LauncherCodex`、`CreateWorktree`、`writePromptFile` の各処理）。本 ADR の決定は upstream 側に統合されたため廃止。

## 関連 ADR
- 依存: ADR-061（codex モードのフェーズ1 仕様（worktree なし・prompt 投入なし）を上書き）
- 関連: ADR-054（dispatch skill — `dispatch.sh` を共通化する基盤）
- 関連: ADR-056（dispatch/orchestrate popup ランチャー — Step 2 UI を流用）

## コンテキスト

ADR-061 で popup ランチャーのトップレベルモードを `claude` / `codex` に再構成したが、codex モードは「リポジトリ選択 → tmux session 作成 → `codex` 起動のみ」のフェーズ1 最小実装に留めた。

実運用では codex モードでも claude モードと同様に「ブランチ／worktree を切ってから初期プロンプトを渡して起動」したいケースが多い。フェーズ1 の単純起動だけだと、毎回 codex 起動後にブランチ操作とプロンプト入力を手動で行う必要があり、claude モードとの操作モデル非対称が大きい。

### codex CLI 入出力契約の調査結果（2026-04-26 / `.outputs/claude/codex-cli-contract-survey.md`）

| 項目 | 結果 | 含意 |
|---|---|---|
| TUI モードの stdin プロンプト | **不可**（`Error: stdin is not a terminal`） | claude の `claude < $prompt_file` パターンは流用不可 |
| 初期プロンプト引数 | `codex [PROMPT]` の位置引数で受付可 | `tmux send-keys` で `codex "$(cat ...)"` 形式が現実的 |
| 作業ディレクトリ指定 | `-C/--cd <DIR>` | worktree パスを明示的に渡せる |
| skill 機構 | あり（SKILL.md 形式、claude と互換） | 将来 codex 内 dispatch skill 化も可能（本 ADR では対象外） |

### ADR-061 の決定変更

ADR-061 は採用済み（フェーズ1 完了）だが、以下 2 点が本 ADR で上書きされる：

- 「codex モードは worktree 作成なし、prompt 投入なし」（ADR-061 設計セクション）
- 「codex モードの初期実装（フェーズ1）」セクションの仕様一式

その他の決定（トップレベル 2 値モード化、PRs モード廃止、候補ソース統一、`tab` でモード切替）は引き続き有効。

## 設計

### 案A: `dispatch.sh` に `--launcher` フラグを追加して共通化（採用）

dispatch.sh の launcher を可変にし、起動コマンド部分だけを分岐する。worktree 作成・session/window 管理・prompt 一時ファイル配置は完全共通化。

- `--launcher claude|codex`（既定 `claude`）を追加
- 既存の `--no-worktree` / `--no-prompt` / `--branch` / `--prompt-file` はすべて両 launcher で共通動作
- `tmux send-keys` の起動コマンド部分のみ launcher に応じて切替
  - claude: `cd '$work_dir'; claude < '$prompt_file'`（既存）
  - codex: `cd '$work_dir'; codex -C '$work_dir' "$(cat '$prompt_file')"`
  - `--no-prompt` 時は launcher 名のみ送る
- session 命名規則 `<repo>@<wt-name>` は両 launcher で共通
- `~/.config/dispatch/no-worktree-repos` 設定は両 launcher で共通参照

採用理由:
- worktree 作成・session 管理・branch checkout など 90% のロジックが launcher 非依存
- 将来別 launcher（例: aider, cursor-cli）追加時も同じパターンで拡張可能
- ADR-054 dispatch skill の意図（「軽量な dispatch」）と整合
- claude モードと同じ Step 2 UI（`:branch-name` プレフィックス含む）を codex で再利用できる

### 案B: codex 専用スクリプト `codex-dispatch.sh` を新設（却下）

`dispatch.sh` を claude 専用のまま残し、`configs/claude/skills/codex-dispatch/codex-dispatch.sh` を新設して codex モードはそちらを呼ぶ。

却下理由:
- worktree 作成・session 管理ロジックの重複が発生し、長期メンテで乖離する
- 将来 launcher を追加するたびに新スクリプトが増殖する
- ADR-054 dispatch skill の「単一エントリ」設計から外れる

### 案C: `codex exec` で非対話バックグラウンド実行（却下）

`codex exec --cd $wd < $prompt_file` で非対話モードを使い、結果を `--output-last-message` で受ける。

却下理由:
- ユーザが対話継続できない（exec は ワンショット実行）
- claude モードとの操作モデル乖離が大きい
- dispatch の本旨（「対話セッションを別ウィンドウで開いておく」）と矛盾

### prompt 投入方式の詳細（案A の補足）

```bash
# claude（既存）
tmux send-keys -t "=$session:$window" "cd '$work_dir'; claude < '$prompt_file'" Enter

# codex（新規）
tmux send-keys -t "=$session:$window" "cd '$work_dir'; codex -C '$work_dir' \"\$(cat '$prompt_file')\"" Enter
```

- prompt_file は dispatch.sh が `mktemp $output_dir/dispatch-prompt-XXXXXX` で作成（既存ロジック流用）
- shell injection 対策として `$prompt_file` のパスは shell quote、内容は `$(cat ...)` 経由で codex 引数に展開
- 改行を含むプロンプトは `cat` がそのまま読むため安全

### `dispatch_launcher.fish` の改修

現状の `dispatch_launcher.fish` line 33-45（codex モード分岐ブロック）を削除し、codex モードを Step 2（prompt 入力）に合流させる。Step 2 内で launcher 選択フラグ `_dl_launcher` を追加し、claude/codex で `dispatch.sh launch` の `--launcher` 引数を切替える。

Step 2 UI の差異：
- 既存 claude モードでは Step 2 の `tab` で `dispatch / orchestrate` を切替
- codex モードでは `tab` を無効化（codex 側に orchestrate 相当がないため、本 ADR では dispatch 固定）
- Step 2 ヘッダー表示は launcher 名を含めて区別（`> dotfiles [codex]` 等）

### キーバインドとフロー

```
Step 1（fzf）
┌─────────────────────────────────────┐
│ tab: switch  claude / codex         │
│ > dotfiles                          │
└─────────────────────────────────────┘

claude モード Step 2:
  tab: dispatch ↔ orchestrate
  enter: 実行 → dispatch.sh --launcher claude

codex モード Step 2（新規・本 ADR）:
  tab: 無効（codex は dispatch のみ）
  enter: 実行 → dispatch.sh --launcher codex
  `:branch-name` プレフィックスで既存 remote branch checkout 可
```

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `~/.claude/skills/dispatch/dispatch.sh` | dotfiles 配布先 | `--launcher claude\|codex` フラグ追加、`tmux send-keys` の起動コマンド部分を launcher で分岐 |
| `configs/claude/skills/dispatch/dispatch.sh` | dotfiles | 上記の dotfiles 内ソース。symlink 経由で `~/.claude/skills/dispatch/dispatch.sh` に反映 |
| `configs/claude/skills/dispatch/skill.md` | dotfiles | `--launcher` 引数の説明追記 |
| `configs/fish/functions/dispatch_launcher.fish` L33-45 | dotfiles | 削除（codex モードの簡易フロー） |
| `configs/fish/functions/dispatch_launcher.fish` Step 2 | dotfiles | 追加（codex モードを Step 2 に合流、launcher 別ヘッダー表示、`tab` 無効化、`dispatch.sh --launcher codex` 呼び出し） |
| `docs/adr/061-popup-launcher-claude-codex-modes.md` | dotfiles | ステータスを `部分廃止（ADR-062 で一部変更）` に更新し、codex モードのフェーズ1 仕様が ADR-062 で上書きされた旨を注記 |

> dispatch.sh の実体パスは `~/.claude/skills/dispatch/dispatch.sh`（実行時参照）と `configs/claude/skills/dispatch/dispatch.sh`（dotfiles 内ソース）の両方が存在するか、setup-symlinks.sh のリンク方式により実体は片方になる。実装時に管理方式を確認すること。

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-062 セクション）
