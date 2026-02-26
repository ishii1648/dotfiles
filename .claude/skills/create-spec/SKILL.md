---
name: create-spec
description: This skill should be used when the user asks to "create-spec", "課題を追加して", "spec作って", "issueに追加して", or describes a problem/pain point they want to track. Creates an entry in docs/issues.md and a corresponding Draft ADR in docs/adr/.
version: 0.1.0
---

# create-spec

課題や問題に感じたことを受け取り、`docs/issues.md` へのエントリ追記と `docs/adr/` への初期 ADR 作成を行う。

## 目的

- 課題と ADR を常に対応させ、トレーサビリティを保つ
- テーブル記法の手間なく課題を追加できるようにする

## ステップ

### Step 1: 入力解析

ユーザーの入力（箇条書き or 自由文）から以下を抽出する：

- **課題の本質**: 何が問題か・何が不便か
- **コンポーネント**: 関係するコンポーネントを特定する（tmux / fish / claude / ghostty / nvim / 複合）
- **解決可能性の見立て**:
  - `○` = 技術的に解決可能
  - `△` = 完全解決は難しいがワークアラウンドあり
  - `×` = アーキテクチャ上の制約で対応不可

### Step 2: ADR 番号の決定

`$PWD/docs/adr/` 内のファイルを Glob で確認し、既存の最大番号 + 1 を次番号とする。番号は3桁ゼロ埋め（001, 002, ... 009, 010）。

### Step 3: ADR 作成

`$PWD/docs/adr/NNN-英語タイトル.md` を Write ツールで作成する。

- ファイル名はハイフン区切りの英語（例: `009-fish-tmux-keybind-sharing.md`）
- 日本語タイトルは英訳する

**テンプレート:**

```markdown
# ADR-NNN: 日本語タイトル

## ステータス

Draft

## コンテキスト

（ユーザー入力を展開して詳細に記述。なぜ問題か・どのような状況で発生するか・現状の回避策があれば何か）

## 決定

（未定）

## 結果

（未定）
```

### Step 4: issues.md に追記

`$PWD/docs/issues.md` のテーブル末尾に1行追記する。既存行は変更しない。

**追記フォーマット:**

```
| - | ○ | tmux / fish | 課題サマリ — 背景の一文 | [ADR-NNN](adr/NNN-title.md) |
```

- 対応済み列: `-`（未対応）固定
- 対応可能列: Step 1 で判断した `○` / `△` / `×`
- コンポーネント列: `/` 区切りで複合も表記可
- サマリ列: 「課題 — 背景の一文」形式
- ADR 列: Step 3 で作成したファイルへの相対リンク

### Step 5: 完了報告

追記した issues.md の行と作成した ADR パスを報告する。

## 制約

- 操作対象は常に `$PWD` 配下（worktree 対応）
- ADR は `$PWD/docs/adr/` に直接作成する（`.outputs/claude/` ではない）
- issues.md は末尾追記のみ。既存行は変更しない
