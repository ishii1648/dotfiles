# ADR-007: tmux セッションリストに Claude Code ランタイム状態を表示

## ステータス

採用済み

## コンテキスト

tmux の `prefix+s` で表示される fzf セッション/ウィンドウリストでは、各ウィンドウで Claude Code が動作中かどうかが分からなかった。複数ウィンドウで Claude Code を並行利用する場合、どのウィンドウが応答待ち・権限要求中・実行中かを一覧から判断できず、ウィンドウを切り替えて確認する必要があった。

## 決定

Claude Code の hooks でペインごとに状態ファイルを `/tmp` に書き出し、tmux セッションリスト生成時に読み取って色付きバッジとして表示する。

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

## 結果

- `prefix+s` のセッションリストで各ウィンドウの Claude Code 状態が一目でわかるようになった
- 権限要求中（赤）のウィンドウを素早く特定して切り替えられる
- Claude Code のクラッシュ時に状態ファイルが残留する可能性があるが、`/tmp` 配下のため OS 再起動でクリーンアップされる

## 参考

- [Claude Code Hooks ドキュメント](https://docs.anthropic.com/en/docs/claude-code/hooks)
