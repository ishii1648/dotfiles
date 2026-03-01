# ADR-003: 通知クリックで tmux セッションに遷移できない

## ステータス

採用済み

## 関連 ADR

- [ADR-007](007-tmux-claude-pane-state.md) — 通知で場所を伝え、セッションリストの状態バッジで素早く遷移できるよう補完

## コンテキスト

3つの問題が複合している:

1. **Claude Code が tmux 内で OSC 通知を送れない** — DCS パススルー形式が必要だが未対応（[Issue #19976](https://github.com/anthropics/claude-code/issues/19976)）
2. **Ghostty の通知クリックでフォーカスが壊れている** — [Issue #9145](https://github.com/ghostty-org/ghostty/issues/9145)、v1.3.0（2026年3月予定）で修正予定
3. **Ghostty は tmux セッション内部を認識できない** — session-A と session-B は Ghostty から見ると同一プロセス

- [Claude Code macOS notifications](https://hoelter.prose.sh/claude-code-notifications)
- [terminal-notifier](https://github.com/julienXX/terminal-notifier)
- [Notification System for Tmux and Claude Code](https://quemy.info/2025-08-04-notification-system-tmux-claude.html)

## 設計案

`terminal-notifier` で macOS デスクトップ通知を発行する（通知のみ、クリック操作なし）。
`-execute` は tmux 環境で正常に動作しないため使用しない。

```
Claude Code (Stop/Notification イベント)
  → Hook でスクリプト実行
    → tmux コンテキスト（session/window）を取得
    → terminal-notifier で通知発行（セッション名をメッセージに含める）
```

通知スクリプト (`~/.claude/scripts/claude-notify.sh`):

```bash
#!/bin/bash
read -r input
event_type=$(echo "$input" | /opt/homebrew/bin/jq -r '.hook_event_name // "unknown"')

[ -z "$TMUX" ] && exit 0

SESSION=$(/opt/homebrew/bin/tmux display-message -p '#{session_name}')
WINDOW=$(/opt/homebrew/bin/tmux display-message -p '#{window_index}')
PANE=$(/opt/homebrew/bin/tmux display-message -p '#{pane_index}')
WINDOW_NAME=$(/opt/homebrew/bin/tmux display-message -p '#{window_name}')

case "$event_type" in
  "Stop")         TITLE="Claude Code: done";         MESSAGE="Task completed ($SESSION:$WINDOW_NAME)" ;;
  "Notification") TITLE="Claude Code: input needed";  MESSAGE="Waiting for input ($SESSION:$WINDOW_NAME)" ;;
  *)              TITLE="Claude Code";                 MESSAGE="$SESSION:$WINDOW_NAME" ;;
esac

/opt/homebrew/bin/terminal-notifier \
  -title "$TITLE" \
  -message "$MESSAGE" \
  -sound default \
  -group "claude-$SESSION-$WINDOW-$PANE"
```

Claude Code Hooks 設定 (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/scripts/sync-settings-local.sh" },
          { "type": "command", "command": "~/.claude/scripts/claude-notify.sh" }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/scripts/claude-notify.sh" }
        ]
      }
    ]
  }
}
```

`terminal-notifier` + Claude Code Hooks でデスクトップ通知を発行する。通知にセッション名を含めることで移動先を把握できる。Ghostty のバグ修正（v1.3.0）を待たずに解決可能。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-003 セクション）
