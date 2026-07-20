# ADR-074: statusline の org 表示廃止と Fable 週間利用率の追加

## ステータス
採用済み

## 関連 ADR
- 関連: ADR-073（statusline のコンテキスト上限・stdin 由来フィールドの扱い方針）

## コンテキスト

`configs/claude/statusline.js` の1行目は `[tier][org][model|effort] 📁 repo ...` の形式で表示している。個人アカウントではデフォルトの組織名が `<email>'s Organization`（例: `ishii1492@gmail.com's Organization`）になり、この1項目だけで statusline の大半を占有して視認性を損なっていた。

また、claude.ai のプラン使用制限画面には「すべてのモデル」の週間制限とは別に「Fable」専用の週間制限バーが表示されている（Fable 5 をメインループに使う `fable` ラッパーの利用が増えたため、この専用枠の消費を statusline から確認したいというニーズがあった）。既存の `getRateLimitUsage()` は `oauth/usage` API のレスポンスから `five_hour` / `seven_day` / `extra_usage`（月間）のみを抽出しており、モデル別の制限は捨てていた。

stdin 経由で Claude Code 本体が渡す `rate_limits`（`data.rate_limits.five_hour` / `seven_day`）にはモデル別の内訳が含まれない。実際に `oauth/usage` API のレスポンスを確認したところ、`limits` という配列に汎用的な制限エントリが入っており、その中に `scope.model.display_name === "Fable"` を持つ週間スコープ制限（`kind: "weekly_scoped"`）が存在し、`percent` と `resets_at` を持っていることを確認した。

## 設計案

### org 名の短縮

#### 案A: 固定文字数で単純truncate（却下）
`org.slice(0, N)` のような単純な切り詰めだと `ishii1492@gmail.c…` のように意味のない位置で切れ、可読性が悪い。

#### 案B: `<local-part>@<domain>'s Organization` パターンを検出して local-part のみ残す（採用）
個人アカウントのデフォルト組織名は `<email>'s Organization` という固定パターンであるため、正規表現でメールアドレスの `@` 以降と `'s Organization` サフィックスを除去し、メールのローカルパート（`ishii1492`）のみを残す。カスタム組織名（`'s Organization` サフィックスを持たない、または email 形式でない）はそのまま使い、それでも 16 文字を超える場合のみ末尾を `…` で省略するフォールバックを用意する。

### Fable 週間利用率の取得

#### 案A: stdin の `rate_limits` を拡張して期待する（却下）
Claude Code 本体が stdin で渡す `rate_limits` にモデル別内訳を追加してもらう必要があり、こちらの制御が及ばない。ADR-073 の「CC の申告値に従う」方針とも整合しない（CC が渡していない情報は作れない）。

#### 案B: `oauth/usage` API の `limits[]` から `scope.model.display_name` が `"Fable"` の要素を探す（採用）
`getRateLimitUsage()` が `oauth/usage` API を叩いた際に、`data.limits` 配列から `scope?.model?.display_name?.toLowerCase() === 'fable'` に一致する最初の要素を取り出し、`{ percent, resetsAt }` として結果に含める。既存の 6 分キャッシュ（`/tmp/claude-usage-cache.json`）に相乗りするため追加のレイテンシコストはほぼない。

ただし、これまで stdin に `rate_limits`（five_hour/seven_day）が来ている場合は `getRateLimitUsage()` を呼ばずスキップしていた（`stdinRateLimits || await getRateLimitUsage()` の短絡評価）。Fable の制限は stdin から得られないため、stdin の有無に関わらず `getRateLimitUsage()` を常に呼ぶよう変更した。5h/7d/月間の表示自体は従来通り stdin を優先し、Fable の週間利用率のみ API 側の結果を使う。

### 変更が必要なファイル
| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/statusline.js` | dotfiles | `shortenOrgName()` を追加して org 表示に適用。`getRateLimitUsage()` が `limits[]` から Fable の週間制限を抽出して返すよう拡張。`rateLimitUsage` 計算とは独立に `getRateLimitUsage()` を常時呼び出し、statusline に `| fable ████░░░░ 33% 5h5m` の形式で追加表示 |

## 追補（2026-07-20）: org 表示を短縮ではなく完全廃止に変更

短縮しても `[max][ishii1492]` の形でなお冗長との指摘があり、org 表示自体を statusline から削除する方針に変更した。`shortenOrgName()` は呼び出し元がなくなったため削除し、`tierOrgInfo` の組み立ては tier（`[max]`）のみになった。`getTierAndOrg()` は tier キャッシュ機構を tier/org 兼用のまま維持しており（org のキャッシュ・バックグラウンド取得自体は残存）、statusline 側で org を単に破棄している。

### 変更が必要なファイル（追補）
| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/statusline.js` | dotfiles | `shortenOrgName()` を削除。`tierOrgInfo` の組み立てから org 参照を除去し `{ tier } = getTierAndOrg()` のみ使用する |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-074 セクション）
