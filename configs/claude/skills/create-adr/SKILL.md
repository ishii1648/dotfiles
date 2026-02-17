---
name: create-adr
description: >-
  Generates an ADR Markdown file from the team's Confluence template with
  proper Unicode emojis and saves it to .outputs/claude/.
  Use when the user says "ADRを作成して", "ADR書いて", or "create-adr".
context: fork
agent: general-purpose
allowed-tools: Read, Write, Glob, Bash(ls:*), Bash(mkdir:*)
argument-hint: "<ADRタイトル>"
---

# Create ADR

## 概要

チームの Confluence ADR テンプレートに基づき、ADR (Architecture Decision Record) の Markdown ファイルを生成して `.outputs/claude/` 配下に出力する。

## 引数

- **ADRタイトル**（必須）: ADR の件名（例: `API Gateway の選定`）

## 絵文字マッピング

このテンプレートには変換済みの Unicode 絵文字が直接含まれているため、`confluence-emoji-mapping` スキルを別途参照する必要はない。マッピングの元データは `confluence-emoji-mapping` スキルに定義されている。

## ワークフロー

### Step 1: 入力の確認

`$ARGUMENTS` から ADR タイトルを取得する。空の場合はユーザーにタイトルの入力を促す。

### Step 2: ADR ファイルの生成

以下のテンプレートに基づき Markdown ファイルを生成する。プレースホルダー部分はイタリック体で残す。

```markdown
# <ADRタイトル>

| | |
|---|---|
| **Driver** | _@ 投稿者_ |
| **Notified** | _@ 関係者_ |
| **Score** | 影響範囲: / 不可逆性: / 総合点: |

## 📘 Context

_背景・文脈・問題を記述_

## ✅ Decision

_決定とその根拠を記述_

## 🌟 Consequences

_決定による影響（例: xxx の工数が 50% 削減される）を記述_

## 🌈 Options Considered

_比較したオプションの pros/cons やその詳細を記述_

- option A
  - (pros)
  - (cons)
- option B
  - (pros)
  - (cons)

## 🤖 Compliance

_意思決定が順守されていることを確認する方法（例: テストの方法、テストの箇所、テストの実行方法）を記述_

## (note) Note

_その他備考があれば記述_

## 📖 References

_関連資料があれば記述_
```

### Step 3: ファイル出力

1. `mkdir -p .outputs/claude` を実行して出力ディレクトリを確保する
2. ADR タイトルからファイル名を生成する:
   - スペースをハイフンに置換
   - 英数字・ハイフン・アンダースコア・日本語以外の文字を除去
   - 先頭に `adr-` プレフィックスを付与
   - 末尾に `.md` を付与
   - 例: `adr-api-gatewayの選定.md`
3. `.outputs/claude/<ファイル名>` に書き込む

### Step 4: 完了報告

出力ファイルの絶対パスをユーザーに表示する。

## 絵文字の検証

出力ファイル生成後、以下を確認する:

1. 見出しの絵文字が Unicode 文字として正しく含まれていること（`<custom>` タグが残っていないこと）
2. テンプレート内の各セクション見出しに対応する絵文字:
   - Context → 📘
   - Decision → ✅
   - Consequences → 🌟
   - Options Considered → 🌈
   - Compliance → 🤖
   - Note → (note)
   - References → 📖
3. Options の pros/cons 表記が `(pros)` / `(cons)` であること（`:plus:` / `:minus:` が残っていないこと）

いずれかの検証に失敗した場合、出力ファイルを修正してから完了報告する。
