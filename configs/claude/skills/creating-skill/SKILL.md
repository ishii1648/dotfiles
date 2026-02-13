---
name: creating-skill
description: >-
  新しいスキルを正しいフォーマットとディレクトリ構造で作成し、検証・改善まで自動化する。
  スキル作成後に validating-skill を自動実行し、major以上の指摘がなくなるまで修正を繰り返す。
  「スキルを作成して」「新しいスキルを作って」「create skill」と言われた時に使用する。
version: 0.1.0
context: fork
agent: general-purpose
allowed-tools: Write, Read, AskUserQuestion, Task, Glob, Bash(mkdir:*), Skill
argument-hint: "[skill-name]"
---

# スキル作成

## 概要

新しいスキルを正しいディレクトリ構造と SKILL.md フォーマットで作成する。作成後は自動的に `validating-skill` で検証を行い、Critical または Major の指摘がなくなるまで修正を繰り返す。これにより、ベストプラクティスに準拠したスキルを効率的に作成できる。

## 引数

- **skill-name**（省略可）: 作成するスキル名（ケバブケース）
- 省略時は対話形式で要件を収集する

## ワークフロー

### Step 1: 要件収集

`$ARGUMENTS` または対話で以下を確認する：

1. **スキル名**: ケバブケース（例: `my-skill`）、動名詞形（-ing）を推奨
2. **トリガーフレーズ**: このスキルを呼び出すフレーズを3〜5個（引用符付き）
3. **目的**: このスキルが提供する機能や知識
4. **必要なリソース**:
   - 参照ドキュメント（`references/`）
   - サンプルファイル（`examples/`）
   - ヘルパースクリプト（`scripts/`）

### Step 2: 保存場所の決定

ユーザーに保存場所を確認する：

- **プロジェクトローカル**: `.claude/skills/[skill-name]/`
- **パーソナル**: `configs/claude/skills/[skill-name]/`

### Step 3: ディレクトリ構造の作成

必要なディレクトリを作成する：

```bash
mkdir -p [location]/skills/[skill-name]
mkdir -p [location]/skills/[skill-name]/references  # 必要に応じて
mkdir -p [location]/skills/[skill-name]/examples    # 必要に応じて
mkdir -p [location]/skills/[skill-name]/scripts     # 必要に応じて
```

### Step 4: SKILL.md テンプレート生成

後述のテンプレートを使用して SKILL.md の内容を生成する。

### Step 5: SKILL.md 書き込み

生成した内容を `[skill-directory]/SKILL.md` に書き込む。

### Step 6: サポートファイル作成

必要に応じて `references/`、`examples/`、`scripts/` 配下にファイルを作成する。

### Step 7: 検証と自動改善ループ

**このステップが本スキルの核心機能である。**

1. Skill ツールで `validating-skill [作成したスキル名]` を実行
2. 検証結果を解析:
   - **Critical または Major エラーがある場合**:
     - エラー内容を解析し、SKILL.md を自動修正
     - 修正後、再度 Step 7.1 を実行（最大3回まで）
   - **Minor のみまたは PASS の場合**:
     - ループ終了、Step 8 へ進む
3. 3回の改善後も Major 以上が残る場合:
   - 残りの問題をユーザーに報告し、手動対応を促す

### Step 8: 完了報告

作成したスキルの情報を報告する：

- ディレクトリ構造
- 検証結果（最終ステータス）
- 使用方法（`/[skill-name]` で呼び出し可能）

## テンプレート

SKILL.md は以下のフォーマットで作成する：

```markdown
---
name: [skill-name]
description: >-
  [機能の説明]。[トリガー条件の説明]。
  「[phrase1]」「[phrase2]」「[phrase3]」と言われた時に使用する。
version: 0.1.0
context: fork
agent: general-purpose
allowed-tools: [必要なツール]
argument-hint: "[引数のヒント]"  # $ARGUMENTS 使用時のみ
---

# [スキルタイトル]

## 概要

[2〜3段落でスキルの目的と機能を説明]

## 引数

[引数の説明。引数がない場合は省略可]

## ワークフロー

### Step 1: [ステップ名]

[ステップの詳細]

### Step 2: [ステップ名]

[ステップの詳細]

## ベストプラクティス

- [プラクティス1]
- [プラクティス2]

## 追加リソース

### 参照ファイル
- **`references/[file].md`** - [説明]

### サンプル
- **`examples/[file]`** - [説明]
```

## フォーマットルール

### Critical（必須）

1. **本文は日本語で記述する**（ひらがな・カタカナを含む）
2. **frontmatter の `---` 区切り**が先頭と末尾に存在する
3. **`name` フィールド**: 64文字以下、ケバブケース、予約語不可
4. **`description` フィールド**: 1024文字以下、XMLタグ不可
5. **`$ARGUMENTS` 使用時は `argument-hint` 必須**

### Major（推奨）

1. **description は三人称で記述**（"I can", "You can" を使わない）
2. **description に機能とトリガー条件の両方を含める**
3. **総行数 500 行以下**
4. **H1 見出しは 1 つのみ**
5. **100 行超の場合はセクション分けまたは目次を設ける**

### Minor（情報提供）

1. 動名詞形（-ing）の命名を推奨
2. 時間依存コンテンツを避ける
3. ハードコードされた絶対パスを避ける

## エラーハンドリング

| シナリオ | 対応 |
|---------|------|
| ディレクトリ作成失敗 | エラーメッセージを表示し、手動作成を促す |
| 検証で Critical エラー | 自動修正を試行、3回失敗で手動対応を促す |
| 検証で Major エラー | 自動修正を試行、3回失敗で手動対応を促す |
| validating-skill 実行失敗 | エラーを報告し、手動検証を促す |
