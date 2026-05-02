# ADR-042: Claude Code フック設計のスケーラビリティ改善

## ステータス
採用済み（案D・案E 実施済み、ヘッダ規約を導入。案A/B は将来課題として保留）

## 関連 ADR
- 関連: ADR-006（PreToolUse hook Bash 権限の基盤）
- 関連: ADR-008（redirect-to-tools の基盤）
- 関連: ADR-017（approve-safe-commands の基盤）
- 関連: ADR-037（approve-safe-file-ops の基盤）
- 関連: ADR-038（approve-safe-file-ops Read 対応）
- 関連: ADR-039（hook スクリプト存在チェック）
- 関連: ADR-041（settings.json の managed keys sync — 案E の実装基盤）
- 関連: ADR-052（claudedog 移動で hooks パスが変更された契機）

## コンテキスト

`configs/claude/settings.json` の `hooks` セクションは肥大化を続けており、現在は 7 イベント・20 エントリ前後を抱える。さらに今後も観測系 hook（claudedog, hitl-metrics 等）や安全フィルタの拡張が見込まれる。

```
SessionStart    → claude-pane-state.sh idle + claudedog/session-index.sh + workflow-session-start.sh + hitl-metrics(session-start, todo-cleanup)
UserPromptSubmit → claude-pane-state.sh running + SSH バナー
Notification (permission_prompt) → claude-notify.sh + claude-pane-state.sh permission + claudedog/permission-log.sh
Notification (elicitation_dialog) → claude-notify.sh + claude-pane-state.sh ask
PreToolUse (全ツール) → claudedog/pretooluse-track.sh
PreToolUse (Bash) → redirect-to-tools.py
PreToolUse (Bash) → approve-safe-commands.py
PreToolUse (全ツール) → approve-safe-file-ops.py（matcher なし、内部で Read/Write/Edit/NotebookEdit のみ承認）
PostToolUse → claude-pane-state.sh running post
PostToolUse (Skill) → skill-call-counter.sh
Stop → check-uncommitted-on-feature.sh + claude-pane-state.sh idle + workflow-session-log.sh + hitl-metrics(stop)
SessionEnd → claude-pane-state.sh end + hitl-metrics(session-end)
```

すべての hook 登録は dotfiles の `configs/claude/settings.json` をソースとし、`setup.sh` が `~/.claude/settings.json` の `hooks` キーを同期する（ADR-041）。claudedog・hitl-metrics 等の外部 CLI が settings.json を直接書き換える経路は存在しない（案E の前提）。hitl-metrics は `install` で hook を自動登録する機能を持たず、登録は dotfiles 経由・検証のみ `hitl-metrics doctor` が担当する設計（[hitl-metrics setup.md](https://github.com/ishii1648/hitl-metrics/blob/main/docs/setup.md)）。

当初挙げた問題は以下 3 つだが、案D・案E 完了後に再評価すると重みが大きく変わっている：

| # | 問題 | 現時点の評価 |
|---|---|---|
| 1 | settings.json の肥大化 | △ ADR-041 の自動同期で「手動編集の手間」は解消済み。残るのは行数のみで実害は小さい |
| 2 | 「なぜあるか」の喪失 | ◎ **未解決の本丸**。スクリプト名・コマンド文字列だけでは変更理由が追跡できない |
| 3 | スケーラビリティの欠如 | △ 案D で重複登録パターンを潰し、案E で外部 CLI 経路を統合した結果、新規追加もエントリ追記 1 行で済む |

つまり構造改革（案A・案B）は #1・#3 を狙うが、それらは前提実装によりほぼ無痛化されている。残るのは #2 のみで、これは構造選択と直交する **メタデータ問題** である。

## 前提（実施済み）

### 前提1: 案D — `approve-safe-file-ops.py` の重複解消（commit `b9c0a82`）

Read/Write/Edit/NotebookEdit の 4 エントリを `matcher` なしの 1 エントリに統合し、スクリプト内部でツール名チェックする方式へ移行済み。PreToolUse セクションが 4 エントリ → 1 エントリに削減され、追加ツール対応もスクリプト内で完結するようになった。

### 前提2: 案E — hook 登録経路の dotfiles 一元化

claudedog 等の外部 CLI が `install` で settings.json を直接編集する経路は廃止し、hook 登録は dotfiles の `configs/claude/settings.json` に集約済み。外部 CLI 側は `doctor` で「期待する hook エントリが登録されているか」のみ検証する。ADR-041 の managed keys sync により、dotfiles ソースが常に正となる。

## 設計案

### 採用: ヘッダ規約のみ先行導入

すべての hook スクリプトの先頭に、根拠 ADR と目的を明示するヘッダを必須化する。これにより問題 #2「『なぜあるか』の喪失」を構造変更なしで解消する。

```bash
#!/usr/bin/env bash
# ADR: 008
# Purpose: Bash 実行前に gh / jq 等の代替提案を行う
```

**良い点**:
- スクリプト本体と乖離しない（後述の案C のような別ファイル manifest だと陳腐化する）
- `grep -rE '^# ADR:' ~/.claude/scripts/` で全 hook の根拠が一覧できる
- 構造変更を伴わないため、ディスパッチャのバグ・暗黙の連番ルール・スクリプト内分岐肥大などの **新たな複雑度を持ち込まない**
- 案A・案B どちらに将来移行しても、ヘッダ規約はそのまま継承できる（前進的な投資）

特定 ADR を持たないスクリプト（プロジェクト規約由来など）は `# ADR: -` を許容する。`Purpose` は常に必須とし、validate は両フィールドの存在を確認する。

**実装内容**:
1. `configs/claude/settings.json` から参照される hook スクリプト全ファイルに `# ADR:` と `# Purpose:` ヘッダを追記
2. `scripts/lib/validate.sh` の hooks 検証に「コマンド先頭スクリプトのヘッダ存在確認」を追加。未記入の場合は WARN（既存設定への過剰な破壊を避けるため、初期は WARN・将来的に FAIL へ昇格）
3. `docs/development.md` に「新規 hook 追加時はヘッダ必須」を記載

claudedog 等の外部 CLI が提供するスクリプト（`~/.claude/claudedog/hooks/*.sh`）は dotfiles 管理外のため、本 ADR のヘッダ規約は適用しない。validate.sh の存在チェック（ADR-039）は引き続き行う。

**懸念**:
- 規約が形骸化するリスク → validate での自動検査でカバー
- ヘッダが事実と食い違うリスク（スクリプト改変時に未更新）→ ADR 番号の更新は規約として運用、最低限「Purpose の整合性」は PR レビューで担保

### 将来課題（保留）: 案A / 案B

問題 #1・#3 が前提実装で実質ほぼ解消したため、構造改革は **具体的な痛みが顕在化してから** 改めて検討する。トリガー条件の例：

- settings.json の `hooks` セクションが 30 エントリを超える
- 順序依存の hook が 3 種類以上のイベントで発生する
- 同一スクリプトを複数 matcher で重複登録するパターンが再び現れる

参考までに、案A・案B の概略は以下に残す（採用時のスタート地点として）。

#### 案A: ディレクトリベースディスパッチャ（保留）

`~/.claude/hooks/<event>/` にスクリプトを配置し、settings.json はディスパッチャ 1 行のみ登録。`*.d/` 系の慣習に倣い `00-`, `10-`, `20-` の gap-numbering で順序を表現。

- 良い点: 新規 hook 追加 = ファイル配置のみ。settings.json 編集不要
- 懸念: ディスパッチャ自身が新たな単一障害点（exit code・タイムアウト・stdin 引き継ぎの誤伝播がセキュリティ機構を無効化しうる）。settings.json → ディスパッチャ → スクリプト の間接層が増え、デバッグ時の追跡コストが上がる

#### 案B: 責務グループ統合（保留）

`pane-state.sh` / `security-gate.py` / `notify.sh` / `workflow.sh` の 3〜4 ドメイン別スクリプトに集約。settings.json の各エントリは集約後スクリプトを呼ぶだけ。

- 良い点: ディスパッチャを増やさず、Claude Code 標準機構をそのまま使う
- 懸念: スクリプト内 event/args 分岐が肥大化。`security-gate.py` の 1 つのバグが redirect・approve・file-ops の全責務を巻き添えにする。単体テストの分離が難しい

#### 案C: 別ファイル manifest（却下）

`docs/reference.md` または `~/.claude/hooks-map.md` に「イベント → スクリプト → 目的」を維持。スクリプト本体と乖離するため陳腐化する。**ヘッダ規約はこの問題を本質的に回避する**。

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-042 セクション）
