# ADR-066: dotfiles 管理 skill を Codex CLI へ symlink 配布する

## ステータス
採用済み

## 関連 ADR
- 関連: ADR-018（unified setup command — manifest による宣言的配布）
- 関連: ADR-061（popup ランチャーの claude / codex モード）
- 関連: ADR-062（popup ランチャー codex モードの dispatch 化）
- 関連: ADR-063（tmux セッションリストへの codex pane state 表示）

## コンテキスト

Claude Code 用に dotfiles で管理している skill（`configs/claude/skills/dispatch`, `orchestrate`, `session-log`）は、ADR-061/062 によって popup ランチャーから Codex CLI を起動する経路が増えた後も Claude Code 専用のままになっている。

Codex CLI からは同等のスキルが利用できないため、`dispatch` のような「別リポで agent を起動して prompt を投入する」操作を Codex セッション内から実行する手段がない。

Codex CLI のスキル仕様（公式 docs）：

- skill は `<dir>/SKILL.md` を含むディレクトリ単位
- 検出パスの一つが `~/.codex/skills/`（公式 blog 例で確立、現行 codex CLI が認識）
- frontmatter は `name` / `description` のみ必須。Claude Code 特有フィールド（`allowed-tools`, `argument-hint`, `disable-model-invocation`）は未対応 → 無視されるが致命的でない
- 公式は `SKILL.md`（大文字）表記。本リポジトリは `skill.md`（小文字）で運用してきたが、実機検証で **codex のスキャナはディレクトリ走査時の元ファイル名を case-sensitive 比較しているため `skill.md` では認識されない**ことが判明（macOS APFS の case-insensitive 性能では `SKILL.md` 名でアクセス可能でも、`readdir(2)` は元の `skill.md` を返すため strict な文字列マッチに失敗する）

公開ツール（`ariccb/sync-claude-skills-to-codex` 等）は `~/.claude/skills/` 配下を一括 sync するため、グローバル `~/.claude/` 経由の間接配布になる。dotfiles の流儀（manifest 駆動・宣言的）に統合できないため不採用とする。

なお dotfiles の `linux` profile では codex 自体を導入しない（`scripts/setup-manifest.yml` の `profiles.linux` に codex 含まれず）。本 ADR の対象は macOS の `full` profile に限定される。

## 設計案

### 案A: setup-manifest.yml の codex コンポーネントに symlinks を直書き + skill ファイル名を `SKILL.md` に統一（採用）

`scripts/setup-manifest.yml` の `components.codex` に `symlinks` を追加し、配布対象 skill を1行ずつ列挙する：

```yaml
codex:
  setup: configs/codex/setup.sh
  symlinks:
    - link: ~/.codex/skills/dispatch
      target: configs/claude/skills/dispatch
    - link: ~/.codex/skills/orchestrate
      target: configs/claude/skills/orchestrate
    - link: ~/.codex/skills/session-log
      target: configs/claude/skills/session-log
```

加えて、`configs/claude/skills/<name>/skill.md` を `SKILL.md`（大文字）にリネームする。Claude Code はファイル名 `SKILL.md` を公式仕様として読み込むため regression なし。core.ignorecase=true 環境ではリネームが index に反映されないため、`git mv -f skill.md _tmp.md && git mv _tmp.md SKILL.md` の二段階で確実に index 更新する。

- 既存の `scripts/lib/symlink.sh` がそのまま使える（manifest 経由で `bash scripts/setup.sh` および `--dry-run` に統合される）
- ディレクトリ単位 symlink にすることで、各 skill 配下の補助スクリプト（`dispatch.sh` 等）も同時に Codex から参照可能
- skill 追加時は manifest に1エントリ足すだけで配布される（明示性の代償として手動更新が必要だが、配布対象は数件で頻度も低い）

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `scripts/setup-manifest.yml` | dotfiles | `components.codex` に `symlinks` セクションを追加 |
| `configs/claude/skills/dispatch/skill.md` | dotfiles | `SKILL.md` にリネーム |
| `configs/claude/skills/orchestrate/skill.md` | dotfiles | `SKILL.md` にリネーム |
| `configs/claude/skills/session-log/skill.md` | dotfiles | `SKILL.md` にリネーム |
| `docs/issues.md` | dotfiles | 受け入れ条件の追記 |

### 案B: ariccb/sync-claude-skills-to-codex 等の公開ツールを導入（却下）

`~/.claude/skills/` 配下を再帰的に列挙して `~/.codex/skills/` へ symlink するツールを `configs/codex/setup.sh` から呼ぶ案。

却下理由：

- dotfiles 管理外の skill（ユーザーの個人 skill, 例: `spawn`）まで配布対象になり、配布範囲が暗黙的になる
- グローバル `~/.claude/skills/` を経由した間接 symlink になり、dotfiles → グローバル → codex の二段リンクで参照解決が複雑化する
- ADR-027（copy + validate パターン）の思想（dotfiles の宣言から逸脱したファイルは検出する）と相性が悪い

### 案C: 配布対象 skill を `configs/codex/setup.sh` 内で動的に列挙して symlink（却下）

`configs/claude/skills/` 配下を `for` ループで列挙し `~/.codex/skills/` に symlink する案。

却下理由：

- 「Codex で利用可能な skill」と「Claude 用 skill」の集合が将来分岐する余地を奪う（例: Claude 専用の skill が増えた場合に除外できない）
- ループスクリプトを setup.sh 内に増やすより、manifest の表 1 行追加のほうが ADR-018 の宣言的管理に整合する
- `scripts/lib/symlink.sh` の既存検証ロジック（target 実在チェック等）をバイパスする実装になる

### skill.md / SKILL.md の case 問題に対する判断

当初は「macOS APFS が case-insensitive のため `skill.md` のままで動く」と想定していたが、`codex debug prompt-input` で実機検証したところ、`<skills_instructions>` の Available skills に dotfiles 製 skill が現れなかった。

詳細：

- ファイルシステム API の `open("SKILL.md")` は case-insensitive で成功する
- しかし `readdir(2)` が返すエントリ名は元の作成時の名前（`skill.md`）
- codex のスキャナは Rust 由来の strict な文字列比較で `"SKILL.md"` を探すため、`skill.md` はマッチ対象外
- 検証手順：dispatch のみ `git mv -f skill.md SKILL.md`（二段階）でリネーム → `codex debug prompt-input` で当該 skill が `### Available skills` に追加されることを確認

結論として `SKILL.md`（大文字）にリネームする。Claude Code 側は SKILL.md が公式仕様のため regression なし。Linux 環境（case-sensitive）でも将来的に整合する。

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-066 セクション）
