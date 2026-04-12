# ADR-054: dispatch skill — spawn/orchestrate を統合した単一エントリポイント

## ステータス
Draft

## 関連 ADR
- 関連: ADR-052（orchestrate skill — dispatch に内部化される）
- 依存: ADR-055（meta planner — dispatch の動的実行戦略決定を担う）

## コンテキスト

現状、新しい作業を開始する際のエントリポイントが 3 つに分散している：

| コマンド | 用途 | 問題 |
|---|---|---|
| `gw_add --claude <name>` | 単発の worktree + Claude 起動 | worktree 名をユーザが毎回決める |
| `/spawn` | TODO.md ベースの並列実行 | TODO.md の事前作成が必要、worktree なし |
| `/orchestrate <type>` | ワークフロータイプ固定の多段エージェント | 重すぎる、単発開発には使いづらい |

「並列か逐次か」「どのエージェント構成にするか」はタスクの性質から導出できる **how** であり、ユーザが判断すべき what ではない。この判断を AI に委譲し、エントリポイントを一本化する。

## 設計案

タスク記述（または issue 番号）だけを受け取り、実行戦略を動的に決定する `/dispatch` skill を新設する。

### 入出力

```
/dispatch "認証ミドルウェアを compliance 要件に対応させる"
/dispatch --issue 53
```

### 実行フロー

1. meta planner（ADR-055）がタスクを分析し実行戦略を決定する
2. 戦略に応じて worktree + Claude セッションを作成する
3. 各ワーカーに適切なプロンプトを送信する
4. ADR-053 の状態集約スクリプトで進捗を監視できる

### 実行戦略パターン

| パターン | 条件 | 構成 |
|---|---|---|
| 単発 | 独立した単一タスク | 1 worktree |
| 並列 | 独立したサブタスクが複数 | N worktrees（spawn 相当） |
| パイプライン | 前工程の成果物に依存 | N worktrees 逐次ハンドオフ |
| 混合 | 並列 + パイプラインの組合せ | hybrid |

### 既存 skill の再配置

- `spawn`: 内部プリミティブとして残す（直接呼び出しも可）
- `orchestrate`: ロールテンプレート定義として再利用（ユーザ向けエントリポイントは dispatch に統合）

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/skills/dispatch/skill.md` | dotfiles | 新規作成 |
| `configs/claude/setup.sh` | dotfiles | dispatch skill の symlink 追加 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-054 セクション）
