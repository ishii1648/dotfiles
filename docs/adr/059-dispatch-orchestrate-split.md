# ADR-059: dispatch / orchestrate の責務分離

## ステータス
部分廃止（ADR-060 で一部変更）

> dispatch の責務分離（軽量版としての位置付け）は引き続き有効。orchestrate の設計（「planning Claude が戦略決定」「worktree N個 + worker Claude N個」）は ADR-060 で「ワークフロータイプ固定のエージェントチェーン + 単一 worktree + tmux wait-for」に変更。

## 関連 ADR
- 依存: ADR-054（dispatch skill — spawn/orchestrate を統合した単一エントリポイント）
- 関連: ADR-052（orchestrate skill）
- 関連: ADR-060（orchestrate v0.0.4 — エージェントチェーン復元）

## コンテキスト

ADR-054 で dispatch を「すべてのタスク起動の単一エントリポイント」として設計し、meta planner が実行戦略（single/parallel/pipeline/hybrid）を動的に決定する構成にした。

しかし運用上、単一ファイルの修正や 1 ブランチで完結する作業（README 更新、単機能 fix 等）に対しても planning Claude を起動してしまい、以下の問題が発生している：

- planning 用の tmux session + Claude セッション起動に不要なオーバーヘッド（時間・トークン）がかかる
- meta planner が `single` 戦略を選択するまで待つ必要がある
- 「worktree 1つ + worker 1つ」という結論が自明なのに計画フェーズが挟まる

また、ADR-054 で「内部プリミティブとして残す」とされた spawn は未実装であり、orchestrate の入力バリエーション（`--from-todo` 等）として吸収可能。

## 設計案

dispatch を2つの skill に分離し、spawn を廃止する。

### dispatch（軽量版・新設）

- **入力** — タスク記述 / issue 番号 / GitHub issue URL
- **計画** — なし（1 worktree 固定）
- **出力** — worktree 1つ + worker Claude 1つ
- **用途** — README 修正、単機能 fix、1 ブランチで完結する作業
- **フロー** — 引数解析 → worktree 作成 → worker Claude 起動（planning Claude なし）

### orchestrate（現 dispatch をリネーム）

- **入力** — タスク記述 / issue 番号 / GitHub issue URL / TODO.md
- **計画** — planning Claude が分析・戦略決定
- **出力** — worktree N個 + worker Claude N個
- **用途** — 複数ファイル/コンポーネントにまたがる並列・逐次作業
- **フロー** — 現行の dispatch フロー（meta planner → YAML → worktree + worker）をそのまま継承

### spawn（廃止）

orchestrate の入力バリエーション（`/orchestrate --from-todo`）として吸収。独立 skill としては廃止。

### 使い分け

| skill | いつ使うか |
|---|---|
| `/dispatch` | 「これ1ブランチで終わる」と分かっている作業 |
| `/orchestrate` | 並列作業が必要、または計画が必要な複雑なタスク |

ユーザーが明示的に選択する（自動判定はしない）。判断が難しいケースでは `/orchestrate --dry-run` で計画だけ確認できる。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `.claude/skills/dispatch/skill.md` | dotfiles | 軽量版に書き換え（planning フェーズ削除） |
| `.claude/skills/orchestrate/skill.md` | dotfiles | 現 dispatch skill.md をリネーム・移動 |
| `.claude/skills/spawn/` | dotfiles | 削除（skill 一覧からも除去） |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-059 セクション）
