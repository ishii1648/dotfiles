# ADR-038: PreToolUse hook による .claude/ サブディレクトリへの Read 操作自動承認

## ステータス

廃止（ADR-091 で置換）

`approve-safe-file-ops.py` は削除した。パス判定が `re.search(r"\.claude/[^/]+/")` のみで正規化もリポジトリ判定もせず、`~/.claude/skills/foo/../../../.ssh/config` のような `.claude/` 配下でないパスまで allow していた。`.claude/` 配下の Read 許可は `permissions.allow` の `Read(~/.claude/**)` に移した。

## 関連 ADR

- [ADR-017](017-pretooluse-hook-approve-safe-commands.md) — approve 専用 PreToolUse hook の設計原則
- [ADR-037](037-pretooluse-hook-approve-claude-subdir-file-ops.md) — Write/Edit/NotebookEdit の自動承認（Cannot Implement でクローズ）

## コンテキスト

ADR-045 の調査で、Claude Code は `.claude/` を含むパスへの **Write/Edit** 操作を特別なチェックで保護しており、PreToolUse hook 自体が呼ばれないことが判明した。

一方、**Read** ツールは通常の permission system を経由するため、PreToolUse hook が呼ばれると考えられる。`.claude/skills/`・`.claude/agents/`・`.claude/commands/` 以下のファイルを読み込む際にも permission UI が発生すると自律作業が中断されるため、Read 操作に限定した自動承認 hook を検証・実装したい。

ADR-045 で設計した `approve-safe-file-ops.py`（Write/Edit/NotebookEdit 用）はファイルが未作成のまま settings.json にエントリが残っている。本 ADR では Read 専用に新規作成し、Write/Edit 用エントリの要否も合わせて整理する。

## 設計案

### 案1: Read 専用の approve hook を approve-safe-file-ops.py として新規作成する（採用）

- ADR-017 の責務分離原則に従い `approve-safe-commands.py`（Bash 専用）とは別ファイルを維持
- `.claude/{subdir}/` 以下への Read のみ `permissionDecision: "allow"` を返す
- `.claude/` 直下のファイル（`settings.json`、`CLAUDE.md` 等）は `sys.exit(0)` でデフォルト動作に委譲
- fail-open 設計: 例外時は `sys.exit(0)` でフォールバック

### 案2: approve-safe-commands.py に Read ロジックを追加する（却下）

- Bash 専用ツールとファイル操作ツールの責務が混在する

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `configs/claude/scripts/approve-safe-file-ops.py` | dotfiles | 新規作成（Read 専用 approve hook） |
| `configs/claude/settings.json` | dotfiles | PreToolUse に Read 用エントリを追加、Write/Edit/NotebookEdit エントリの要否を確認 |

### 判定ロジック

```
tool_name が "Read"
  ↓
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

→ [issues.md](../issues.md)（ADR-038 セクション）
