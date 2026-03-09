# ADR-040: Spike ADR ライフサイクルの明文化

## ステータス
採用済み

## 関連 ADR
- 依存: ADR-035（Spike パターン導入の基盤）
- 依存: ADR-025（ADR 運用ルール・ステータス定義の基盤）

## コンテキスト
ADR-035 で Spike パターンを導入したが、Spike 完了後のフロー（`Spike中 → Draft → adr-ship`）に
構造的欠陥があった。Draft に戻した時点で Spike 由来の痕跡が消え、adr-ship が
Spike ADR を通常 ADR と同様に「採用済み」に処理してしまうケースが発生した。

Spike の本質は「設計判断に必要な知見を得ること」であり、実装完了とは異なる。
Spike 完了後の ADR を「採用済み」にするのは意味的に誤りである。

## 設計案

`Spike完了` ステータスを追加し、Spike ADR は採用済みに遷移させない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `.claude/skills/adr-reference/skill.md` | dotfiles | `Spike完了` ステータス追加、遷移ルール更新 |
| `.claude/skills/adr-ship/skill.md` | dotfiles | `Spike完了` も適用対象外と明記 |
| `.claude/skills/create-adr/skill.md` | dotfiles | Spike作成時のステータス分岐追加 |
| `docs/development.md` | dotfiles | Spikeフロー修正 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-040 セクション）
