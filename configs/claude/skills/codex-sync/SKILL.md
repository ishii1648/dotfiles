---
name: codex-sync
description: >-
  This skill should be used when the user wants to make Claude Code skills available to Codex CLI,
  such as "/codex-sync", "claude skill を codex でも使えるようにして", "codex に skill 同期して",
  "codex 用に skill コピーして". Creates directory symlinks from ~/.claude/skills/<name> to ~/.codex/skills/<name>
  so the same skill bodies can be invoked from Codex CLI.
version: 0.1.0
allowed-tools: Bash
argument-hint: "[--dry-run]"
---

# codex-sync - Claude Code skill を Codex CLI へ同期

## 概要

`~/.claude/skills/` 配下の各 skill ディレクトリを `~/.codex/skills/<name>` にディレクトリ symlink で公開し、Codex CLI からも同じ skill body を呼び出せるようにする。

実装は `~/.claude/skills/codex-sync/codex-sync.sh` に委譲する。skill 本体での Bash 呼び出しは最大 1 回に抑える。

## ワークフロー

### Step 1: 引数チェック

| 引数 | 動作 |
|---|---|
| なし | 通常実行（symlink を作成） |
| `--dry-run` | 作成予定のみ表示（実際の symlink は作らない） |
| その他 | usage を表示して終了 |

### Step 2: 同期スクリプトの実行

**Bash ツール**で次を 1 回だけ実行する：

```
~/.claude/skills/codex-sync/codex-sync.sh [--dry-run]
```

スクリプトは各 skill ごとに以下のいずれかを 1 行で出力する：

| ステータス | 意味 |
|---|---|
| `CREATED` | 新規 symlink を作成した |
| `OK` | 既に正しい symlink が存在（冪等） |
| `SKIP` | broken symlink・自分自身（codex-sync）等で除外 |
| `WARN` | `SKILL.md`（大文字）が無く Codex で認識されない可能性 |
| `CONFLICT` | 既存ファイルが別の先を指す or 通常ファイル。手動対応必要 |

### Step 3: 結果の要約

スクリプトの最終行 `Summary: N created, M existed, K conflicts, W warns, S skipped` をユーザーに伝える。

`CONFLICT` が 1 件以上ある場合、スクリプトは exit 2 で終了する。その場合は競合内容（`existing symlink -> ...` 行）をそのまま提示し、ユーザーに手動解消を促す。

## 注意事項

- **Codex の `SKILL.md` 大文字要件**: codex のスキャナはディレクトリ走査時の元ファイル名を case-sensitive 比較する。`skill.md`（小文字）の skill は macOS APFS の case-insensitivity に依存して見えるケースもあるが、Linux では認識されない。本 skill は `SKILL.md` 不在時に `WARN` を出すだけで自動リネームはしない（破壊的変更を避けるため）
- **broken symlink の扱い**: `~/.claude/skills/<name>` が壊れた symlink の場合は SKIP。自動修復はしない
- **自分自身の扱い**: `codex-sync` も同期対象に含める（Codex 側からも `/codex-sync` を呼べるように）。再帰の問題は無い（symlink の張替えは冪等）
- **冪等性**: 何度実行しても結果は同じ。差分のみが `CREATED` で表示される
