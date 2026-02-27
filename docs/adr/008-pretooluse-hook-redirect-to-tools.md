# ADR-008: PreToolUse Hook による Bash コマンドのネイティブツールへのリダイレクト

## ステータス

採用済み

## コンテキスト

CLAUDE.md に「`find` の代わりに Glob ツールを使う」「`grep`/`rg` の代わりに Grep ツールを使う」等のツール使用ルールが記載されているが、LLM がこれを守らず Bash コマンドを直接実行してしまうケースがある。

[公式の hook 例](https://github.com/anthropics/claude-code/blob/main/examples/hooks/bash_command_validator_example.py)は `grep` → `rg` のような Bash 間リダイレクトだが、本環境では **Bash コマンド → Claude Code ネイティブツール**（Glob, Grep, Read, Edit, Write）へのリダイレクトが必要。

既存の `enforce-bash-permissions.py`（ADR-006）は deny/allow の権限制御を担当しており、関心事が異なるため新しい hook スクリプトとして分離する。

## 設計案

### 構成

| コンポーネント | パス |
|---------------|------|
| Hook スクリプト | `configs/claude/scripts/redirect-to-tools.py` → `~/.claude/scripts/` (symlink) |
| Hook 登録 | `~/.claude/settings.json` の `hooks.PreToolUse` |

### リダイレクトルール

パイプチェーン内の**最初のコマンドのみ**をチェックする（`git log | grep "fix"` の `grep` は検査対象外）。

| Bash コマンド | 条件 | リダイレクト先ツール |
|---|---|---|
| `find` | 常に | Glob |
| `grep` / `rg` | 常に | Grep |
| `cat` | リダイレクトなし | Read |
| `cat` | リダイレクト(`>`)あり | Write |
| `head` / `tail` | 常に | Read |
| `sed` / `awk` | 常に | Edit |
| `echo` | リダイレクト(`>`)あり | Write |

### コマンド解析ロジック

```mermaid
flowchart TD
    A[Bash コマンド受信] --> B[チェーン分割: &&, ||, ;]
    B --> C[各セグメントを処理]
    C --> D[パイプ分割: 最初のコマンドのみ取得]
    D --> E[環境変数代入をスキップしてベースコマンド抽出]
    E --> F{リダイレクトルールにマッチ?}
    F -->|Yes| G[block + メッセージ出力]
    F -->|No| H[pass through]
```

1. **チェーン分割**: `&&`, `||`, `;` でセグメントに分割
2. **パイプ分割**: 各セグメントで `|` の前の最初のコマンドのみ取得
3. **ベースコマンド抽出**: 環境変数代入（`VAR=val cmd`）をスキップして最初のワードを取得
4. **リダイレクト検出**: `>{1,2}` で stdout のファイルリダイレクトを検出（`>&2` 等の fd リダイレクトは除外）

### 設計方針

- **fail-open**: 例外発生時は `sys.exit(0)` で通常動作に戻る（`enforce-bash-permissions.py` と統一）
- **hook の実行順序**: redirect → enforce の順。redirect がブロックした場合、後続の enforce は実行されない
- **パイプ内コマンドは対象外**: `git log | grep` や `kubectl get pods | awk` のように、パイプの後段でフィルタリング用途に使われるケースは許可する

### permissions.allow からの冗長ルール削除

redirect hook でブロックされるコマンドの allow ルールは不要になるため削除:

| 削除ルール | 理由 |
|-----------|------|
| `Bash(find:*)` | hook が Glob へリダイレクト |
| `Bash(grep:*)` | hook が Grep へリダイレクト |
| `Bash(awk:*)` | hook が Edit へリダイレクト |

`Bash(echo:*)` はリダイレクトなしの `echo` が許可される必要があるため保持（ただし元々 allow リストに未登録）。

## 決定

`PreToolUse` hook として `redirect-to-tools.py` を作成し、`enforce-bash-permissions.py`（ADR-006）の**前**に配置する。LLM が CLAUDE.md のルールを無視した場合でも hook レベルで強制的にブロックし、適切なネイティブツールの使用を促す。

## 受け入れ条件

（issues.md 導入前の ADR。以下は実装後の結果）

- LLM が CLAUDE.md のツール使用ルールを無視した場合でも、hook レベルで強制的にブロックし適切なツールの使用を促す
- `enforce-bash-permissions.py` とは独立して動作し、各 hook が単一責任を持つ
- パイプ内のフィルタリング用途（`git log | grep` 等）は引き続き許可され、正当な利用が阻害されない

## 参考

- [ADR-006: PreToolUse Hook による Bash Permission の強制実行](./006-pretooluse-hook-bash-permissions.md)
- [Claude Code Hooks ドキュメント](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [公式 hook 例: bash_command_validator_example.py](https://github.com/anthropics/claude-code/blob/main/examples/hooks/bash_command_validator_example.py)
