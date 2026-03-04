# ADR-042: perm UI 発生率の時系列トレンドグラフを追加する

## ステータス

Draft

## コンテキスト

ADR-041 で Permission UI 発生率（perm_count / tool_use_total）を主指標として導入した。しかし現在のダッシュボードでは全グラフが perm_rate 昇順（= 良い順）でソートされており、「直近 PR で介入率が改善しているか/悪化しているか」というトレンドが把握できない。

perm_rate を時系列で見るには、PR を **作成時刻順** に並べる必要がある。PR の正確なマージ日時はデータにないが、GitHub の PR 番号は単調増加するため、PR URL から取得できる番号を時系列の近似として利用できる。

ただし PR ごとの性質差（小さいバグ修正 vs 大規模新機能）により隣接する値がばらつくため、折れ線だけでは改善傾向を見誤る。**移動平均線を重ねる**ことでノイズと傾向を分離する。

## 設計案

### PR の時系列ソート

PR URL の番号（`/pull/(\d+)` から抽出）を昇順に並べる。

```python
def pr_number(url):
    m = re.search(r'/pull/(\d+)', url)
    return int(m.group(1)) if m else 0

sorted_by_time = sorted(pr_stats.items(), key=lambda x: pr_number(x[0]))
```

### 折れ線グラフ + 移動平均線（SVG）

`generate_trend_line_chart` を perm_rate 対応で再実装する。

- **X 軸**: PR 番号（ラベルは `owner/repo#NNN` の短縮形）
- **Y 軸**: perm_rate（%）
- **青い折れ線**: 各 PR の個別 perm_rate
- **橙の折れ線**: 直近 `WINDOW = 5` 件の移動平均
- データが `WINDOW` 件未満の場合は移動平均線を非表示

移動平均の計算:

```python
def moving_avg(values, window=5):
    result = []
    for i, v in enumerate(values):
        start = max(0, i - window + 1)
        result.append(sum(values[start:i+1]) / (i - start + 1))
    return result
```

### ダッシュボードへの配置

- 既存の「メトリクス別グラフ（PR 別、perm UI 発生率 昇順）」の**前**に新セクションを追加
- セクション名: 「perm UI 発生率 時系列トレンド（PR 番号順）」
- 既存の棒グラフ群はランキング表示として有用なため残す

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-042 セクション）

## 関連 ADR

- [ADR-041](041-claude-human-intervention-metrics-expansion.md): perm UI 発生率を主指標として導入（本 ADR の前提）
- [ADR-036](036-claude-permission-ui-count-via-hook.md): Permission UI ログ収集の基盤
