# ADR-017: PreToolUse hook による安全なコマンドの自動承認

## ステータス

Draft

## コンテキスト

Claude Code はシステムプロンプトで `git commit -m "$(cat <<'EOF'...EOF)"` の heredoc パターンを推奨しているが、`$()` (command substitution) を含むコマンドは一律で permission ask が発生する。

`permissions.allow` のパターンマッチでは `$()` を含むコマンドを許可できない（展開前後の不一致による既知の制約: GitHub Issue #5471 → #2983）。

現状の PreToolUse hook `redirect-to-tools.py` は「Bash の代わりに専用ツールを使え」と **block する**責務に特化しており、approve（許可）のロジックを混ぜると設計思想に反する。

## 補足: PreToolUse hook の permission 制御の仕組み

### 処理フロー

```
Claude がツール呼び出しを生成
  ↓
PreToolUse hook を実行
  ↓
hook の出力を確認
  ├─ "allow"  → permission UI をスキップして即実行
  ├─ "deny"   → ツール呼び出しのみ拒否（セッションは継続、モデルが別アプローチを試行可能）
  ├─ "ask"    → ユーザーに確認ダイアログを表示
  └─ 出力なし → デフォルトの permission チェックへ進む（$() 検出等）
  ↓
ツール実行
```

hook は permission システムの **前段** に位置するため、`allow` を返せばその後の permission チェック（`$()` 検出を含む）自体を通らない。

### `permissions.allow` との違い

| | `permissions.allow` | PreToolUse hook の `allow` |
|---|---|---|
| 判定方式 | 静的パターンマッチ | 動的（コマンド内容を検査して判定） |
| `$()` 対応 | 不可（展開前後の不一致） | 可能（文字列として検査できる） |
| 柔軟性 | ワイルドカードのみ | 任意のロジックが書ける |

### 新旧の出力形式

旧形式（deprecated）:
```json
{"decision": "block", "reason": "..."}
{"decision": "approve"}
```

新形式（推奨）:
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "..."
  }
}
```

- 旧 `"block"` → 新 `"deny"` に自動マッピング（動作は同じ：ツール拒否のみ、セッション中断なし）
- 旧 `"approve"` → 新 `"allow"` に自動マッピング
- 既存の `redirect-to-tools.py` も新形式への移行が推奨される

## 設計案

1. **approve 専用の PreToolUse hook を新規作成する**（例: `approve-safe-commands.py`）
   - `redirect-to-tools.py`（block 専用）と責務を分離
   - `git commit` + `$(cat <<'EOF'...EOF)` のみを含むコマンドを `permissionDecision: "allow"` で自動承認
   - 将来的に他の安全パターンも追加可能

2. **redirect-to-tools.py に approve ロジックを追加する**
   - ファイルが1つで済むが、block と approve の責務が混在する
   - 却下済み

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `configs/claude/scripts/approve-safe-commands.py` | dotfiles | 新規作成（approve 専用 hook） |
| `configs/claude/settings.json` | dotfiles | PreToolUse に approve-safe-commands.py を追加 |

## 決定

（未定）

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-017 セクション）
