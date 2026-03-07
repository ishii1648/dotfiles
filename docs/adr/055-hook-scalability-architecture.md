# ADR-055: Claude Code フック設計のスケーラビリティ改善

## ステータス
Draft

## 関連 ADR
- 関連: ADR-006（PreToolUse hook Bash 権限の基盤）
- 関連: ADR-008（redirect-to-tools の基盤）
- 関連: ADR-017（approve-safe-commands の基盤）
- 関連: ADR-045（approve-safe-file-ops の基盤）
- 関連: ADR-047（approve-safe-file-ops Read 対応）
- 関連: ADR-048（hook スクリプト存在チェック）
- 関連: ADR-052（claudedog hooks の分離。本 ADR は configs/claude/scripts/ 側が対象）

## コンテキスト

現在の `settings.json` には 15 個の hook エントリが存在し、今後も拡張が見込まれる。

```
SessionStart    → claude-pane-state.sh idle + session-index.sh（claudedog）
UserPromptSubmit → claude-pane-state.sh running
Notification (permission_prompt) → claude-notify.sh + claude-pane-state.sh permission + permission-log.sh（claudedog）
Notification (elicitation_dialog) → claude-notify.sh + claude-pane-state.sh ask
PreToolUse (全ツール) → pretooluse-track.sh（claudedog）
PreToolUse (Bash) → redirect-to-tools.py + approve-safe-commands.py
PreToolUse (Read/Write/Edit/NotebookEdit) → approve-safe-file-ops.py（4 エントリ）
PostToolUse → claude-pane-state.sh running post
Stop → claude-pane-state.sh idle
SessionEnd → claude-pane-state.sh end
```

ADR-052 で claudedog 関連フック（session-index.sh, permission-log.sh, pretooluse-track.sh）が `claudedog/hooks/` に移行済みまたは移行中であるため、本 ADR は `configs/claude/scripts/` 配下のコア系フックを対象とする。

具体的な問題は以下の通り：

1. **settings.json の肥大化**: フック追加のたびに settings.json を直接編集する必要がある
2. **重複エントリ**: `approve-safe-file-ops.py` が Read/Write/Edit/NotebookEdit の 4 エントリで重複登録されている
3. **「なぜあるか」の喪失**: スクリプト名・コマンド文字列だけでは変更理由が追跡できない
4. **スケーラビリティの欠如**: 新しいセキュリティルールや状態追跡を追加するたびに settings.json の行数が増える

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
- claudedog hooks（`claudedog/hooks/`）との境界が明確

**デメリット**:
- ディスパッチャスクリプト自体の実装が必要
- セキュリティフック（redirect-to-tools.py）の失敗モードが増える。ディスパッチャが terminate/block を正しく伝播しないと安全機構が無効化されるリスクがある
- claudedog 等「外部配置スクリプト」はどのみち settings.json 直接編集になり、完全な統一はできない

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

### 案D: 即効改善（独立実施可能）

設計方向に関わらず、今すぐ実施できる改善：

1. **`approve-safe-file-ops.py` の重複解消**: Read/Write/Edit/NotebookEdit の 4 エントリを、全 PreToolUse に対して内部でツール名チェックする 1 エントリに集約する
2. **ファイル配置の統一**: `configs/claude/scripts/` に一本化（ADR-052 完了後、claudedog hooks は `claudedog/hooks/` に）

案D は案A・案Bのいずれを選択しても先行して実施できる。

### 変更が必要なファイル（案Dのみ確定）

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/settings.json` | dotfiles | Read/Write/Edit/NotebookEdit の 4 エントリを 1 エントリに統合 |
| `configs/claude/scripts/approve-safe-file-ops.py` | dotfiles | 内部でツール名チェックを追加（全 PreToolUse に対応） |

案A・案B の変更内容は設計確定後に追記する。

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-055 セクション）
