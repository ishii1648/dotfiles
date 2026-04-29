# ADR-007: tmux セッションリストに Claude Code ランタイム状態を表示

## ステータス

部分廃止（ADR-063 で一部変更）

> **ADR-063 Phase A での変更点**:
> - スクリプト名 `claude-pane-state.sh` → `agent-pane-state.sh`
> - 関数名 `__tm_claude_state.fish` → `__tm_agent_state.fish`
> - 状態ディレクトリ `/tmp/claude-pane-state/` → `/tmp/agent-pane-state/`
> - 状態ファイル形式: 1行目=state、2行目=agent (`claude` | `codex`) の 2 行形式に変更
> 以下の本文は ADR-063 適用前の記述。最新の構成は ADR-063 を参照。

## 関連 ADR

- [ADR-003](./003-tmux-notification-click.md) — 通知の仕組みを状態バッジに発展
- [ADR-063](./063-tmux-codex-pane-state.md) — Codex ランタイム状態への対応で本 ADR の一部仕様を変更

## コンテキスト

tmux の `prefix+s` で表示される fzf セッション/ウィンドウリストでは、各ウィンドウで Claude Code が動作中かどうかが分からなかった。複数ウィンドウで Claude Code を並行利用する場合、どのウィンドウが応答待ち・権限要求中・実行中かを一覧から判断できず、ウィンドウを切り替えて確認する必要があった。

- [Claude Code Hooks ドキュメント](https://docs.anthropic.com/en/docs/claude-code/hooks)

## 設計案

### 構成

| コンポーネント | パス |
|---------------|------|
| 状態書き出しスクリプト | `configs/claude/scripts/claude-pane-state.sh` → `~/.claude/scripts/` (symlink) |
| 状態読み取り関数 | `configs/fish/functions/__tm_claude_state.fish` |
| 表示統合 | `configs/fish/functions/__tm_candidates.fish` |
| Hook 登録 | `~/.claude/settings.json` の hooks |

### 状態遷移

```
SessionStart → idle
UserPromptSubmit → running
Notification (permission_prompt) → permission
Notification (elicitation_dialog) → ask
Stop → idle
SessionEnd → ファイル削除
```

> **注意**: `PostToolUse` で `running` を設定する際、第2引数 `post` を渡して呼び出す。`post` が指定された場合、`permission`/`ask`/`idle` が5秒以内に設定されていれば `running` への上書きをスキップする。これにより以下の競合を防止する:
> - 並列ツールの PostToolUse が `permission`/`ask` を上書きする問題
> - Stop 直後の PostToolUse が `idle` を `running` に戻す問題
>
> `UserPromptSubmit` は `post` なしで呼び出すため、ガードの影響を受けずに常に `running` を設定できる。

### バッジ表示

| 状態 | バッジ | 色 |
|------|--------|-----|
| idle | `[idle]` | dim (`\e[2m`) |
| running | `[running]` | purple (`\e[35m`) |
| permission | `[perm]` | red (`\e[31m`) |
| ask | `[ask]` | red (`\e[31m`) |

### データフロー

```
Claude Code Hooks
  → claude-pane-state.sh <state>
    → /tmp/claude-pane-state/pane_{TMUX_PANE}

prefix+s (fzf セッションリスト)
  → __tm_candidates.fish
    → __tm_claude_state.fish (ウィンドウ内ペインの最優先状態を返す)
      → /tmp/claude-pane-state/pane_{id} を読み取り
```

### 設計方針

- **状態ファイル方式**: `echo "$STATE" > "$PANE_FILE"` の1行で書き出し、読み取りも `test -f` + `cat` で完結。`jq` 等の外部依存なし
- **JSON パース不要**: 状態は hook イベント種別で一意に決まるため、コマンド引数で渡す
- **複数ペイン優先度**: 1ウィンドウに複数 Claude ペインがある場合、アクション必要な状態を優先（`permission > ask > running > idle`）
- **tmux 外では無動作**: `$TMUX_PANE` 未設定時は即座に exit
- **stale running 検知**: 読み取り時に tmux の `pane_idle`（ペインへの最終出力からの秒数）を確認。`running` 状態だがペインに15秒以上出力がない場合、Stop 未発火とみなし `idle` に補正する

Claude Code の hooks でペインごとに状態ファイルを `/tmp` に書き出し、tmux セッションリスト生成時に読み取って色付きバッジとして表示する。状態ファイル方式により外部依存なしで実装できる。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-007 セクション）
