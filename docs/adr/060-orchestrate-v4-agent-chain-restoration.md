# ADR-060: orchestrate v0.0.4 — エージェントチェーンの復元と tmux wait-for による順次実行

## ステータス
Superseded by [ADR-076](076-herdr-migration-from-tmux.md)（orchestrate を廃止）

## 関連 ADR
- 依存: ADR-052（orchestrate skill の初期設計 — ワークフロータイプ・ハンドオフ文書の原型）
- 依存: ADR-059（dispatch / orchestrate の責務分離 — 軽量版 dispatch との使い分けは維持）
- 関連: ADR-054（dispatch を統合エントリポイントとした設計 — ADR-059 で分離済み）
- 関連: ADR-058（workflow session log — Mode B を引き続き利用）

## コンテキスト

orchestrate skill は ADR-052（v0.1.0）で「ワークフロータイプに応じたエージェントチェーンの順列実行」として設計された。planner → tdd-guide → code-reviewer → security-reviewer のようにエージェントを順に起動し、ハンドオフ文書で引き継ぐ構成だった。

その後の簡素化で以下の変遷を辿った：

| バージョン | 変更 | 結果 |
|---|---|---|
| v1.0.0（ADR-059） | meta planner が戦略を動的決定 | ワークフロータイプ廃止 |
| v2.0.0 | parallel/pipeline/hybrid 戦略を廃止、単一 worktree 化 | エージェントチェーン廃止 |
| v3.0.0 | コアロジックを orchestrate.sh に切り出し | 堅牢性向上、ただし設計は v2.0 のまま |

v3.0.0 の時点で orchestrate は「1 worktree + 1 Claude + 1 プロンプト」に退化し、dispatch と実質同じになっている。プロンプト内に「Phase 1: 計画」「Phase 2: 実装」と書いても、spawned Claude は自由裁量で計画をスキップできる（実際にスキップされた）。

**v0.1.0 の問題**: 全エージェントを同時起動し Read ツールでハンドオフ文書をポーリング待機する設計はトークンを大量に浪費する。

**v2.0/v3.0 の問題**: フェーズ分離が構造的に保証されない。orchestrate の存在意義（dispatch との差別化）が失われている。

## 設計案

v3.0 の orchestrate.sh の堅牢性（マニフェスト管理、set -euo pipefail、構造化出力、cleanup）を維持しつつ、v0.1.0 の設計意図（ワークフロータイプ、エージェントチェーン、ハンドオフ文書、フェーズゲート）を復元する。

v0.1.0 のポーリング待機は `tmux wait-for` によるゼロコスト待機に置き換える。

### 実行モデル

- **単一 worktree** — sequential 実行なのでエージェントごとの worktree は不要（v0.1.0 からの変更点）
- **複数 tmux ウィンドウ** — 各エージェントに専用ウィンドウを割り当て進捗を可視化
- **`tmux wait-for` による順次起動** — Claude 終了 → シェルが `tmux wait-for -S` を実行 → orchestrate.sh の advance ループがブロック解除 → 次エージェント起動

### ワークフロータイプ（ADR-052 から復元）

| タイプ | エージェントチェーン |
|--------|---------------------|
| `feature` | planner → tdd-guide → code-reviewer → security-reviewer |
| `bugfix` | planner → tdd-guide → code-reviewer |
| `refactor` | architect → code-reviewer → tdd-guide |
| `security` | security-reviewer → code-reviewer → architect |
| `custom` | `--agents a,b,c` で指定 |

### ハンドオフ文書

各エージェントは完了時にハンドオフ文書を書き、次のエージェントはそれを読んで作業を開始する。

- 中間: `<worktree>/.outputs/claude/handoffs/HANDOFF-<prev>-to-<next>.md`
- 最終: `<worktree>/.outputs/claude/handoffs/FINAL-REPORT.md`

### `tmux wait-for` によるフェーズゲート

各エージェントの起動コマンド:
```
claude < '<prompt>'; tmux wait-for -S 'done-<session-id>-<agent>'
```

orchestrate.sh の advance ループ（バックグラウンド）:
```
tmux wait-for "done-<session-id>-<agent>"  # ブロック待機（トークン消費ゼロ）
→ ハンドオフ文書の存在チェック
→ 次エージェントの tmux ウィンドウ作成 + Claude 起動
```

v0.1.0 のポーリング待機と比較して:
- トークン消費: ゼロ（待機中の Claude セッションが不要）
- CPU 消費: ゼロ（tmux のカーネルレベル待機）
- 信頼性: Claude プロセス終了を確実に検出

### orchestrate.sh の拡張

- `--workflow <type>` 引数の追加
- `resolve_agent_chain()`: workflow type → エージェント配列
- `agent_role_description()`: エージェント名 → 役割説明文
- `generate_agent_prompt()`: エージェント別プロンプトファイル生成
- `advance_loop()`: `tmux wait-for` ベースの順次起動ループ（バックグラウンド）

### マニフェスト構造の拡張

```json
{
  "workflow": "feature",
  "chain": {
    "agents": ["planner", "tdd-guide", "code-reviewer", "security-reviewer"],
    "current_phase": 0,
    "phases": [
      { "agent": "planner", "status": "running", "handoff": null }
    ]
  },
  "advance_pid": 12345
}
```

### dispatch との差別化

| 観点 | dispatch | orchestrate (v0.0.4) |
|------|----------|------------------|
| 目的 | 1ブランチ完結の軽量タスク | 計画ベースのフェーズ分離 |
| Claude セッション数 | 1 | N（エージェントチェーン長） |
| 計画フェーズ | なし | 必須（planner/architect が先行） |
| フェーズゲート | なし | ハンドオフ文書 + tmux wait-for |
| tmux ウィンドウ | 1 | N（各エージェント） |
| worktree | 1 | 1（共有） |

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/skills/orchestrate/orchestrate.sh` | dotfiles | 拡張: --workflow 引数、resolve_agent_chain、generate_agent_prompt、advance_loop |
| `configs/claude/skills/orchestrate/SKILL.md` | dotfiles | v0.0.4 に書き換え: workflow-type 必須化 |
| `docs/reference.md` | dotfiles | orchestrate の説明とアーキテクチャ図を更新 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-060 セクション）
