# ADR-055: meta planner — 動的実行戦略決定エージェント

## ステータス
Draft

## 関連 ADR
- 依存: ADR-054（dispatch skill — meta planner の呼び出し元）
- 関連: ADR-052（orchestrate skill — planner ロールとの役割区分）

## コンテキスト

ADR-054（dispatch skill）は「タスク記述 → 実行戦略決定 → worktree/セッション作成」というフローを実現する。このうち「実行戦略決定」を担うコンポーネントが meta planner。

現状の orchestrate skill における `planner` エージェントとは役割が異なる：

| | orchestrate の planner | meta planner（新設計） |
|---|---|---|
| 責務 | タスク分析 + 次エージェントへのハンドオフ文書作成 | 実行戦略そのものを決定する |
| worktree 数の決定 | skill の固定ロジック（workflow タイプで決定） | meta planner が動的に決定 |
| 並列/逐次の判断 | skill の固定ロジック | meta planner が動的に判断 |
| 自身は実装するか | しない（ハンドオフのみ） | しない（戦略決定のみ） |

## 設計案

dispatch skill 内で subagent として動作する。ファイルへの出力を介して dispatch skill と連携する。

### meta planner の処理ステップ

1. **タスク分解**: タスク記述をサブタスクに分解する
2. **依存関係分析**: サブタスク間の依存グラフを構築する
3. **実行戦略選択**: 依存関係と複雑度から A/B/C/D パターンを選択する
4. **worktree 設計**: 必要な worktree 数・名前・ブランチ名を決定する
5. **ワーカー指示書作成**: 各 Claude セッションへ送るプロンプトを生成する

### 出力フォーマット（dispatch skill が読む）

```yaml
strategy: parallel        # single / parallel / pipeline / hybrid
worktrees:
  - name: auth-compliance-impl
    branch: dispatch/auth-compliance-impl
    prompt: |
      認証ミドルウェアの実装を...
  - name: auth-compliance-review
    branch: dispatch/auth-compliance-review
    prompt: |
      実装完了後、以下のハンドオフ文書を...
      待機: .dispatch/<session>/HANDOFF-impl-to-review.md
```

### dry-run モード

meta planner が決定した計画をユーザに提示してから実行する確認フェーズを設ける。`/dispatch --dry-run` で計画だけ出力する。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/skills/dispatch/skill.md` | dotfiles | meta planner の呼び出し手順を記述（ADR-054 と同ファイル） |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-055 セクション）
