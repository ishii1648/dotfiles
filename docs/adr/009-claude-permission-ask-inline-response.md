# ADR-009: Claude Permission Ask のインライン応答

## ステータス

Draft

## コンテキスト

Claude Code を複数の tmux セッション（またはペイン）で並行稼働させている場合、あるセッションで permission ask（ツール実行の許可確認）が発生すると、そのセッションに移動して内容を確認し allow/deny を選択する必要がある。

セッション移動が必要になるケース：
- 別のセッションで作業中に permission ask が割り込む
- セッション数が多く、どのセッションで発生したか把握しにくい
- セッション移動の往復で作業コンテキストが切れる

permission ask で実際に必要な操作は「内容の閲覧」と「allow/deny の選択」のみであり、フルセッション移動は不要なはずである。

現状の回避策：
- ADR-003/007 の通知・状態バッジで発生セッションを検知し移動する（移動コストは残る）
- `--dangerously-skip-permissions` で全許可（セキュリティリスクあり）

## 設計案

### 却下: tmux popup で既存セッションに attach

```bash
tmux display-popup -E 'tmux attach -t <session>:<window>.<pane>'
```

同一セッションに2クライアントが接続される形で動作はするが、セッション全体が popup に表示されるため permission ask のペインだけを切り出せない。UX が荒い。

### 却下: `--permission-prompt-tool` オプション（MCP ツール経由）

Claude Code の `--permission-prompt-tool` フラグで permission ask を MCP ツールに委譲できるが、**print mode（`-p`）専用**であり、通常のインタラクティブモードには適用できない。

### 採用: `PermissionRequest` hook + named pipe

`PermissionRequest` hook はインタラクティブモードでも発火する。hook スクリプトを named pipe でブロック待機させ、ユーザーが任意のタイミングでキーを押して popup を呼び出す設計にすることで、「予期しないタイミングでの自動 popup」を避けられる。

#### アーキテクチャ

```
[hook 発火]
    │
    ├─ permission 内容を一時ファイルに書く
    ├─ tmux status bar に ⚠ バッジを出す
    └─ named pipe を読んでブロック待機
                        ↑
                        │（ユーザーがキーを押してここに書き込む）
                        │
[ユーザーがキーを押す]
    │
    ├─ 一時ファイルから内容を読む
    ├─ tmux popup で内容 + allow/deny 表示
    └─ 選択結果を named pipe に書き込む → hook が返る
```

#### ① hook スクリプト（`~/.claude/hooks/permission-request.sh`）

Claude Code が permission ask 発生時に自動呼び出す。

```bash
#!/bin/bash
INPUT=$(cat)
echo "$INPUT" > /tmp/claude-permission-request.json

mkfifo /tmp/claude-permission-response 2>/dev/null || true

# tmux status bar に待機バッジを表示
tmux set-option -g @permission-pending "⚠ PERMISSION"

# ユーザーの応答を待ってブロック
RESPONSE=$(cat /tmp/claude-permission-response)
rm -f /tmp/claude-permission-response

tmux set-option -g @permission-pending ""
echo "$RESPONSE"
```

#### ② popup スクリプト（ユーザーがキー入力で呼び出す）

```bash
#!/bin/bash
REQUEST=/tmp/claude-permission-request.json
[ -f "$REQUEST" ] || exit 0

TOOL=$(jq -r '.tool_name' "$REQUEST")
CMD=$(jq -r '.tool_input.command // ""' "$REQUEST")

DECISION=$(tmux display-popup -E \
  "printf 'Tool: $TOOL\nCmd:  $CMD\n\n' && \
   echo -e 'allow\ndeny' | fzf --prompt='> '")

rm -f "$REQUEST"

if [ "$DECISION" = "allow" ]; then
  RESP='{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
else
  RESP='{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Denied"}}}'
fi

echo "$RESP" > /tmp/claude-permission-response
```

#### ③ settings.json の hook 設定

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/permission-request.sh"
          }
        ]
      }
    ]
  }
}
```

#### ④ キーバインドの割り当て

ADR-005 の制約（Ghostty は条件分岐付きキーバインド非対応）を踏まえ、以下のいずれかで popup スクリプトを呼び出す：

- **Ghostty keybind → shell command 直接実行**（`action = run_command` 対応の場合）
- **Ghostty keybind → tmux send-keys → tmux bind でスクリプト実行**（tmux 内のみ動作）

具体的なキー割り当ては実装時に確定する。

## 決定

（未定）

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-009 セクション）
