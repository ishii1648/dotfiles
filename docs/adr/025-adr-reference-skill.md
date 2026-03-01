# ADR-025: ADR 運用ルール・テンプレートを reference skill として集約する

## ステータス

採用済み

## コンテキスト

ADR が 23 件まで増え、以下の運用上の課題が顕在化している。

1. **採用案の表記ぶれ**: 設計案セクションで複数案を列挙する際、どれが採用されたかの記載が統一されていない。また独立した選択肢なのか、1 つの設計の構成要素なのか構造的に区別できない
2. **ADR 間の矛盾チェック機構がない**: 暗黙の依存関係（例: ADR-023 → ADR-016/021/022）はあるが、矛盾検出は人力に依存している
3. **Supersede フローが未定義**: ADR-005 は「採用済み（廃止）」だが、どの ADR が上書きしたのか、部分的か完全かが不明確

また、ADR と reference.md の役割分担も整理が必要である。

- **ADR**: 設計に関する意思決定の記録（時系列で蓄積される変更理由のログ）
- **reference.md**: その時点での dotfiles の設計を示すスナップショット（常に最新の状態を反映）

現状、reference.md の ADR 一覧は手動メンテナンスで ADR-019〜023 のリンクが欠落しており、`create-spec` / `adr-ship` のどちらも reference.md を更新しない。

これらのルールは `development.md` に書くよりも、Claude Code の skill として提供した方が適切である。理由:

- 主な参照者は Claude Code（`create-spec` / `adr-ship` スキル経由）
- skill としてトリガー条件を設定でき、ADR 作成・更新時に自動ロードされる
- `development.md` を開発フローの概要に留められる

## 設計案

### 案A: development.md にルールを追記（却下）

- メリット: 追加作業が少ない
- デメリット: Claude Code が参照するには development.md 全体を読む必要がある。ADR 固有のルールと開発フロー全般が混在する

### 案B: adr-reference skill を新設（採用）

`adr-reference` skill を作成し、以下を集約する:

**1. ADR と reference.md の役割分担**
- ADR: 意思決定の「なぜ」を記録（履歴として蓄積）
- reference.md: dotfiles の「今の全体像」を示すスナップショット（常に最新）
- ADR に「現状の設計」を書きすぎない。reference.md に「変更理由」を書かない

**2. ADR テンプレート（設計案セクションの構造ルール）**
- 独立した選択肢は `### 案A` / `### 案B` の見出しレベルで分離
- 1 つの設計内の構成要素は箇条書きで記述
- 各案に `（採用）` / `（却下）` ラベルを必須化

**3. ステータス定義と遷移**
- `Draft` → 検討中
- `採用済み` → 有効な意思決定
- `廃止（ADR-YYY で置換）` → 完全に上書きされた
- `部分廃止（ADR-YYY で一部変更）` → 一部の決定が上書きされた
- `却下` → 検討したが採用しなかった

**4. Supersede フロー（双方向リンク）**
- 新 ADR 側: 「コンテキスト」に「ADR-XXX の決定を変更する」と明記
- 旧 ADR 側: ステータスを `廃止（ADR-YYY で置換）` に更新し、どの決定が変更されたか注記
- 部分上書きの場合: 旧 ADR 側に変更された決定と引き続き有効な決定を明記

**5. 関連 ADR フィールド**
- `依存`: この ADR が前提とする ADR（例: ADR-022 は ADR-023 のネスト構成を前提）
- `関連`: 同じ領域の ADR（依存関係はないが文脈が共通）

**6. 矛盾チェックの指針**
- `create-spec` 時に同じコンポーネントの既存 ADR を確認するステップを追加
- `依存` で参照される ADR の前提と矛盾しないか確認

**7. reference.md の自動更新**
- `adr-ship` の完了処理（Step 5）で reference.md の ADR 一覧セクションに新規 ADR のリンクを追記する

**8. 既存スキルとの連携**
- `create-spec` / `adr-ship` スキルから `adr-reference` skill を参照する
- `development.md` は「詳細は `adr-reference` skill を参照」に簡略化

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `.claude/skills/adr-reference/skill.md` | dotfiles | 新規作成（ADR 運用ルール・テンプレート skill） |
| `.claude/skills/create-spec/skill.md` | dotfiles | `adr-reference` skill への参照を追加 |
| `.claude/skills/adr-ship/SKILL.md` | dotfiles | Step 5 に reference.md の ADR 一覧更新を追加 |
| `docs/development.md` | dotfiles | ADR 関連の詳細を skill への参照に置き換え |
| `docs/reference.md` | dotfiles | ADR 一覧セクションを全 ADR で補完 |
| `docs/adr/001-023` | dotfiles | 既存 ADR を新テンプレートに書き換え |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-025 セクション）
