# ADR-097: board の research Task を廃止して spike Task を置く

## ステータス

採用済み（2026-10-19）

## 関連 ADR

- 依存: ADR-095（board。research Task の扱いと Project のフェーズを置き換える）

## コンテキスト

ADR-095 では、成果物が調査結果の Task を `research` ラベルで区別していた。research は起点のリポジトリの `docs/<topic>/` に Markdown を書いて PR にし、Project のフェーズ「調査」「分割案の確認」は research の有無とその PR で決めていた。

しかし、成果物が文書かコードかは Task の扱いを変える理由にならない。分割案を作る Task も、PR で閉じる通常の Task と変わらない。人が Task を見て知りたいのは、前提を確かめた結果、計画に手戻りが出るかどうかである。また、Epic の子 Task は blocked by が解けると自動で dispatch されるので、前提が崩れた後続 Task も古い計画のまま起動してしまう。

## 設計案

### 案A: research を廃止し、検証のための spike を置く（採用）

- `spike` ラベルの Task は前提を確かめ、手戻りの有無を結論として出す。結論は Issue コメントに根拠とともに書き、`spike:rework`（手戻りあり）か `spike:ok`（手戻りなし）のラベルで表す
- 検証のためのコードは main に入れない（`docs/development.md` の Spike パターンと同じ）。PR が無いので、結論のラベルが付いた open な spike を「レビュー待ち」とし、人が結論を確認して close する
- `spike:rework` で閉じた spike に blocked された Task は自動で dispatch せず、「判断待ち（手戻りの確認）」にする。人が計画を直したあと起動ボタンで起動する
- Project のフェーズは、子の有無と完了だけで決める「計画 / 実行 / 目標の確認」の 3 つにする。分割案を作る作業は通常の Task として扱う

### 案B: research を残し、spike を追加する（却下）

成果物の違いで類型を分けることになり、区別する理由が無いまま worker の手順とフェーズの判定が増える。

### 案C: 結論を Issue コメントだけで残す（却下）

board が手戻りの有無を読めず、自動 dispatch を止められない。

## 結果

- 手戻りありで閉じた spike の後続は、人が起動するか blocked by を外すまで起動しない
- 結論のラベルは worker が付ける。付け忘れると spike は「作業中」のままになる
