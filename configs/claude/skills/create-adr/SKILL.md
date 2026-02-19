---
name: create-adr
description: >-
  「ADRを作成して」「ADR書いて」「create-adr」のようにADRの作成を依頼された場合に使用する。
  チームのConfluenceテンプレートに基づきMarkdownファイルを生成し、コードベースとの事実照合と
  review-adrスキルによるレビューループ（Critical/Major解消まで最大5回）を経て .outputs/claude/ に出力する。
context: fork
agent: general-purpose
allowed-tools: Read, Write, Glob, Grep, Task, Skill, Bash(ls:*), Bash(mkdir:*)
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

### Step 4: 絵文字の検証

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

いずれかの検証に失敗した場合、出力ファイルを修正してから次のステップへ進む。

### Step 4.5: 事実確認（コードベース照合）

ADR 内で具体的に言及している事実（設定値、コンポーネント名、ファイルパス等）を Glob/Grep/Read でコードベースと照合する。

**手順**:
1. ADR の Decision・Consequences・Options Considered セクションから「確認が必要な事実」を列挙する
   - 具体的なファイルパス、設定値、コンポーネントの挙動など
2. 各事実を Glob/Grep/Read ツールで実際のコードベースを確認して照合する
3. 不一致があれば ADR を修正してから次のステップへ進む

**確認の優先度**（高い順）:
- ファイルパスの実在確認（存在しないパスを参照していないか）
- 設定値の一致確認（コードベースの実際の値と一致しているか）
- コンポーネントの動作確認（DaemonSet の toleration 設定など、実装と記述が合っているか）

### Step 5: review-adr スキルによるレビューループ

Critical/Major 指摘が解消されるまで review-adr → ADR修正のループを繰り返す。

**5-1: review-adr の実行**

Skill ツールを使って review-adr スキルを呼び出す:
```
Skill(skill: "review-adr", args: "<ADRファイルの絶対パス>")
```

**5-2: レビュー結果の確認**

review-adr スキルが生成するレビューファイル（`.outputs/claude/adr-review-<ベース名>.md`）を Read ツールで読み込む。
以下の条件でループ継続か終了かを判断する：

| 条件 | 判断 |
|------|------|
| `## Critical` セクションに「指摘事項なし」以外の内容がある | → 5-3 へ（修正が必要） |
| `## Major` セクションに「指摘事項なし」以外の内容がある | → 5-3 へ（修正が必要） |
| Critical/Major ともに「指摘事項なし」 | → Step 6 へ（承認） |

**5-3: ADR の修正**

Critical/Major 指摘の内容に基づいて ADR を修正する:
1. 各指摘の種類に応じた修正方針を決める：
   - **事実誤認（fact-checker 指摘）**: Glob/Grep/Read でコードベースを確認してから正確な内容に修正
   - **根拠不足（logic-reviewer 指摘）**: 判断の根拠・評価基準を明示する記述を追加
   - **整合性問題（consistency-checker 指摘）**: Context-Decision-Consequences の対応関係を見直す
2. Write ツールで ADR ファイルを更新する
3. 5-1 に戻る（再レビュー実行）

**無限ループ防止**: 5-1 の実行回数を内部でカウントする（初回実行で 1 回とカウント）。5回目の 5-1 実行後に 5-2 の条件判定を行い、それでも Critical/Major が残る場合はループを終了して Step 6 へ進む。Step 6 の完了報告に「5回上限到達・未解消の指摘あり」を明記してユーザーに判断を委ねる。

### Step 6: 完了報告

以下の情報を含めて報告する:
- ADR ファイルの絶対パス
- レビュー結果ファイルのパス（`.outputs/claude/adr-review-<ベース名>.md`）
- レビューループの回数（何回の修正で承認されたか）
- 残存する Minor 指摘の件数（対応は任意）
