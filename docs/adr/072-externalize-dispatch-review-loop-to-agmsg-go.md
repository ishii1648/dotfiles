# ADR-072: dispatch / review-loop の配布を agmsg-go へ外部化する

## ステータス
Superseded by [ADR-076](076-herdr-migration-from-tmux.md)（dotfiles からの dispatch / review-loop 自動配布を廃止）

## 関連 ADR
- 関連: ADR-059（dispatch / orchestrate の連携モード分離 — dispatch は本 ADR で配布元が変わるが、連携モードの位置づけは不変）
- 関連: ADR-071（元セッション主導の review-loop。本 ADR でシグナリング機構を marker ファイル → agmsg IPC に変更し、配布元を agmsg-go に移す）
- 関連: ADR-060（orchestrate のエージェントチェーン — orchestrate は dotfiles に残し、本 ADR の対象外）

## コンテキスト

`dispatch` / `review-loop` の 2 skill は dotfiles の `configs/claude/skills/` に vendor され、`setup.sh` が per-skill の symlink（`~/.claude/skills/<name>` → dotfiles 実体）として展開していた。ソース・オブ・トゥルースは dotfiles リポジトリにあり、改変は dotfiles 編集で即時反映できた。

一方、これら 2 skill を **Go 実装の IPC コア（`agmsg` binary、共有 SQLite を通信路とする daemon/network レスのエージェント間 IPC）と同梱して 1 binary から配る**プロジェクト [agmsg-go](https://github.com/ishii1648/agmsg-go) が立ち上がり、`v0.0.1` がリリースされた。agmsg-go は skill を binary に `go:embed` し、`agmsg skills install` で `~/.claude/skills` へ展開する。

agmsg-go 同梱版は単なる再パッケージではなく、**シグナリング機構をアップグレードした新バージョン**である:

| skill | dotfiles 現行 | agmsg-go `v0.0.1` 同梱 |
|---|---|---|
| review-loop | v1.0.0 — reviewer↔implementer のシグナリングをレビュー結果ファイル（`round-N-review.md` の `REVIEW_RESULT` 行）のポーリングで検知 | v2.0.0 — シグナリングを **agmsg IPC（`agmsg send` / `agmsg inbox`）** で実施。`notify-verdict` サブコマンド追加、team 概念導入。`agmsg` を**必須**とする |
| dispatch | v1.1.0 — 素の tmux 起動 | v1.2.0 — 起動 agent を agmsg team に **auto-join**（親 session から `agmsg send` で到達可能に）。`agmsg` が無ければ join を skip して従来動作 |

この状況で「dotfiles で vendor し続ける」と、agmsg-go 側の skill 進化（IPC 機構・team・auto-join）と二重メンテになり、どちらが正かが曖昧になる。

## 設計案

### 案A: 配布を agmsg-go に外部化し、dotfiles の vendor を廃止する（採用）

`dispatch` / `review-loop` のソース・オブ・トゥルースを agmsg-go に移し、dotfiles は配布元から外す。

- **binary は `go install ...@v0.0.1` で pin 導入**する。agmsg-go は開発中（🚧）であり、`@latest` は破壊的変更の影響を直接受けるため、再現性を優先してタグ pin とする。更新は意図的な版 bump で行う。
- **skill は `agmsg skills install --force` で `~/.claude/skills` に実ファイル展開**する。既存の dotfiles symlink は事前に除去する（`agmsg skills install` は既定で既存ファイルを skip し、symlink を残すと dotfiles リポジトリに書き込む事故になるため）。
- **dotfiles の vendor（`configs/claude/skills/{dispatch,review-loop}`）を削除**する。`orchestrate` / `session-log` は agmsg-go に含まれないため dotfiles に残す。
- **`setup.sh` で bootstrap を自動化**する: `agmsg` が PATH に無ければ `go install ...@v0.0.1` を実行し、続けて `agmsg skills install --force` を呼ぶ。さらに `~/.claude/skills/{dispatch,review-loop}` が dotfiles を指す stale symlink なら除去してから install する（冪等）。これにより dotfiles の一括 setup で skill が揃う一貫性を保つ。
- **新規ハード依存（`agmsg` binary）を受け入れる**。review-loop v2 は `agmsg` 無しでは動かない（`die`）。dispatch v1.2 は soft 依存（無ければ従来どおり）。
- **runtime config は不変**。dispatch の `~/.config/dispatch/no-worktree-repos` は両版とも同じパスを読むため、`configs/dispatch/no-worktree-repos.example`（雛形）は据え置く。
- **DB の置き場所は既定（`~/.agents/skills/agmsg`）**を使う。`AGMSG_HOME` は設定時のみ skill が起動先へ伝播する。当面は既定のままとし、シェル rc への export は行わない。

トレードオフ:
- 得るもの: 配布の一元化、IPC ベースの確実なシグナリング（marker ポーリングの取りこぼし回避）、複数 CLI からの共有。
- 失うもの: dotfiles git による即時改変・ピン留めの単純さ。今後 skill を直す場合は agmsg-go 側 PR に移る。`v0.0.1` pin と setup.sh bootstrap でリスクは許容範囲と判断。

### 案B: dotfiles で vendor を継続し、agmsg-go 版を都度同期する（却下）

agmsg-go の skill 更新を dotfiles に手動コピーで取り込み、vendor + symlink 方式を維持する。

**却下理由**: 二重メンテが恒常化し、どちらが正かが曖昧になる。IPC 機構の進化（team / auto-join / notify-verdict）を取り込むたびに手動同期が必要で、外部化の利点を打ち消す。

### 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/claude/skills/dispatch/` | 削除（agmsg-go に外部化） |
| `configs/claude/skills/review-loop/` | 削除（agmsg-go に外部化） |
| `configs/claude/setup.sh` | skill symlink ループから 2 skill が自然に外れる。agmsg bootstrap ブロック（未導入なら `go install ...@v0.0.1` → `agmsg skills install --force`）と stale symlink 除去を追加 |
| `docs/reference.md` | skills の出所を `configs/claude/skills/` → agmsg-go（`agmsg skills install`）に更新。review-loop の機構を agmsg IPC に注記 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-072 セクション）
