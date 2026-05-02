# ADR-042: Claude Code フック設計のスケーラビリティ改善

## ステータス
Draft

## 関連 ADR
- 関連: ADR-006（PreToolUse hook Bash 権限の基盤）
- 関連: ADR-008（redirect-to-tools の基盤）
- 関連: ADR-017（approve-safe-commands の基盤）
- 関連: ADR-037（approve-safe-file-ops の基盤）
- 関連: ADR-038（approve-safe-file-ops Read 対応）
- 関連: ADR-039（hook スクリプト存在チェック）

## コンテキスト

現在の `settings.json` には 15 個の hook エントリが存在し、今後も拡張が見込まれる。

```
SessionStart    → claude-pane-state.sh idle + hitl-metrics hook session-start + hitl-metrics hook todo-cleanup
UserPromptSubmit → claude-pane-state.sh running
Notification (permission_prompt) → claude-notify.sh + claude-pane-state.sh permission
Notification (elicitation_dialog) → claude-notify.sh + claude-pane-state.sh ask
PreToolUse (Bash) → redirect-to-tools.py + approve-safe-commands.py
PreToolUse (全ツール) → approve-safe-file-ops.py（matcher なし、内部で Read/Write/Edit/NotebookEdit のみ承認）
PostToolUse → claude-pane-state.sh running post
Stop → claude-pane-state.sh idle + hitl-metrics hook stop
SessionEnd → claude-pane-state.sh end + hitl-metrics hook session-end
```

hitl-metrics（外部 CLI ツール）が SessionStart / SessionEnd / Stop の観測フックを `hitl-metrics hook <subcommand>` 形式で提供しており、`hitl-metrics install` コマンドで settings.json に自動登録される。本 ADR は `configs/claude/scripts/` 配下のコア系フック（pane-state, notify, security gate）を対象とする。

具体的な問題は以下の通り：

1. **settings.json の肥大化**: フック追加のたびに settings.json を直接編集する必要がある
2. **「なぜあるか」の喪失**: スクリプト名・コマンド文字列だけでは変更理由が追跡できない
3. **スケーラビリティの欠如**: 新しいセキュリティルールや状態追跡を追加するたびに settings.json の行数が増える

なお、当初課題に挙げていた `approve-safe-file-ops.py` の Read/Write/Edit/NotebookEdit 4 エントリ重複登録は、案D として先行実施済み（commit `b9c0a82`）。matcher なしの 1 エントリに統合し、スクリプト内部でツール名チェックする方式へ移行した。

## 設計案

### 案A: ディレクトリベースディスパッチャ（候補）

`~/.claude/hooks/<event>/` ディレクトリにスクリプトを配置し、settings.json はディスパッチャのみを登録する。

```
~/.claude/hooks/
  pre-tool-use/
    bash/
      00-redirect-to-tools.py
      10-approve-safe-commands.py
    file-ops/          # Read/Write/Edit/NotebookEdit を統合
      00-approve-safe-file-ops.py
  session-start/
    00-pane-state-idle.sh
  ...
```

settings.json には各イベントに対して1エントリのみ登録し、ディスパッチャがディレクトリ内スクリプトを連番順に実行する。

**メリット**:
- 新フック追加 = ファイルを置くだけ。settings.json 変更不要
- 追加・削除・順序変更がファイル操作で完結する
- hitl-metrics 等の外部 CLI hook（`hitl-metrics install` 管理下）との境界が明確

**デメリット**:
- ディスパッチャスクリプト自体の実装が必要
- セキュリティフック（redirect-to-tools.py）の失敗モードが増える。ディスパッチャが terminate/block を正しく伝播しないと安全機構が無効化されるリスクがある
- hitl-metrics 等「外部 CLI が自動登録するフック」は `hitl-metrics install` が settings.json を直接編集する経路で入るため、ディスパッチャ方式と二重管理になり完全な統一はできない

### 案B: 責務グループ統合（候補）

現在の細粒度スクリプトを 3〜4 のドメイン別スクリプトに集約する。

```
configs/claude/scripts/
  pane-state.sh          # 全状態管理（idle/running/permission/ask/end）（現状とほぼ同じ）
  security-gate.py       # redirect-to-tools + approve-safe-commands + approve-safe-file-ops
  notify.sh              # 通知系（現状とほぼ同じ）
```

**メリット**: ファイル数が減り、スクリプト間の依存が減る
**デメリット**: スクリプト内に条件分岐が増える。settings.json の行数は減らない。個別テストが難しくなる

### 案C: ドキュメント化のみ（却下候補）

構造は変えず、`docs/reference.md` または `~/.claude/hooks-map.md` に「イベント → スクリプト → 目的」のマップを維持する。

**メリット**: ゼロリスク。既存コード変更なし
**デメリット**: 根本問題（settings.json 肥大化・重複エントリ・スケーラビリティ欠如）を解決しない。マニフェストが陳腐化する

### 案E: 外部 CLI hook の dotfiles 一元管理（直交制約・候補）

hitl-metrics 等の外部 CLI が `install` で settings.json を直接編集する経路を廃止し、hook 登録は dotfiles の責務に寄せる。外部 CLI 側は `doctor` で「期待する hook エントリが settings.json に登録されているか」のみを検証する。

**前提**:
- 外部 CLI 側が `install --no-hooks` モードを提供するか、`install` の hook 登録機能自体を削除する
- 期待される hook エントリ（subcommand 名・引数）の仕様を外部 CLI と dotfiles で合意する

**メリット**:
- settings.json の hook 登録経路が dotfiles 一本に統一される（ADR-041 の managed keys sync と整合）
- 案A・案B のディスパッチャ／責務統合がそのまま外部 CLI hook にも適用できる
- 二重登録（dotfiles + 外部 CLI install）の事故が構造的に発生しない

**デメリット**:
- 外部 CLI の hook 契約（subcommand 名・引数）が変更されたとき dotfiles 側で追従が必要
- `doctor` は警告のみで自動修復しないため、期待する hook が抜けていても CLI 実行時までは検出できない（ADR-039 の hook 存在チェックと同様の思想）

**位置づけ**: 案A・案B のいずれを選択しても直交して適用できる制約。本 ADR で採用すれば「案A」のデメリット 3 番目（外部 CLI が settings.json を直接編集する経路で二重管理になる）が解消され、ディスパッチャ方式・責務統合方式のどちらでも `configs/claude/scripts/` 以下に統一できる。

### 案D: 即効改善（実施済み）

設計方向に関わらず先行実施できる改善として、以下を完了済み：

1. **`approve-safe-file-ops.py` の重複解消**（commit `b9c0a82`）: Read/Write/Edit/NotebookEdit の 4 エントリを `matcher` なしの 1 エントリに統合し、スクリプト内部でツール名チェックする方式へ移行
2. **ファイル配置の統一**: dotfiles 管理対象は `configs/claude/scripts/` に一本化（hitl-metrics 等の外部 CLI が登録するフックは `hitl-metrics install` 管理下で別経路。案E 採用時は dotfiles 一元管理に変わる）

案D は案A・案Bのいずれを選択しても干渉しない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 | 状態 |
|---|---|---|---|
| `configs/claude/settings.json` | dotfiles | Read/Write/Edit/NotebookEdit の 4 エントリを 1 エントリに統合 | 実施済み（`b9c0a82`） |
| `configs/claude/scripts/approve-safe-file-ops.py` | dotfiles | 内部でツール名チェックを追加（全 PreToolUse に対応） | 実施済み（`b9c0a82`） |

案A・案B・案E の変更内容は設計確定後に追記する。

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-042 セクション）
