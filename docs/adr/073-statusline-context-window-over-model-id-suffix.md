# ADR-073: statusline のコンテキスト上限判定を model.id サフィックスから context_window フィールドへ変更する

## ステータス
Draft

## 関連 ADR
- 関連: ADR-048（1M context モデルの auto-compaction 閾値。同じ statusline のコンテキスト使用率表示に関わる）

## コンテキスト

`configs/claude/statusline.js` は Claude Code の statusline hook から stdin 経由で受け取る `model.id` に `"[1m]"` サフィックスが含まれるかどうかで 1M コンテキストモデルを判定し、コンテキスト使用率表示の分母（通常モデル: 200k/150k、1M モデル: 1M/950k）を切り替えていた。

Sonnet 5 でこの分母が常に 150k 表示になる不具合が発生した。statusline hook の stdin JSON を実際にダンプして確認したところ、`model.id` は `"claude-sonnet-5"`（`"[1m]"` サフィックスなし）だった一方、Claude Code 本体は同じ stdin JSON に `context_window`（`context_window_size` / `used_percentage` / `current_usage` 等）という新フィールドを直接渡すようになっていた。つまり Claude Code 内部では 1M コンテキストが正しく有効になっているが、それを示す情報が `model.id` のサフィックスから `context_window` フィールドへ移っており、statusline.js 側の判定が追いついていなかった。

同種の破損は過去にも一度発生している（`[1m]` サフィックス判定自体、2026年3月にモデルごとの命名揺れへ対応するために追加されたもの）。`model.id` の命名規則は Claude Code 内部の実装詳細であり、モデル世代が変わるたびに同じ理由で再発するリスクを構造的に抱えていた。

## 設計案

### 案A: model.id のパターンマッチを拡張し続ける（却下）
新しいモデル名（例: `sonnet-6`, `opus-6` 等）が出るたびに、そのモデルで `"[1m]"` サフィックスが付くかどうかを都度確認してパターンを追加する。Claude Code 内部の命名規則というブラックボックスに依存し続けるため、モデル世代交代のたびに再発するリスクを解消できない。

### 案B: stdin の context_window フィールドを優先して使用する（採用）
Claude Code 本体が stdin JSON で渡す `context_window.context_window_size`（コンテキスト上限）・`context_window.used_percentage`（使用率）・`context_window.current_usage`（トークン内訳）を最優先の情報源として使う。これは Claude Code 自身が計算・保証する値であり、モデル名の命名規則に依存しない。

`context_window` フィールドが存在しない旧バージョンの Claude Code 向けに、従来の `model.id` の `"[1m]"` サフィックス判定 + transcript ファイル解析によるトークン集計をフォールバックとして残す。`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`（ADR-048）による分母上書きは、`context_window` 優先時・フォールバック時のどちらでも従来通り最優先で尊重する。

### 変更が必要なファイル
| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/statusline.js` | dotfiles | `context_window` フィールドをコンテキスト上限・使用率・トークン集計の第一情報源として使用するよう変更。`context_window` 不在時は従来の `model.id` サフィックス判定 + transcript 解析にフォールバック |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-073 セクション）
