# ADR-057: stacked PRs — dispatch と分離した PR 依存管理コンポーネント

## ステータス
Draft

## 関連 ADR
- 依存: ADR-054（dispatch skill — 依存グラフの出力元）
- 関連: ADR-056（tmux-sidebar — monitoring agent の UI 候補）

## コンテキスト

ADR-054 の dispatch skill 設計レビュー中に、複数 PR を順列でマージする必要があるシナリオ（stacked PRs）が dispatch の kick-off モデルでは解決できないことが判明した。

dispatch の責務は「タスクを受け取り、実行戦略を決定し、worktree + Claude セッションを起動して終わる」である。
一方、stacked PR 管理に必要な処理は以下であり、性質が異なる：

- PR1 の CI が通ったか継続的に監視する
- PR1 マージ後に PR2 の base を `main` に rebase して push する
- GitHub の状態変化に応じて次のアクションをトリガーする

dispatch に全部詰め込むと責務が拡散するため、**依存グラフの表現（dispatch 側）** と **PR 依存の実行管理（別コンポーネント側）** を分離する。

## 設計案

### 責務分担

| 処理 | 担当 |
|---|---|
| PR 依存グラフの表現（`base_branch` / `merge_order` フィールドの出力） | dispatch / meta planner（ADR-054） |
| 「PR1 マージ待ち → PR2 rebase → push」の実行 | 本 ADR が定義する monitoring agent または ADR-056 sidebar |

### meta planner 出力フォーマット拡張（ADR-054 への追記）

ADR-054 の meta planner 出力に以下フィールドを追加する：

```yaml
worktrees:
  - name: auth-compliance-impl
    branch: dispatch/auth-compliance-impl
    base_branch: main          # PR の base ブランチ
    merge_order: 1             # 省略時は順不同（並列）
    prompt: |
      ...
  - name: auth-compliance-test
    branch: dispatch/auth-compliance-test
    base_branch: dispatch/auth-compliance-impl  # impl マージ後に rebase
    merge_order: 2
    prompt: |
      ...
```

### monitoring agent の設計（詳細は後続 ADR）

`merge_order` が付与された worktree セットに対して以下を実行するコンポーネントを別途設計する：

- GitHub API で PR1 のマージ状態をポーリングする
- PR1 マージ検知後に PR2 の base を `main` に rebase して push する
- 完了後に次の `merge_order` の PR を有効化する

UI は ADR-056 の sidebar から操作できることを目指す（確定は後続 ADR で）。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/skills/dispatch/skill.md` | dotfiles | meta planner 出力フォーマットに `base_branch` / `merge_order` フィールドを追記 |
| （monitoring agent の実装場所は未定） | TBD | 別 ADR で決定 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-057 セクション）
