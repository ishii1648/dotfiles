# TODO

claudedog の開発タスクを管理する。完了したら CHANGELOG.md に記録して削除する。

## 未着手

- Bash コマンドのコンテキスト消費監視
  - `PostToolUse` Hook（`posttooluse-track.sh`）で Bash コマンドの stdout サイズを記録
  - redirect-to-tools をすり抜けた正当な Bash コマンドのうち、出力が大きいものを特定
  - 定期集計で「常連犯」コマンドを可視化し、対策要否を判断する
- メトリクスの再検討
  - 単なる総数以外の算出を検討したい
- メトリクス収集方法の再検討
  - OpenMetircsへの形式変換
- retro-pr との連携
  - PR の下位・上位10%ずつは自動で retro-pr 実行
  - 結果を PR と関連付けて表示

## 進行中

（なし）
