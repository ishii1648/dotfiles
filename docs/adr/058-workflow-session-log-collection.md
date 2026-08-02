# ADR-058: workflow skill の session log 収集と commit の体系化

## ステータス
Superseded by [ADR-076](076-herdr-migration-from-tmux.md)（herdr 移行に伴い dispatch/orchestrate を削除、本 ADR の hook・skill も撤去）

## 関連 ADR
- 関連: ADR-054（dispatch skill — 対象 workflow skill の筆頭）
- 関連: ADR-042（hook scalability architecture — SessionStart/Stop/UserPromptSubmit/PostToolUse hook にエントリを追加する）

## コンテキスト

dispatch / spawn などの workflow skill は tmux ウィンドウで `claude` を起動してタスクを実行する。各 Claude セッションの会話ログ（JSONL）は `~/.claude/projects/<hashed-path>/<session-id>.jsonl` に自動保存されるが、以下の問題がある：

1. **session ID が事後にしか分からない** — `tmux send-keys "claude" Enter` では起動後の session ID を取得できない
2. **ログの場所がバラバラ** — hashed path は `cwd` から計算されるが、worktree ごとに異なる
3. **コミットの仕組みがない** — ログを振り返ってプロンプトや戦略を改善したくても、ファイルがリポジトリ外かつ gitignore 外に散在する
4. **skill への埋め込みが困難** — worker skill 自体に処理を追加できないケース、またはユーザーに tmux 内部の命名規則を意識させたくないケースがある

「このskillのセッションを継続的に計測したい」というユースケースに対し、skill 名だけで設定でき tmux 内部知識を不要とする横断的な仕組みが必要。

## 設計案

2モードで実現する。session ID は SessionStart 時に確定するため、skill 側で UUID を事前生成する必要がない。

### モード概要

```
【Mode B: ペンディングコンテキスト（dispatch 向け）】
dispatch-new-worker-window.sh がウィンドウ作成時に
~/.workflow-sessions/pending/pane-<N>.json を書き込む
       ↓
SessionStart hook がペイン ID でマーカーを生成

【Mode C: hook ベース自動検出（spawn 等 — skill 変更不要）】
UserPromptSubmit hook が /spawn 等を検出
→ active-skill-<session-id>.json を書き込む
PostToolUse:Bash hook が tmux new-window/new-session を検出
→ pending/<tmux-session>-<window>.json を書き込む
       ↓
SessionStart hook が session+window 名でマーカーを生成
```

### コンポーネント構成

```
┌─────────────────────────────────────────────────────┐
│  workflow skill (dispatch / spawn / ...)            │
│  Mode B: dispatch-new-worker-window に              │
│          session-id・repo-root を渡すだけ            │
│  Mode C: skill 側の変更不要。                        │
│          hook がプロンプトと tmux 操作を自動検出     │
└──────────────────────┬──────────────────────────────┘
                       │ claude 起動前（各セッション開始前）
                       ▼
┌─────────────────────────────────────────────────────┐
│  SessionStart hook: workflow-session-start.sh        │
│  Mode B: pending/pane-<N>.json が存在すれば          │
│          session_id でマーカーを生成して削除          │
│  Mode C: pending/<session>-<window>.json が存在すれば│
│          session_id でマーカーを生成して削除          │
└──────────────────────┬──────────────────────────────┘
                       │ 終了時（各ターン）
                       ▼
┌─────────────────────────────────────────────────────┐
│  Stop hook: workflow-session-log.sh（変更なし）       │
│  stdin の session_id でマーカーを確認               │
│  → transcript_path を log_dir にコピー（上書き）    │
│  （コミットはしない。ターンごとに最新状態を保持）   │
└──────────────────────┬──────────────────────────────┘
                       │ 任意のタイミングで
                       ▼
┌─────────────────────────────────────────────────────┐
│  /session-log skill（変更なし）                       │
│  log_dir 内の JSONL を git add + commit             │
└─────────────────────────────────────────────────────┘
```

### マーカーファイル規約（全 workflow skill 共通）

```
~/.workflow-sessions/<session-id>.json
{
  "workflow_session_id": "<dispatch-session-id または tmux-session-name>",
  "role": "planning" | "fix" | "worker-0" | <window-name> | ...,
  "repo_root": "/path/to/repo",
  "log_dir": "docs/dispatch-logs/<workflow-session-id>"
}
```

### ペンディングコンテキストファイル

**Mode B（pane ID ベース）:**
```
~/.workflow-sessions/pending/pane-<pane-num>.json
```
`dispatch-new-worker-window.sh` が書き込む。`$TMUX_PANE` でキーを特定。

**Mode C（session+window 名ベース）:**
```
~/.workflow-sessions/pending/<tmux-session>-<window-name>.json
```
`workflow-window-register.sh`（PostToolUse:Bash hook）が書き込む。

### workflow-sessions.json（Mode C 設定）

skill 名をキーとして指定するだけ。tmux セッション名などの内部仕様はユーザーが意識しない。

```json
{
  "auto_log": {
    "spawn": { "log_dir": "docs/workflow-logs/{session_name}" }
  }
}
```

- `{session_name}` / `{workflow_session_id}`: tmux セッション名に展開
- `role` は tmux ウィンドウ名を自動使用

### Mode C の処理フロー

**UserPromptSubmit hook（`workflow-skill-detect.sh`）:**
1. stdin の JSON からプロンプトと `session_id` を取得する
2. プロンプトが `/spawn` 等 `auto_log` に登録された skill 名で始まる場合:
   `~/.workflow-sessions/active-skill-<session-id>.json` にログ設定を書き込む

**PostToolUse:Bash hook（`workflow-window-register.sh`）:**
1. stdin の JSON から `session_id` と Bash コマンドを取得する
2. `active-skill-<session-id>.json` が存在するか確認する
3. コマンドが `tmux new-window` または `tmux new-session` の場合:
   `-t`/`-s` からセッション名、`-n` からウィンドウ名を抽出する
4. `pending/<session>-<window>.json` にワークフローコンテキストを書き込む
   （`dispatch-new-worker-window` の呼び出しは Mode B が処理するためスキップ）

**SessionStart hook（`workflow-session-start.sh`）— Mode C 部分:**
1. `$TMUX_PANE` での Mode B 照合を先に試みる
2. 未ヒットなら tmux session 名 + window 名で `pending/<session>-<window>.json` を確認する
3. ヒットすれば `~/.workflow-sessions/<session_id>.json` を生成して pending ファイルを削除する

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/scripts/workflow-session-start.sh` | dotfiles | Mode C（session+window ベース照合）を追加 |
| `configs/claude/scripts/workflow-session-log.sh` | dotfiles | 変更なし（Stop hook） |
| `configs/claude/scripts/workflow-skill-detect.sh` | dotfiles | 新規作成（UserPromptSubmit hook） |
| `configs/claude/scripts/workflow-window-register.sh` | dotfiles | 新規作成（PostToolUse:Bash hook） |
| `configs/claude/scripts/dispatch-new-worker-window.sh` | dotfiles | 変更なし（Mode B は既存） |
| `configs/claude/workflow-sessions.json` | dotfiles | フォーマット変更（session_pattern → skill 名キー） |
| `configs/claude/settings.json` | dotfiles | UserPromptSubmit・PostToolUse hook に追加 |
| `configs/claude/setup.sh` | dotfiles | 変更なし（config シンリンクは既存） |
| `configs/claude/skills/dispatch/skill.md` | dotfiles | 変更なし |
| `configs/claude/skills/session-log/skill.md` | dotfiles | 変更なし |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-058 セクション）
