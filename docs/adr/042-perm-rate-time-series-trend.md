# ADR-042: perm UI 発生率の時系列トレンドグラフを追加する

## ステータス

採用済み

## コンテキスト

ADR-041 で Permission UI 発生率（perm_count / tool_use_total）を主指標として導入した。しかし現在のダッシュボードでは全グラフが perm_rate 昇順（= 良い順）でソートされており、「介入率が改善しているか/悪化しているか」というトレンドが把握できない。

PR 単位でトレンドを見ようとすると、PR の性質差（バグ修正 1 時間 vs 新機能 1 週間）や PR 番号が時系列の近似にすぎない問題がある。一方、**日別・週別で集計すると等間隔な時系列になり、複数 PR が平均化されてノイズが小さくなる**。

ただし PR ごとの詳細確認（どの PR で介入が多かったか）は PR 単位でしか見えない。そのため、**グラフは時系列（日別/週別）でトレンドを把握し、テーブルは PR 単位で詳細を確認する**という役割分担が適切と判断した。

## 設計案

### データ集計

時系列の perm_rate を計算するには、各 tool_use がいつ発生したかのタイムスタンプが必要。

`load_transcript_stats` に `tool_use_times`（timestamp リスト）の収集を復活させ、`_aggregate_by_key` 型の関数で日別・週別に perm_count と tool_use_total を集計する。

```python
# 日別集計の戻り値イメージ
{
  "2026-02-01": {"perm_count": 3, "tool_use_total": 42, "perm_rate": 7.1},
  "2026-02-08": {"perm_count": 2, "tool_use_total": 55, "perm_rate": 3.6},
  ...
}
```

週別は ISO 週（`%Y-W%W`）でキーを作る。

### グラフ（折れ線 SVG）

- X 軸: 日付または週
- Y 軸: perm_rate（%）
- **日別 / 週別** タブで切り替え（既存の `showTrend` パターンを再利用）
- データ点が 2 未満のグラニュラリティはメッセージを表示して非表示

### ダッシュボードの構成

```
[サマリカード]
[定義カード]
[時系列トレンド（日別/週別タブ）]  ← 追加
[メトリクス別グラフ（PR 別）]      ← 既存（ランキング用途として維持）
[PR 別統計テーブル]                ← 既存
```

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-042 セクション）

## 関連 ADR

- [ADR-041](041-claude-human-intervention-metrics-expansion.md): perm UI 発生率を主指標として導入（本 ADR の前提）
- [ADR-036](036-claude-permission-ui-count-via-hook.md): Permission UI ログ収集の基盤
