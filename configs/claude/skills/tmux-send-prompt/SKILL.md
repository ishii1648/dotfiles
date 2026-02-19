---
name: tmux-send-prompt
description: >-
  This skill should be used when the user wants to send a prompt or instruction to another tmux pane or session,
  such as "tmuxの別セッションにプロンプトを送りたい", "対向のClaudeに指示したい", "別のpaneにコマンドを送って",
  "tmuxペインに指示を転送して". This skill lists available panes (claude/codex panes only), lets the user select a target,
  verifies the target is idle using a state file and child-process check, then safely sends the prompt using send-keys.
  Accepts optional partial target (session, session:window, session:window.pane) as argument and resolves missing parts interactively.
version: 2.0.0
allowed-tools: Bash, AskUserQuestion
argument-hint: "[session[:window[.pane]]] \"<prompt>\""
---

# tmux-send-prompt - 安全なプロンプト送信

## 概要

`~/.claude/scripts/tmux-send-prompt.sh` に全ロジックを委譲する。
最大 Bash 2回 + AskUserQuestion 1回で完結する。

## ワークフロー

### Step 1: スクリプト実行（gather モード）

```bash
~/.claude/scripts/tmux-send-prompt.sh gather "<引数全体>"
```

引数なしで呼ばれた場合は `""` を渡す。

### Step 2: STATUS に応じて分岐

| STATUS | 意味 | 対応 |
|--------|------|------|
| `SENT` | 送信完了 | → Step 5（完了報告） |
| `ERROR` | エラー | → MESSAGE を表示して終了 |
| `NEED_PROMPT` | ターゲット決定済み、プロンプト未入力 | → Step 3a |
| `NEED_TARGET` | プロンプト決定済み、ターゲット未選択 | → Step 3b |
| `NEED_BOTH` | 両方未入力 | → Step 3c |

### Step 3a: プロンプト入力（NEED_PROMPT）

出力例:
```
STATUS: NEED_PROMPT
TARGET: ishii1648_dotfiles:3.1
```

AskUserQuestion でプロンプトを入力してもらう（"Other" で自由入力）。
入力後:
```bash
~/.claude/scripts/tmux-send-prompt.sh send "<TARGET>" "<入力されたプロンプト>"
```

### Step 3b: ターゲット選択（NEED_TARGET）

出力例:
```
STATUS: NEED_TARGET
PROMPT: テストを実行して
CANDIDATES:
ishii1648_dotfiles:1.1 [state=idle]
ishii1648_dotfiles:3.1 [state=idle]
```

CANDIDATES の各行を選択肢として AskUserQuestion を呼び出す（最大4件、idle のみ）。
選択後:
```bash
~/.claude/scripts/tmux-send-prompt.sh send "<選択されたターゲット>" "<PROMPT>"
```

### Step 3c: 両方入力（NEED_BOTH）

出力例:
```
STATUS: NEED_BOTH
CANDIDATES:
ishii1648_dotfiles:1.1 [state=idle]
ishii1648_dotfiles:3.1 [state=idle]
```

AskUserQuestion で 2 問同時に聞く:
- Q1: 送信先ターゲット（CANDIDATES から選択肢を生成）
- Q2: 送信するプロンプト（"Other" で自由入力。よく使う定型文があれば選択肢に入れる）

選択後:
```bash
~/.claude/scripts/tmux-send-prompt.sh send "<選択されたターゲット>" "<入力されたプロンプト>"
```

### Step 4: send モード結果の確認

send モードも同じフォーマットで出力する:
- `STATUS: SENT` → Step 5
- `STATUS: ERROR` → MESSAGE を表示して終了

### Step 5: 完了報告

```
✓ プロンプトを送信しました
  送信先: <target>
  内容: "<prompt>"
```

## 引数フォーマット

| フォーマット | 例 |
|---|---|
| プロンプトのみ | `"テストを実行して"` |
| セッション + プロンプト | `main "テストを実行して"` |
| セッション:ウィンドウ + プロンプト | `main:1 "テストを実行して"` |
| 完全指定 + プロンプト | `main:1.0 "テストを実行して"` |
| ターゲットのみ（`|` 区切りも可） | `ishii1648_dotfiles\|3` |
| 引数なし | （Step 3c に進む） |

## エラーハンドリング

スクリプトがすべてのエラーを `STATUS: ERROR\nMESSAGE: ...` 形式で返す。
モデルは MESSAGE をそのまま表示して終了する。
