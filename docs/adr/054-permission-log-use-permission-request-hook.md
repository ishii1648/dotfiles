# ADR-054: permission-log を PermissionRequest フックに移行する

## ステータス

採用済み

## 関連 ADR

- 依存: ADR-036（permission UI 計測の基盤）
- 依存: ADR-043（permission UI 内訳の監視 — pretooluse-track.sh + permission-log.sh の設計）

## コンテキスト

ADR-036 で採用した `Notification (permission_prompt)` フックによる permission UI 計測が不安定であることが判明した。

### 発見された問題

1. **発火が不安定**: 同じ `cp ... /tmp/...`（プロジェクト外パス）でも、`permission_prompt` Notification が発火するケースとしないケースがある
2. **一部の permission UI を捕捉できない**: `mkdir -p <project-internal-path>` で permission UI が表示されても `permission_prompt` Notification が発火しない
3. **GitHub Issues でも報告あり**: Notification フックの遅延・未発火が複数報告されている

### 原因の仮説

`Notification` イベントは「通知を送る」ための汎用イベントであり、permission UI の発生を確実に捕捉する用途には設計されていない。一方、Claude Code には `PermissionRequest` という専用フックイベントが存在する。

| Event | When it fires |
|---|---|
| `Notification` (permission_prompt) | Claude Code が通知を送信するとき（発火が不安定） |
| `PermissionRequest` | permission dialog が表示されるとき |

## 設計案

### 案A: permission-log.sh を PermissionRequest フックに移行する（採用・検証済み）

`settings.json` の `Notification (permission_prompt)` から `permission-log.sh` を外し、`PermissionRequest` フックとして登録する。

### Spike 検証結果

| 検証項目 | Notification (旧) | PermissionRequest (新) |
|---|---|---|
| `cp ... /tmp/...`（external） | 不安定（記録されたりされなかったり） | 安定して記録 ✅ |
| `mkdir -p /tmp/...`（external） | 記録されなかった | 安定して記録 ✅ |
| 複数回実行の安定性 | × | ✅（4/4 回記録） |
| tool_name 直接取得 | ×（pretooluse-track.sh の一時ファイル経由） | ✅（入力 JSON に `tool_name`・`tool_input` が含まれる） |

### 追加の知見

1. **pretooluse-track.sh の一時ファイルが不要になる**: `PermissionRequest` の入力 JSON には `tool_name` と `tool_input` が直接含まれるため、`pretooluse-track.sh` → 一時ファイル → `permission-log.sh` の間接的な連携が不要。`permission-log.sh` 単体で tool_name の判定・記録が完結する
2. **pretooluse-track.sh の Bash パス判定バグ**: `awk '{print $2}'`（第2ワード）でパスを取得していたため、`cp src dest` では source を、`mkdir -p path` ではフラグ `-p` をパスとして誤判定していた。`awk '{print $NF}'`（最終ワード）に修正済み
3. **`Bash(cp *)` 等の allow リストはプロジェクト内スコープ**: グローバル settings.json の `Bash(cp *)` はプロジェクト内のみ許可。プロジェクト外パスでは permission UI が表示される
4. **`permission-log.sh` スクリプトのデプロイ漏れ**: 当初 `~/.claude/scripts/` にスクリプトが存在せず、フックがサイレントに失敗していた。`~/.claude/claudedog/hooks/` に配置して解消

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/settings.json` | dotfiles | Notification から permission-log.sh を削除し、PermissionRequest フックに登録 |
| `claudedog/hooks/permission-log.sh` | dotfiles | PermissionRequest の入力 JSON から tool_name・tool_input を直接読むよう変更（一時ファイル依存を廃止） |
| `claudedog/hooks/pretooluse-track.sh` | dotfiles | Bash パス判定を `awk '{print $2}'` → `awk '{print $NF}'` に修正（permission-log.sh では不要になったが、他の用途で残す） |

## 受け入れ条件

-> [issues.md](../issues.md)（ADR-054 セクション）
