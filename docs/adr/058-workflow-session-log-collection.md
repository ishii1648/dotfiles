# ADR-058: workflow skill の session log 収集と commit の体系化

## ステータス
採用済み

## 関連 ADR
- 関連: ADR-054（dispatch skill — 対象 workflow skill の筆頭）
- 関連: ADR-042（hook scalability architecture — Stop hook にエントリを追加する）

## コンテキスト

dispatch / spawn などの workflow skill は tmux ウィンドウで `claude` を起動してタスクを実行する。各 Claude セッションの会話ログ（JSONL）は `~/.claude/projects/<hashed-path>/<session-id>.jsonl` に自動保存されるが、以下の問題がある：

1. **session ID が事後にしか分からない** — `tmux send-keys "claude" Enter` では起動後の session ID を取得できない
2. **ログの場所がバラバラ** — hashed path は `cwd` から計算されるが、worktree ごとに異なる
3. **コミットの仕組みがない** — ログを振り返ってプロンプトや戦略を改善したくても、ファイルがリポジトリ外かつ gitignore 外に散在する

また、dispatch 以外の workflow skill（spawn 等）にも同様の需要が想定されるため、個別 skill への埋め込みではなく横断的な仕組みが必要。

## 設計案

Stop hook の `transcript_path` フィールドを活用し、3コンポーネントで実現する。

### コンポーネント構成

```
┌─────────────────────────────────────────────────────┐
│  workflow skill (dispatch / spawn / ...)            │
│  起動時: uuidgen → マーカー書き込み                  │
│         → claude --session-id <uuid> で起動         │
└──────────────────────┬──────────────────────────────┘
                       │ 終了時（各ターン）
                       ▼
┌─────────────────────────────────────────────────────┐
│  Stop hook: workflow-session-log.sh                  │
│  stdin の session_id でマーカーを確認               │
│  → transcript_path を log_dir にコピー（上書き）    │
│  （コミットはしない。ターンごとに最新状態を保持）   │
└─────────────────────────────────────────────────────┘
                       │ 任意のタイミングで
                       ▼
┌─────────────────────────────────────────────────────┐
│  /session-log skill                                  │
│  log_dir 内の JSONL を git add + commit             │
│  dispatch/spawn cleanup から呼び出し可              │
└─────────────────────────────────────────────────────┘
```

### マーカーファイル規約（全 workflow skill 共通）

```
~/.workflow-sessions/<claude-uuid>.json
{
  "workflow_session_id": "<dispatch-session-id>",
  "role": "planning" | "fix" | "worker-0" | ...,
  "repo_root": "/path/to/repo",
  "log_dir": "docs/dispatch-logs/<workflow-session-id>"
}
```

- `<claude-uuid>`: `uuidgen` で生成した UUID（`--session-id` に渡す値）
- `log_dir`: リポジトリ相対パス

### Stop hook の処理フロー

1. stdin の JSON から `session_id` と `transcript_path` を取得する
2. `~/.workflow-sessions/<session_id>.json` の存在を確認する（なければ即 exit 0）
3. マーカーから `repo_root` と `log_dir` を取得する
4. `<repo_root>/<log_dir>/<role>.jsonl` に `transcript_path` をコピーする（上書き）
5. exit 0（コミットはしない）

### /session-log skill の処理フロー

引数 `commit <workflow-session-id>` を受け取り：

1. `docs/dispatch-logs/<workflow-session-id>/` 内の JSONL ファイルを確認する
2. `git add <log_dir>` → `git commit -m "log: <workflow-session-id> session logs"` を実行する
3. `git push` も自動で行う

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/scripts/workflow-session-log.sh` | dotfiles | 新規作成（Stop hook スクリプト） |
| `configs/claude/settings.json` | dotfiles | Stop hook に `workflow-session-log.sh` を追加 |
| `configs/claude/skills/session-log/skill.md` | dotfiles | 新規作成（/session-log skill） |
| `configs/claude/skills/dispatch/skill.md` | dotfiles | `claude --session-id <uuid>` 起動に変更、マーカー書き込みを追加 |
| `configs/claude/setup.sh` | dotfiles | session-log skill の symlink 追加 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-058 セクション）
