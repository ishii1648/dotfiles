# Claude Code ガイドライン
- ユーザが意見を求めた場合、忖度せず批判的に検討したうえで回答すること

## 人間への確認を最小化
質問・承認要求の前に必ず自己解決を試みること。どうしても必要な場合は作業開始前に AskUserQuestion / EnterPlanMode でまとめて確認する：
- テストを実行して検証する
- ブラウザや出力で結果を確認する
- ゴールから逆算して次ステップを自己判断する
- 物理的に不可能なもの（SMS認証等）のみ人間に依頼

## ユーザ環境
- シェルは **fish** を使用している。コマンド例を示す際は fish 構文で記述すること（heredoc `<<EOF` は使用不可、代わりに `printf` + `tee` を使う）

## 実装完了時の自動Git操作
未コミット変更があり feature/fix/docs/chore ブランチ上にいる場合、`git-ship` skill を自動実行する（$PWD 配下であることを確認してから）。PRが未作成なら commit→push→Draft PR作成、作成済みなら commit→push のみ。

## PR 作成後の CI 自動監視
`git-ship` で PR を作成・push した後は `auto-fix-ci` skill を自動実行する。Monitor tool で CI を継続 watch し、失敗ジョブのログを取得して原因を診断 → 修正 → 再 push のループを回す。手動介入が必要な失敗（secrets 不足、外部障害、scope 越え）に達した場合は状況を報告して停止する。

## 調査結果のまとめ
- 調査結果をまとめる際に表を使う場合はmarkdownを使うこと
- 調査結果は`.outputs/claude/`に出力すること（global gitignoreで除外済み）
- ただし、プロジェクト CLAUDE.md で調査ドキュメントの出力先が指定されている場合はそちらに従う
