# ADR-063: tmux セッションリストに Codex ランタイム状態を表示

## ステータス

Superseded by [ADR-076](076-herdr-migration-from-tmux.md)（agent-pane-state.sh を撤去し herdr integration hook へ移行）

## 関連 ADR

- 依存: ADR-007（Claude Code 用の pane_state 機構を本 ADR で汎用化）
- 関連: ADR-041（settings.json の dotfiles 管理キー sync — claude 側の hook command 書き換えに必要）
- 関連: ADR-051（Go 製 tmux-sidebar が `/tmp/claude-pane-state/` を直接参照しており、ディレクトリ／ファイル形式変更に追随する必要あり）
- 関連: ADR-061（popup launcher の codex モード — 起動経路）
- 関連: ADR-062（popup launcher の codex dispatch 化 — 起動経路）

## コンテキスト

ADR-007 で tmux の `prefix+s` セッションリスト（`__tm_candidates.fish`）に Claude Code のランタイム状態を `[idle] / [running] / [perm] / [ask]` バッジで表示できるようになった。仕組みは：

- `claude-pane-state.sh` が hook (UserPromptSubmit / PostToolUse / Notification / Stop / SessionStart / SessionEnd) から呼ばれて `/tmp/claude-pane-state/pane_<TMUX_PANE>` に状態を書き込む
- `__tm_claude_state.fish` がペイン一覧から状態ファイルを読み、優先度付きで集約

ADR-061/062 で popup launcher から `codex` CLI を起動できるようになったが、**codex 起動中のペインは状態バッジが付かず**、複数ペインで並行作業した際にどの codex が応答待ち（idle）でどれが応答中（running）か一覧から判断できない。

調査の結果、**Codex CLI v0.124.0+ で公式の hooks フレームワークが追加**されており、Claude Code とほぼ 1:1 対応する 6 イベント（`SessionStart` / `UserPromptSubmit` / `PreToolUse` / `PostToolUse` / `PermissionRequest` / `Stop`）が利用可能であることが分かった。この公式機構を使えば、ADR-007 の仕組みを汎用化して Codex にも同等の状態表示を提供できる。

加えて、ADR-051 で導入した Go 製 `ishii1648/tmux-sidebar` も `/tmp/claude-pane-state/` を直接読んでいる（`internal/state/state.go` の `DefaultStateDir` がハードコード）ため、本 ADR でディレクトリ名と状態ファイル形式が変わると tmux-sidebar 側も同時に改修が必要。dotfiles 単独で完結せず、別リポジトリ側のリリース順序にも依存する。

## 設計案

### 案A: hooks ベース + スクリプト/関数の汎用化（採用）

公式 hook イベントから状態ファイルに書き込み、tmux 一覧側で読み取る既存方式を、agent 種別を引数で受ける形に汎用化する。

- 書き出しスクリプト: `claude-pane-state.sh` → `agent-pane-state.sh` にリネーム。第3引数で agent 種別 (`claude` | `codex`) を受け取る
- 状態ディレクトリ: `/tmp/claude-pane-state/` → `/tmp/agent-pane-state/` に統一（1ペイン1 agent 前提）
- 状態ファイル形式: 1行目に状態（`idle` / `running` / `permission` / `ask`）、2行目に agent 種別。既存の `_started` / `_session_id` 補助ファイルもそのまま流用
- 読み取り関数: `__tm_claude_state.fish` → `__tm_agent_state.fish` にリネーム。出力に agent 種別を含め、`__tm_candidates.fish` 側でバッジ色を分岐（claude=purple、codex=cyan など）
- stale 検知 (`pane_current_command` がシェル化、`pane_idle > 15s` で running を idle 補正) は agent 非依存なのでそのまま流用

### 案B: tmux pane_idle ヒューリスティックのみ（却下）

`pane_current_command` が `codex` で、かつ `pane_idle` の閾値で running/idle を判別する。

- 却下理由: codex の TUI が出力を生成しなくても処理中（tool 実行待ち、長い思考）は十分起こり得るため不正確。Claude 側で hook を使っている整合性も失われる

### 案C: rollout JSONL ファイル監視（却下）

`~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` の最終行を読み、`task_started` / `task_complete` で running/idle を判別する。

- 却下理由: pane と rollout file の紐付けが困難（複数 codex 並行時に cwd 一致だけでは特定不能）。公式 hook が提供されている以上、自前で polling する必要はない

### 案D: スクリプト/関数を Codex 用に並列追加（却下）

`codex-pane-state.sh` / `__tm_codex_state.fish` を並列で新設し、Claude 側の既存ファイルは触らない。

- 却下理由: stale 検知・優先度ロジック・状態ファイル管理がほぼ同一なので二重メンテになる。汎用化コストは小さく、汎用化したほうが将来 agent が増えても拡張しやすい

### Codex hook 設定の dotfiles 管理

`configs/codex/config.toml`（新規）に以下を記載し、`scripts/setup-manifest.yml` 経由で `~/.codex/config.toml` に配布する。既存ユーザー設定（`approval_policy` / `sandbox_mode` / `[projects.*]`）を破壊しないよう、ADR-027 の copy + validate パターンに準拠（`if_missing: true`）。dotfiles 側の hooks ブロックを ADR-041 同様に managed-keys 方式で sync する仕組みも必要になる場合がある（実装時に判断）。

```toml
[features]
codex_hooks = true   # v0.125.0 で要否は実装時に検証

[[hooks.UserPromptSubmit]]
[[hooks.UserPromptSubmit.hooks]]
type = "command"
command = "~/.claude/scripts/agent-pane-state.sh running codex"

[[hooks.PostToolUse]]
[[hooks.PostToolUse.hooks]]
type = "command"
command = "~/.claude/scripts/agent-pane-state.sh running codex post"

[[hooks.PermissionRequest]]
[[hooks.PermissionRequest.hooks]]
type = "command"
command = "~/.claude/scripts/agent-pane-state.sh permission codex"

[[hooks.Stop]]
[[hooks.Stop.hooks]]
type = "command"
command = "~/.claude/scripts/agent-pane-state.sh idle codex"

[[hooks.SessionStart]]
[[hooks.SessionStart.hooks]]
type = "command"
command = "~/.claude/scripts/agent-pane-state.sh idle codex"
```

> Codex には Claude の `Notification: elicitation_dialog` 相当（`ask` 状態）が無いため、`ask` バッジは Claude 専用のまま残る。Codex 側は `permission` までしか使わない。
> Codex には `SessionEnd` 相当が無いため、終了時の状態ファイル削除は `__tm_agent_state.fish` 既存の「pane_current_command がシェル化したら stale 削除」ロジックでカバーする。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/scripts/claude-pane-state.sh` | dotfiles | 削除（`git rm`） |
| `configs/claude/scripts/agent-pane-state.sh` | dotfiles | 追加（移動先として新規作成、第3引数で agent 種別 + 状態ディレクトリを `/tmp/agent-pane-state/` に変更） |
| `configs/claude/settings.json` | dotfiles | hooks の command を `claude-pane-state.sh <state>` → `agent-pane-state.sh <state> claude [post]` に書き換え |
| `configs/fish/functions/__tm_claude_state.fish` | dotfiles | 削除（`git rm`） |
| `configs/fish/functions/__tm_agent_state.fish` | dotfiles | 追加（移動先として新規作成、出力に agent 種別を含む） |
| `configs/fish/functions/__tm_candidates.fish` | dotfiles | 呼び出しを `__tm_claude_state` → `__tm_agent_state` に変更し、agent 種別でバッジ色を分岐 |
| `configs/codex/config.toml` | dotfiles | 新規作成。`[features]` と `[[hooks.*]]` ブロックを記載 |
| `configs/codex/setup.sh` | dotfiles | 新規作成。`~/.codex/config.toml` への配布（ユーザー設定とのマージ方針を確定） |
| `scripts/setup-manifest.yml` | dotfiles | codex コンポーネント追加 |
| `scripts/lib/validate.sh` | dotfiles | hooks スクリプト存在チェックを `~/.codex/config.toml` の `[[hooks.*]]` にも適用 |
| `docs/adr/007-tmux-claude-pane-state.md` | dotfiles | ステータスを `部分廃止（ADR-063 で一部変更）` に更新。スクリプト名・関数名・状態ディレクトリパスが ADR-063 で変更された旨を注記 |
| `docs/reference.md` | dotfiles | pane_state 関連の記述をリネーム後の名称に更新 |
| `internal/state/state.go` | tmux-sidebar | `DefaultStateDir` を `/tmp/agent-pane-state` に変更。`PaneState` に `Agent` フィールド（`claude` / `codex`）を追加。状態ファイルの 2 行目を agent 種別としてパースする |
| `internal/ui/model.go` | tmux-sidebar | バッジ色／表記を `PaneState.Agent` で分岐（claude=purple、codex=cyan 等。`__tm_candidates.fish` 側と整合させる）。`ask` バッジは claude 専用のままで OK |
| `aqua.yaml` | dotfiles | tmux-sidebar の改修版リリースに合わせて version を bump（migration 順序制約あり、下記参照） |

> v0.125.0 における `[features] codex_hooks` 明示有効化の要否、および既存 `~/.codex/config.toml`（ユーザー設定）への hooks ブロック差分マージ方式は実装時に検証して確定する。

### 移行順序制約

ディレクトリ名と状態ファイル形式の変更が破壊的なため、以下の順序で進める必要がある：

1. **tmux-sidebar 側を先にリリース**: `internal/state/state.go` を新フォーマット（`/tmp/agent-pane-state/`、2 行目 agent 種別）に対応させ、新 version をタグ付けしてリリース
2. **dotfiles `aqua.yaml` を bump**: 改修版 tmux-sidebar が `aqua install` で取得できる状態にする
3. **dotfiles 本体の改修を merge**: `agent-pane-state.sh` 配置、`settings.json` 書き換え、`__tm_agent_state.fish` 配置、`configs/codex/config.toml` 配布

逆順でやると、状態ディレクトリ切替直後に tmux-sidebar が「全 pane 状態不明」状態になり、ユーザー体験が一時的に劣化する。tmux-sidebar 側を後方互換にする（`/tmp/agent-pane-state/` と `/tmp/claude-pane-state/` の両方を読む）案も検討したが、ADR-007 を完全廃止する方針なので二重対応は避ける。

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-063 セクション）
