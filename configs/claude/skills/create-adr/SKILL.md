---
name: create-adr
description: >-
  「ADRを作成して」「ADR書いて」「create-adr」のようにADRの作成を依頼された場合に使用する。
  ADR (Architecture Decision Record) の Markdown ファイルを生成し、コードベースとの事実照合と
  review-adrスキルによるレビューループ（Critical/Major解消まで最大5回）を経て .outputs/claude/ に出力する。
context: fork
agent: general-purpose
allowed-tools: Read, Write, Glob, Grep, Task, Skill, ToolSearch, mcp__atlassian-v2__getJiraIssue, Bash(ls:*), Bash(mkdir:*)
argument-hint: "<ADRタイトル> [JiraチケットURL または 調査コンテキスト]"
---

# Create ADR

## 概要

ADR (Architecture Decision Record) の Markdown ファイルを生成して `.outputs/claude/` 配下に出力する。

## 引数

- **ADRタイトル**（必須）: ADR の件名（例: `API Gateway の選定`）
- **コンテキスト**（任意）: 以下のいずれかを指定できる
  - Jira チケット URL（例: `https://jira-freee.atlassian.net/browse/SREPO-XXXX`）
  - 既存の調査ファイルパス（`.outputs/claude/` 配下の Markdown ファイル）
  - フリーテキストの問題・背景説明

## ワークフロー

### Step 1: 入力の確認

`$ARGUMENTS` を解析して以下を取得する:

1. **ADRタイトル**（必須）: 引数の先頭部分。空の場合はユーザーにタイトルの入力を促す。
2. **コンテキスト**（任意）: タイトルに続く残りの引数。以下の3種類を識別する:
   - **Jira URL**: `https://` で始まり `atlassian.net/browse/` を含む文字列
   - **調査ファイルパス**: `.outputs/claude/` を含むファイルパス文字列
   - **フリーテキスト**: 上記以外の文字列（問題や背景の説明）
   - **未指定**: 引数にコンテキストが含まれない場合 → アーリーリターン

**コンテキストが未指定の場合のアーリーリターン**:

以下をユーザーに伝えてスキルを終了する:

```
コンテキストが指定されていません。以下のいずれかを指定して再度実行してください:

- Jira チケット URL（例: https://jira-freee.atlassian.net/browse/SREPO-XXXX）
- 調査ファイルパス（例: .outputs/claude/xxx.md）
- フリーテキストの問題・背景説明
```

### Step 1.5: 調査観点の洗い出し

コンテキストを解析して「ADR に必要な事実を特定するための調査観点」を 3〜5 カテゴリに整理する。

**コンテキストが Jira URL の場合の手順**:

1. `mcp__atlassian-v2__getJiraIssue` でチケット情報（課題説明・完了条件・背景）を取得する
   （このツールは allowed-tools に含まれており、直接呼び出し可能）
2. 取得した内容（summary, description, acceptance criteria 等）を基に調査観点を設計する
3. **重要**: チケットの summary（タイトル）が ADR タイトルと大きく異なる場合、チケットの内容を優先して ADR タイトルを修正し、ユーザーに通知する

**コンテキストが調査ファイルパスの場合**:
- 該当ファイルを Read ツールで読み込み、調査結果から不足している観点を補完する

**コンテキストがフリーテキストの場合**:
- ADR タイトルとフリーテキストの内容から調査観点を推測して設計する

**調査観点の設計ルール**:
- 3〜5 個のカテゴリに整理する（後続の Task エージェント数と対応させる）
- 各カテゴリに対し「確認すべきファイルパスパターン（Glob パターン）」と「確認すべき具体的な値・属性」を明示する
- **コードベース調査が必要な ADR（Kubernetes 設定変更・インフラ設計・Helm 値変更等）の場合のみ**:
  設定の「継承元（chart-libs / helmfile-libs / values 直書きのいずれか）」を特定する指示を各カテゴリに含める
- 技術選定・プロセス変更等のコードベース非依存 ADR の場合: 継承元特定の指示は不要

### Step 1.7: agent team による並列調査

Step 1.5 で洗い出した観点を Task エージェントに分割して並列起動する。

**エージェント数の決め方**:
- 観点が 3 カテゴリ以下: 観点ごとに 1 エージェントを並列起動（最大 3 並列）
- 観点が 4 カテゴリ以上: 関連する観点をグループ化して最大 3 エージェントに集約

**各エージェントへの指示に必ず含める内容**:
- 調査するファイルパスのパターン（Glob パターンを明示）
- 確認すべき具体的な値や属性
- 「設定の継承元（chart-libs / helmfile-libs / values 直書きのいずれか）まで特定すること」という指示
- Task の `subagent_type` は `Explore`、`thoroughness` は `very thorough` を指定

**結果の統合**:

全エージェントの結果が出揃ったら以下を実施する:
1. 各エージェントの調査結果を統合する
2. 矛盾や疑問点がないか確認する
3. 不明点は追加の Glob/Grep/Read で補完してから次へ進む

### Step 2: ADR ファイルの生成

Step 1.7 の調査結果を参照しながら、以下のテンプレートに基づき Markdown ファイルを生成する。

**フィールドの扱い**:
- **コンテンツセクション**（Context / Decision / Consequences / Options Considered / Compliance）:
  プレースホルダーを残さず、調査結果に基づいた内容で埋める
- **メタデータフィールド**（Driver / Notified / Score）:
  ユーザーが記入する性質のため、テンプレートの記述（`_@ 投稿者_` 等）をそのまま維持する
- **確認できなかった項目**（コンテキスト未提供またはフリーテキストのみの場合）:
  イタリック体で「_（要確認: <確認すべき内容>）_」と記述する

| セクション | 埋め方 |
|----------|--------|
| Context | 調査で得られた背景・現状の問題点・根拠データを記述 |
| Decision | 調査結果に基づく推奨案とその根拠を記述 |
| Consequences | 調査から判明した影響・リスク・工数を記述 |
| Options Considered | 調査で洗い出した代替案と pros/cons を記述 |
| Compliance | 調査で確認した設定の検証方法を記述 |

```markdown
# <ADRタイトル>

| | |
|---|---|
| **Driver** | _@ 投稿者_ |
| **Notified** | _@ 関係者_ |
| **Score** | 影響範囲: / 不可逆性: / 総合点: |

## Context

_背景・文脈・問題を記述_

## Decision

_決定とその根拠を記述_

## Consequences

_決定による影響（例: xxx の工数が 50% 削減される）を記述_

## Options Considered

_比較したオプションの pros/cons やその詳細を記述_

- option A
  - (pros)
  - (cons)
- option B
  - (pros)
  - (cons)

## Compliance

_意思決定が順守されていることを確認する方法（例: テストの方法、テストの箇所、テストの実行方法）を記述_

## Note

_その他備考があれば記述_

## References

_関連資料があれば記述_
```

### Step 3: ファイル出力

1. `mkdir -p .outputs/claude` を実行して出力ディレクトリを確保する
2. ADR タイトルからファイル名を生成する:
   - タイトルが日本語の場合は英語に翻訳する
   - スペースをハイフンに置換
   - 英数字・ハイフン・アンダースコア以外の文字を除去
   - 先頭に `adr-` プレフィックスを付与
   - 末尾に `.md` を付与
   - 例: `adr-api-gateway-selection.md`
3. `.outputs/claude/<ファイル名>` に書き込む

### Step 4: 事実確認（コードベース照合）

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
