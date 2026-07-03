# ADR-073: statusline のコンテキスト上限判定を model.id サフィックスから context_window フィールドへ変更する

## ステータス
採用済み

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

## 追補（2026-07-04）: `used_percentage` 未着パスの maxContext 尊重

初期実装は「stdin に `context_window` が来ていれば直る」前提だったが、`used_percentage` が未着のとき（起動直後や旧バージョン CC）に `cw.context_window_size` を検出済みでも下流の閾値が固定値に落ちるバグが残っていた。旧 else 分岐は `modelId.includes("[1m]")` だけを見て 150k/950k を固定しており、`maxContext` を捨てていた。

補強:

- `used_percentage` 未着パスの `displayThreshold` 算出を `maxContext` ベースに変更（`>=1M` → 950k、`<=200k` → 150k、その他は `maxContext * 0.95`）。命名パターン依存は最終フォールバックのみ。

主方針（stdin 優先）は不変。

## 追補（2026-07-04）: Fable 5 と CC の context_window 申告値の食い違い

Fable 5 セッションで `(0/150k)` → `(32k/200k)` と表示され「1M であるべき」との指摘があり調査した結果、Anthropic 公式仕様（claude-api skill / Models 表）と Claude Code v2.1.191 の間で食い違いを確認した。

- **Anthropic 公式**: `claude-fable-5` は 1M context / 128K max output（デフォルト値）
- **Claude Code v2.1.191**: Fable 5 セッションの stdin で `context_window.context_window_size=200000, used_percentage=<200k基準>` を申告してくる

statusline は ADR-073 の主方針どおり **CC の申告値を尊重する** 立場を取る。Fable 5 は CC 側 registry / 使用率計算がモデル真値と乖離しているが、auto-compaction の実発火タイミングは CC が保持しているため、CC が 200k と言う以上 200k 基準で表示するのが正しい（無理に 1M/950k 表示にすると実 compact との乖離で誤解を招く）。

- 一時的に加えていた `^claude-fable` / `fable` regex による 1M 判定は **削除** した
- CC 側でこの点が修正されれば `context_window_size=1000000` が流れてくるようになり自動で 1M/950k 表示になる

つまり、この件は statusline 側で追加対処せず、CC のアップデートを待つ運用とする。

### 変更が必要なファイル
| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/statusline.js` | dotfiles | `context_window` フィールドをコンテキスト上限・使用率・トークン集計の第一情報源として使用するよう変更。`context_window` 不在時は従来の `model.id` サフィックス判定 + transcript 解析にフォールバック |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-073 セクション）
