# ADR-045: PreToolUse hook による .claude/ サブディレクトリへのファイル操作自動承認

## ステータス

採用済み

## 関連 ADR

- [ADR-017](017-pretooluse-hook-approve-safe-commands.md) — approve 専用 PreToolUse hook の設計原則
- [ADR-006](006-pretooluse-hook-bash-permissions.md) — PreToolUse hook 全般

## コンテキスト

Claude Code はスキル・エージェント定義等を `.claude/skills/`、`.claude/agents/`、`.claude/commands/` といったサブディレクトリで管理する。これらへの Write/Edit/NotebookEdit は Claude が自律的に行うべき操作であるにもかかわらず、現状では permission UI が発生して作業が中断される。

一方、`.claude/` **直下** のファイル（`settings.json`、`CLAUDE.md`、`settings.local.json` 等）は設定・ポリシーファイルであり、変更前にユーザーが内容を確認したい。

ADR-017 の責務分離原則（approve 専用の hook を新規作成）に従い、Write/Edit/NotebookEdit に特化した approve hook を追加する。

## 設計案

### 案1: Write/Edit/NotebookEdit 専用の approve hook を新規作成する（採用）

- `approve-safe-commands.py`（Bash 専用）には手を加えず責務を分離
- `.claude/{subdir}/` 以下のパスのみ `permissionDecision: "allow"` を返す
- `.claude/` 直下や `.claude/` を含まないパスは `sys.exit(0)` でデフォルト動作に委譲
- fail-open 設計: 例外時は `sys.exit(0)` でフォールバック

### 案2: 既存の approve-safe-commands.py に追記する（却下）

- Bash 専用ツールとファイル操作ツールの責務が混在する

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `configs/claude/scripts/approve-safe-file-ops.py` | dotfiles | 新規作成（Write/Edit/NotebookEdit 専用 approve hook） |
| `configs/claude/settings.json` | dotfiles | PreToolUse に Write/Edit/NotebookEdit 用エントリを追加 |

### 判定ロジック

```
file_path に .claude/ が含まれる
  ↓
.claude/ の次のパス要素がサブディレクトリ（= .claude/ 直下ではない）
  → permissionDecision: "allow"

.claude/ 直下のファイル（settings.json 等）
  → sys.exit(0)（デフォルトの permission チェックへ）

.claude/ を含まないパス
  → sys.exit(0)
```

**Allow される例:**
- `~/.claude/skills/textlint/SKILL.md`
- `/path/.claude/agents/foo.md`
- `.claude/commands/bar.md`

**Ask（デフォルト）になる例:**
- `~/.claude/settings.json`
- `~/.claude/CLAUDE.md`
- `~/.claude/settings.local.json`

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-045 セクション）
