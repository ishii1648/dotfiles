---
name: jira-todo-breakdown
description: >-
  JiraチケットからTODOリストを自動生成する。チケット情報・関連ADR・Confluence・コードベースを
  並列で調査し、AI担当/人担当に振り分けたTODOをPhase別に構造化して出力する。
  「TODOを洗い出して」「タスク分解して」「JiraチケットのTODO」と言われた時に使用する。
version: 0.1.0
context: fork
agent: general-purpose
allowed-tools: Read, Write, Glob, Grep, Task, ToolSearch, WebFetch, Bash(ls:*), Bash(mkdir:*)
argument-hint: "<JiraチケットURL or キー>"
---

# Jira TODO Breakdown

## 概要

JiraチケットのURLまたはキー（例: `SREPO-2071`）を受け取り、チケット情報・関連ADR・Confluenceドキュメント・コードベースを並列に調査して、構造化されたTODOリストを `.outputs/claude/<チケットキー>-todos.md` に出力する。

TODOはAI担当と人担当に振り分けられ、Phase別にグルーピングされる。これにより、チケット着手前の計画立案を効率化する。

## 引数

- **JiraチケットURL or キー**（必須）: 対象チケットの識別子
  - URL例: `https://jira-freee.atlassian.net/browse/SREPO-2071`
  - キー例: `SREPO-2071`

## 共通コンテキスト

```yaml
team: t9s
confluence:
  space: SPO
  cloudId: jira-freee.atlassian.net
  adr_parent_page_id: "2312601820"
  t9s_top_page_id: "2480508411"
```

## ワークフロー

### Step 1: 入力の正規化

`$ARGUMENTS` からチケットキーを抽出する。URLの場合はパスの末尾からキーを取得する。

### Step 2: 並列調査（1a〜1f を同時実行）

ToolSearchで必要なMCPツールをロードした後、以下の調査を **Taskツールで並列に** 実行する。

#### 2a. Jiraチケット読み取り

Atlassian MCPの `getJiraIssue` でチケット情報を取得する。

- 取得項目: summary, description, acceptance criteria, labels, components, linked issues
- descriptionに含まれるリンクURLも抽出する

#### 2b. 関連ADR検索

チケットのsummaryとdescriptionからキーワードを抽出し、Confluence CQLで関連ADRを検索する。

```
キーワード抽出ルール:
- チケットタイトルから技術用語・サービス名・機能名を抽出
- 一般的な動詞・助詞・形容詞は除外
- 2〜3個のキーワードに絞る
```

CQLクエリ:
```
ancestor = 2312601820 AND title ~ "<keyword1>" AND title ~ "<keyword2>"
```

Atlassian MCPの `searchConfluenceUsingCql` で検索し、ヒットしたADRの本文を `getConfluencePage` で取得する。

#### 2c. ADRテンプレート参照（条件付き）

チケットの完了条件にADR作成が含まれる場合、`references/adr-template.md` を参照する（Confluence取得不要）。

#### 2d. description内リンク先の取得

2aで抽出したリンクURLについて:
- Confluenceリンク → Atlassian MCPで本文取得
- その他のリンク → WebFetchで内容取得

#### 2e. コードベース調査

TaskツールのExplore agentを使用して、チケットに関連するコード領域を調査する。

- チケットの対象サービス・機能に関連するファイル構造
- 既存の実装パターン
- 設定ファイル・定義ファイルの構造

#### 2f. 技術スタック推定

コードベースから使用技術を判断する。

- 言語・フレームワーク
- インフラ構成（Kubernetes manifests, Helm charts, Terraform等）
- CI/CDパイプライン構成
- **コードに存在しない技術は言及しない**

### Step 3: アウトプット生成

Step 2の調査結果を統合し、`.outputs/claude/<チケットキー>-todos.md` に出力する。出力前に `mkdir -p .outputs/claude` を実行する。

アウトプットは以下の7セクション構成（詳細フォーマットは `references/output-format.md` を参照）：

1. 背景
2. 完了条件
3. 既存設計・関連ドキュメントの要約（表形式）
4. 対象領域の現状（表形式）
5. AI担当TODO（Phase別グルーピング、3列: #, TODO, 完了条件）
6. 人担当TODO（1テーブル、4列: #, TODO, 理由, 完了条件、番号は `H-` prefix）
7. 実行フロー（mermaid図）

## 担当振り分けルール

| 分類 | 基準 |
|------|------|
| AI（デフォルト） | 調査・分析・ドラフト作成・実装・検証・レポート作成 |
| 人（限定） | 最終意思決定、組織間合意形成、ADR Driver/Notified記入、ADR最終承認 |
| 記載しない | 環境展開Go/NoGo判断、PRレビュー・マージ等の自明な作業 |

## ベストプラクティス

- 調査は可能な限り並列実行し、効率を最大化する
- コードベースに存在しない技術スタックには言及しない
- TODOの粒度は「1回のClaude Codeセッションで完了可能」を目安にする
- 人担当TODOには必ず「なぜAIが担当できないか」の理由を記載する
- Phase間の依存関係を明確にし、並列実行可能なタスクを識別する

## エラーハンドリング

| シナリオ | 対応 |
|---------|------|
| Jiraチケットが見つからない | エラーメッセージを表示し、キーの確認を促す |
| Confluence検索結果が0件 | 「関連ADRなし」と記載し、処理を継続 |
| MCPツールのロード失敗 | エラーを報告し、手動での情報収集を促す |
| コードベース調査で対象不明 | チケット情報のみでTODOを生成し、調査不足を明記 |

## 追加リソース

### 参照ファイル
- **`references/adr-template.md`** - t9s ADRテンプレート（Confluenceから取得済み）。ADRドラフト作成時のセクション構成として使用
- **`references/output-format.md`** - アウトプットの7セクション構成とテーブルフォーマットの詳細仕様
- **`references/skill-spec.md`** - スキルの詳細仕様書。AI/人の担当振り分け基準の具体例、キーワード抽出ルール、CQLクエリのテンプレート、Jiraチケットの最小構成要件を含む
