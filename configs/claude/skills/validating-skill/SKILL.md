---
name: validating-skill
description: >-
  スキル作成・更新後に自動実行し、SKILL.md を公式ドキュメントのベストプラクティスに基づき検証する。
  configs/claude/skills/ 配下のスキルを対象とし、frontmatter、命名規則、description品質、
  本文構造、progressive disclosure、コンテンツ品質、コード/スクリプト品質を検証する。
  create-skill スキル実行後、スキルファイル編集後、「スキルを検証して」と言われた時に使用する。
version: 0.2.0
context: fork
agent: general-purpose
allowed-tools: Read, Glob, Grep, WebFetch
argument-hint: "[skill-name]"
---

# Validating Skill

## 概要

`configs/claude/skills/` 配下の SKILL.md ファイルを、Claude Code 公式ドキュメントのベストプラクティスに基づいて検証する。frontmatter の構文・意味チェック、命名規則、description 品質、本文構造、progressive disclosure、コンテンツ品質、スクリプト品質の 7 カテゴリで監査し、重要度別（Critical / Major / Minor）のレポートを**日本語で**出力する。PASS 項目は省略し、問題点のみを簡潔に報告する。

## 引数

- **skill-name**（省略可）: 指定したスキルのみを検証（例: `datadog`, `git-ship`）
- **引数省略時**: 直近で作成・更新されたスキルを自動検出して検証

## ワークフロー

### Step 1: 検証対象の解決

**最初に `$ARGUMENTS` を解析し、検証対象を決定する。**

1. `$ARGUMENTS` の値を確認する:
   - **引数あり**（スキル名が指定された場合）→ Glob パターン: `configs/claude/skills/$ARGUMENTS/SKILL.md`
   - **引数が空** の場合 → 直近で作成・更新されたスキルを自動検出:
     1. Glob `configs/claude/skills/*/SKILL.md` で全スキルを取得
     2. 各ファイルの更新日時を確認し、最新のものを対象とする
2. 決定したパターン/ファイルで対象を確定する
3. 指定スキルが見つからない場合:
   - `configs/claude/skills/*/SKILL.md` で全スキル一覧を取得し、利用可能なスキル名を列挙してエラー終了する
   - 例: `Error: skill "xxx" not found. Available skills: datadog, git-ship, ...`

### Step 2: 最新ドキュメントの取得

2 つの公式ドキュメントを WebFetch で取得し、検証基準を抽出する:

1. **Skills 仕様ドキュメント** (frontmatter フィールド、構造ルール):
   - URL: `https://code.claude.com/docs/en/skills`
   - 抽出対象: frontmatter フィールド名・制約、行数制限、ディレクトリ構造ルール

2. **ベストプラクティスドキュメント** (推奨事項、アンチパターン):
   - URL: `https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`
   - 抽出対象: description の書き方、命名規則、progressive disclosure、アンチパターン

**フォールバック**: いずれかの WebFetch が失敗した場合、後述の「埋め込みチェックリスト」を使用する。レポートの `Validation Source` に使用したソース（`Fetched docs` / `Embedded checklist` / `Mixed`）を明記する。

**重要**: 取得したドキュメントの内容が埋め込みチェックリストと矛盾する場合は、**取得したドキュメントを優先**する。

### Step 3: 各スキルの検証

対象スキルごとに、Read でファイル内容を読み込み、以下の 7 カテゴリで検証する。

#### 3a: Frontmatter 検証 (Critical)

- `---` 区切りが先頭と末尾に存在するか
- `name` フィールド:
  - 存在するか
  - 64 文字以下か
  - 小文字英数字 + ハイフンのみか（`^[a-z0-9]+(-[a-z0-9]+)*$`）
  - 予約語でないか（`help`, `clear`, `exit`, `quit`, `login`, `logout`, `config`, `settings`, `setup`）
- `description` フィールド:
  - 存在し、空でないか
  - 1024 文字以下か
  - XML タグ（`<...>`）を含んでいないか
- `version` フィールド: semver 形式か（存在する場合）
- `allowed-tools`: 存在する場合、書式が正しいか
- `argument-hint`: `$ARGUMENTS` を本文で使用している場合に存在するか
- 未知のフィールド名がないか（公式仕様に照らして警告）

#### 3b: Description 検証 (Major)

- 三人称で書かれているか（"I can", "You can", "We can" を使用していないか）
- 「何をするか」（機能）と「いつ使うか」（トリガー条件）の両方が含まれているか
- 具体的な動詞で始まっているか（"Manages...", "Validates...", "Automates..." など）
- 冗長な表現がないか（"This skill is used to..." など間接的な表現）

#### 3c: 命名規則検証 (Major)

- スキル名がディレクトリ名と `name` フィールドで一致するか
- ケバブケース（小文字 + ハイフン）か
- 動名詞（gerund: -ing 形）の命名が推奨される点を情報提供（Minor レベル）
  - 例: `validating-code` vs `validate-code` → 後者でも PASS だが提案を出す

#### 3d: 本文構造検証 (Critical/Major)

**Critical:**
- **本文が日本語で書かれているか**: 見出し・説明文が日本語であること（コードブロック、技術用語、固有名詞は除く）
  - 検出方法: 本文（frontmatter 以降）にひらがな・カタカナが含まれているか確認
  - 英語のみで書かれている場合は Critical エラー

**Major:**
- 総行数が 500 行以下か（Read で取得した最終行番号で判定）
- H1 見出し（`#`）が1つだけ存在するか
- セクション構造が論理的か（概要 → 詳細 → 例の順）
- 参照先ファイル（パスを含む記述）が実際に存在するか（Glob/Read で確認）
- 参照が 2 階層以上ネストしていないか（SKILL.md → A → B のように）

#### 3e: Progressive Disclosure 検証 (Major)

- 100 行超のファイルに目次または構造的なセクション分けがあるか
- 冒頭に概要セクションがあるか
- 例やテンプレートが本文末尾寄りに配置されているか
- 過度にフラットな構造（見出しなしの長文）になっていないか

#### 3f: コンテンツ品質検証 (Minor/Info)

- 時間依存コンテンツがないか（"as of 2024", "currently", 特定の日付への依存）
- ハードコードされた絶対パスがないか（ユーザー固有パスの検出）
- 用語の不統一がないか（同じ概念に複数の表記を使用）
- `$ARGUMENTS` を使用している場合に `argument-hint` が存在するか

#### 3g: スクリプト/コード検証 (該当時のみ)

- コードブロック内のスクリプトにエラーハンドリングがあるか
- コードブロックに言語指定があるか（````bash`, ````python` など）
- 外部コマンド実行時に適切なツール指定がされているか

### Step 4: レポート出力

検証結果を以下のフォーマットで出力する。

## 埋め込みチェックリスト（フォールバック用）

WebFetch が失敗した場合に使用するコアルール一覧。このリストは 2025-05 時点の公式ドキュメントに基づく。

### Frontmatter ルール

| フィールド | 必須 | 制約 |
|-----------|------|------|
| `name` | Yes | 64文字以下、`^[a-z0-9]+(-[a-z0-9]+)*$`、予約語不可 |
| `description` | Yes | 1024文字以下、XMLタグ不可、三人称推奨 |
| `version` | No | semver形式（`X.Y.Z`） |
| `context` | No | `fork` \| `none`（デフォルト: `none`） |
| `agent` | No | `general-purpose` \| その他のエージェント名 |
| `allowed-tools` | No | カンマ区切りのツール名リスト |
| `argument-hint` | No | 引数のヒント文字列 |
| `disable-model-invocation` | No | `true` \| `false` |

### Description ルール

- 三人称で記述（"I", "You", "We" を主語にしない）
- 機能（何をするか）とトリガー（いつ使うか）の両方を含む
- 具体的な動詞で始める
- 1024 文字以下
- XML タグを含めない

### 構造ルール

- **本文は日本語で記述すること**（Critical）
- 総行数 500 行以下
- H1 見出しは 1 つのみ
- 100 行超の場合はセクション分け・目次を推奨
- 参照ネストは 1 階層まで
- 冒頭に概要を配置

### 命名ルール

- ディレクトリ名 = `name` フィールド値
- ケバブケース（小文字英数字 + ハイフン）
- gerund 形式が推奨（強制ではない）

### アンチパターン

- **本文が英語のみで書かれている**（Critical）
- ハードコードされたユーザー固有パス
- 時間依存コンテンツ（特定日付、"currently" など）
- `$ARGUMENTS` 使用時に `argument-hint` なし
- description での一人称・二人称使用
- 500 行超の単一ファイル（分割を検討）
- 見出しなしの長文ブロック

## レポートフォーマット

**出力は全て日本語で行う。** ヘッダー・ラベル・説明文すべて日本語とする。PASS 項目は省略し、問題のある項目（FAIL / WARN）のみを報告する。

### ステータス判定基準

- **FAIL**: Critical エラーが 1 件以上
- **WARN**: Critical なし、Major が 1 件以上
- **PASS**: Critical なし、Major なし（Minor は許容）

### 単一スキル検証時

```
## 検証レポート: <skill-name>

**ステータス: PASS | WARN | FAIL** ── Critical: N / Major: N / Minor: N
検証ソース: Fetched docs | Embedded checklist | Mixed

### Critical (N)
- L{行}: {説明} → {修正方法}

### Major (N)
- L{行}: {説明} → {推奨対応}

### Minor (N件)
- {1行サマリー列挙}

### 総評
{2-3文の総合評価。何が良くて何を直すべきか}
```

**出力ルール:**
- Critical / Major が 0 件のセクションは **`なし`** と 1 行で済ませる
- Minor は詳細説明なしの 1 行リスト（件数 + 項目名のみ）
- Best Practices Checklist テーブルは **出力しない**（PASS 項目を列挙しない）

## エラーハンドリング

| シナリオ | 対応 |
|---------|------|
| 指定スキルが見つからない | 利用可能なスキル一覧を表示して終了 |
| SKILL.md が空ファイル | Critical エラーとして報告 |
| WebFetch 両方失敗 | 埋め込みチェックリストで検証続行、ソースを明記 |
| WebFetch 片方のみ失敗 | 成功分 + 埋め込みチェックリストの組み合わせ、ソースを `Mixed` と明記 |
| frontmatter パース不可 | Critical エラーとして報告、本文検証は続行 |
| 参照先ファイルのアクセス不可 | Major として報告、検証は続行 |
