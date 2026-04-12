# ADR-058: workflow skill の session log 収集と commit の体系化

## ステータス
採用済み

## 関連 ADR
- 関連: ADR-054（dispatch skill — 対象 workflow skill の筆頭）
- 関連: ADR-042（hook scalability architecture — SessionStart/Stop hook にエントリを追加する）

## コンテキスト

dispatch / spawn などの workflow skill は tmux ウィンドウで `claude` を起動してタスクを実行する。各 Claude セッションの会話ログ（JSONL）は `~/.claude/projects/<hashed-path>/<session-id>.jsonl` に自動保存されるが、以下の問題がある：

1. **session ID が事後にしか分からない** — `tmux send-keys "claude" Enter` では起動後の session ID を取得できない
2. **ログの場所がバラバラ** — hashed path は `cwd` から計算されるが、worktree ごとに異なる
3. **コミットの仕組みがない** — ログを振り返ってプロンプトや戦略を改善したくても、ファイルがリポジトリ外かつ gitignore 外に散在する
4. **個別 skill への埋め込みが困難** — worker skill 自体に処理を追加できないケースがある

また、dispatch 以外の workflow skill（spawn 等）にも同様の需要が想定されるため、config で設定した skill に自動適用できる横断的な仕組みが必要。

## 設計案

SessionStart hook + ペンディングコンテキストファイルの2モードで実現する。session ID は SessionStart 時に確定するため、skill 側で UUID を事前生成する必要がない。

### モード概要

```
【Mode A: config パターンマッチ（デフォルト）】
workflow-sessions.json の session_pattern に tmux セッション名がマッチ
           ↓
SessionStart hook が自動でマーカーを生成
（skill 側の変更不要）

【Mode B: ペンディングコンテキスト（dispatch 向け）】
dispatch-new-worker-window.sh が
~/.workflow-sessions/pending/pane-<N>.json を書き込む
           ↓
SessionStart hook がペイン ID でマッチしてマーカーを生成
（workflow_session_id = dispatch session-id、role = window 名）
```

### コンポーネント構成

```
┌─────────────────────────────────────────────────────┐
│  workflow skill (dispatch / spawn / ...)            │
│  Mode A: tmux セッション名が config にマッチすれば自動│
│  Mode B: dispatch-new-worker-window に               │
│          session-id・repo-root を渡すだけでよい      │
└──────────────────────┬──────────────────────────────┘
                       │ claude 起動時（各セッション開始前）
                       ▼
┌─────────────────────────────────────────────────────┐
│  SessionStart hook: workflow-session-start.sh        │
│  Mode B: pending/pane-<N>.json が存在すれば          │
│          session_id でマーカーを生成して削除          │
│  Mode A: config パターンにマッチすれば               │
│          session_id でマーカーを自動生成             │
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
│  dispatch/spawn cleanup から呼び出し可              │
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

- キーは Claude Code が SessionStart hook に渡す `session_id`
- `log_dir`: リポジトリ相対パス

### ペンディングコンテキストファイル（Mode B）

```
~/.workflow-sessions/pending/pane-<pane-num>.json
```

`dispatch-new-worker-window.sh` が tmux ウィンドウ作成時に書き込む。SessionStart hook がマーカー生成後に削除する。キーは tmux の `$TMUX_PANE` 環境変数（`%` プレフィックスなし）。

### workflow-sessions.json（Mode A 設定）

```json
{
  "auto_log": [
    {
      "session_pattern": "spawn-*",
      "log_dir": "docs/workflow-logs/{workflow_session_id}"
    }
  ]
}
```

- `session_pattern`: tmux セッション名のグロブパターン（`*` のみワイルドカード）
- `log_dir`: ログ保存先テンプレート（`{workflow_session_id}`, `{session_id}` を展開）
- `workflow_session_id` は tmux セッション名、`role` は tmux ウィンドウ名を使用

`configs/claude/setup.sh` が `~/.workflow-sessions/config.json` へのシンリンクを管理する。

### SessionStart hook の処理フロー

1. stdin の JSON から `session_id` を取得する
2. **Mode B**: `$TMUX_PANE` で `pending/pane-<N>.json` を確認する
   - ファイルが存在する場合: `~/.workflow-sessions/<session_id>.json` としてコピーし、pending ファイルを削除する（exit 0）
3. **Mode A**: `~/.workflow-sessions/config.json` を読み込み、tmux セッション名とパターンを照合する
   - マッチする場合: CWD から git root を取得してマーカーを生成する（exit 0）
4. いずれもマッチしない場合は exit 0（通常セッション）

### Stop hook の処理フロー（変更なし）

1. stdin の JSON から `session_id` と `transcript_path` を取得する
2. `~/.workflow-sessions/<session_id>.json` の存在を確認する（なければ即 exit 0）
3. マーカーから `repo_root` と `log_dir` を取得する
4. `<repo_root>/<log_dir>/<role>.jsonl` に `transcript_path` をコピーする（上書き）
5. exit 0（コミットはしない）

### dispatch-new-worker-window.sh の変更

オプション引数を追加する:

```
dispatch-new-worker-window <session-name> <window-name> <worktree-path> [<workflow-session-id> <repo-root>]
```

4・5 番目の引数が指定された場合、`pending/pane-<N>.json` を書き込む。dispatch skill は Phase 2-3 でこれらの引数を渡す。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/scripts/workflow-session-start.sh` | dotfiles | 新規作成（SessionStart hook） |
| `configs/claude/scripts/workflow-session-log.sh` | dotfiles | 変更なし（Stop hook） |
| `configs/claude/scripts/dispatch-new-worker-window.sh` | dotfiles | オプション引数 + pending ファイル書き込みを追加 |
| `configs/claude/workflow-sessions.json` | dotfiles | 新規作成（Mode A 設定ファイル） |
| `configs/claude/settings.json` | dotfiles | SessionStart hook に `workflow-session-start.sh` を追加 |
| `configs/claude/setup.sh` | dotfiles | `workflow-sessions.json` → `~/.workflow-sessions/config.json` シンリンク追加 |
| `configs/claude/skills/dispatch/skill.md` | dotfiles | Phase 2-3 で workflow context を渡すよう変更（Phase 2-4 は通常の `claude` 起動に戻す） |
| `configs/claude/skills/session-log/skill.md` | dotfiles | 変更なし |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-058 セクション）
