# ADR-067: Claude Code skill を Codex CLI へ動的に同期する codex-sync skill を追加する

## ステータス
採用済み

## 関連 ADR
- 関連: ADR-066（dotfiles 管理 skill の Codex への symlink 配布 — 静的配布）
- 関連: ADR-018（unified setup command — 宣言的配布の出発点）

## コンテキスト

ADR-066 により dotfiles で管理する skill 3 件（dispatch / orchestrate / session-log）は `setup-manifest.yml` 経由で `~/.codex/skills/<name>` に静的に symlink される。一方、`~/.claude/skills/` 配下にはユーザーが個別に追加する skill（プラグイン経由含む）も存在し得るため、dotfiles の理想状態に含まれない skill は Codex 側に伝播しない。

ariccb/sync-claude-skills-to-codex のような公開ツールは `~/.claude/skills/` 配下を一括で `~/.codex/skills/` に symlink する設計になっており、dotfiles 外の skill にも対応できる。本リポジトリの流儀に合わせて Claude Code skill として再実装し、ユーザーが `/codex-sync` で任意のタイミングで同期を実行できるようにする。

## 設計案

### 案A: Claude Code skill `codex-sync` を新設し、内部で同期スクリプトを呼ぶ（採用）

`configs/claude/skills/codex-sync/` を作成し、以下 2 ファイルを置く：

- `SKILL.md` — Skill 定義（name, description, allowed-tools, argument-hint）
- `codex-sync.sh` — `~/.claude/skills/<name>` を列挙して `~/.codex/skills/<name>` にディレクトリ symlink を張る本体

`setup-manifest.yml` の `claude.symlinks` に `~/.claude/skills/codex-sync` のエントリを追加することで、setup.sh 経由で Claude Code に登録される。

スクリプトの動作仕様：

| ケース | 出力 | 終了コード貢献 |
|---|---|---|
| `~/.codex/skills/<name>` 不在 → 作成 | `CREATED` | 0 |
| 既存 symlink が同じ先 | `OK` | 0 |
| 既存 symlink が別の先 | `CONFLICT` | exit 2 |
| 通常ファイル/ディレクトリが既存 | `CONFLICT` | exit 2 |
| `<name>` が broken symlink・非ディレクトリ | `SKIP` | 0 |
| `SKILL.md`（大文字）不在 | `WARN` で続行 | 0 |
| 隠しディレクトリ（`.system` 等） | 暗黙 skip | 0 |

冪等性：何度実行しても結果は同じ。差分（新規追加分）のみが `CREATED` で表示される。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/skills/codex-sync/SKILL.md` | dotfiles | 新規 |
| `configs/claude/skills/codex-sync/codex-sync.sh` | dotfiles | 新規（実行ビット必須） |
| `scripts/setup-manifest.yml` | dotfiles | `claude.symlinks` に `~/.claude/skills/codex-sync` を追加 |
| `docs/issues.md` | dotfiles | 受け入れ条件の追記 |

### 案B: ariccb/sync-claude-skills-to-codex を直接 git submodule で取り込む（却下）

`~/.claude/skills/sync-claude-skills-to-codex` として外部リポジトリを submodule 配置し、そこに含まれる Python/Bash スクリプトを呼ぶ案。

却下理由：

- dotfiles の他 skill は単一リポジトリ内で完結しており、外部依存を増やしたくない
- ariccb 版は Python 実装で、dotfiles 全体の Bash 統一スタイルから外れる
- 必要な機能（数十行の Bash ループ）を自前で書くコストが低く、submodule 更新追従コストの方が高い
- ライセンス・配布形態の違いがメンテナンス時の注意事項を増やす

### 案C: Claude Code skill ではなく setup.sh の symlink ステップに統合（却下）

`scripts/lib/symlink.sh` を拡張し、`~/.claude/skills/*/` を読んで `~/.codex/skills/` に伝播するロジックを setup.sh 実行時に動かす案。

却下理由：

- ADR-018 の宣言的 manifest 思想と矛盾する（manifest にないものを動的に配布する暗黙ロジックが setup.sh に混入）
- setup.sh は dotfiles の理想状態を作るためのもので、ユーザー個別 skill の伝播は別レイヤーの責務
- 「いつ・どの skill を同期するか」をユーザーがコントロールできなくなる（インストール直後に意図せず全部同期される）
- 同期実行を `/codex-sync` という skill 呼び出しに分けることで、`/dispatch` や `/orchestrate` と同じ運用感に揃う

### 案D: dotfiles 管理 3 件と同様に manifest にすべての個人 skill を列挙（却下）

ADR-066 の延長で、すべての skill エントリを `setup-manifest.yml` に静的列挙する案。

却下理由：

- 個人 skill が増減するたび manifest 編集が必要になり、dotfiles 外の変更で manifest を触る運用は非現実的
- プラグイン経由 skill は manifest 化できない（プラグインバージョンで変動するため）
- 「dotfiles 管理 skill は静的 manifest、それ以外は codex-sync で動的同期」と責務分離した方が明快

## skill.md / SKILL.md の case 問題に対する判断

ADR-066 で「Codex は `SKILL.md`（大文字）のみを認識する」ことが判明済み。codex-sync.sh は `SKILL.md` 不在時に `WARN` を出すが、自動リネームはしない。理由：

- リネームは dotfiles 外の skill（プラグインなど）にも影響を与える可能性があり破壊的
- ファイル名は skill 作者の責務であり、sync ツールが勝手に変更するのは越権
- 警告に止めることで利用者が認識して修正できる

## 結果

- `/codex-sync` で `~/.claude/skills/` 全体を `~/.codex/skills/` へ同期できる
- `codex debug prompt-input` の `<skills_instructions>` に `codex-sync` 自身を含む 5 件（imagegen, dispatch, orchestrate, session-log, codex-sync）が登録されることを実機確認済み
- broken symlink (`spawn` 等) は SKIP され、エラーにならない

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-067 セクション）
