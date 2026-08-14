# ADR-092: settings.json の permissions を配布せずベースライン検査に変える

## ステータス
採用済み

## 関連 ADR
- 依存: ADR-091（`permissions` を `MERGE_KEYS` に追加）— 本 ADR で該当部分を変更する
- 関連: ADR-041（settings.json の管理キー同期）— 同期方式の基盤
- 関連: ADR-015（settings.json を共通・端末固有に分離）— 端末固有部分の扱いを引き継ぐ
- 関連: ADR-034（テスト追加基準）— 回帰テストの追加根拠

## コンテキスト

ADR-091 の「3. `permissions` を settings.json の同期対象に追加」を変更する。

ADR-091 は `MERGE_KEYS` に `permissions` を追加し、「`allow` / `deny` / `defaultMode` は dotfiles を正としつつ、配布先固有のキーは保持する」と記した。しかし実装に使っている jq の `*` は object を再帰マージする一方で、**配列に当たると右辺で丸ごと置換する**。

```
{"A":1,"B":2} * {"A":9}        → {"A":9,"B":2}      object は再帰マージ
{"A":[1,2,3]} * {"A":[9]}      → {"A":[9]}          配列は置換
```

`permissions.allow` / `deny` は配列のため、setup.sh を実行するたびに配布先のエントリが dotfiles の内容で全置換される。

### 実測

2026-08-14、ADR-091 の hook 削除を配布先へ反映するため setup.sh を実行して顕在化した。`hooks` の同期（`SYNC_KEYS` による全置換）は意図どおり働き、削除済みスクリプトを指す PreToolUse エントリ 2 件が消えた。壊れたのは `permissions` だけである。

| キー | 値の型 | 実行前 | 実行直後 | 帰結 |
|---|---|---:|---:|---|
| `permissions.allow` | 配列 | 47 | 19 | 47 件が消失 |
| `permissions.deny` | 配列 | 46 | 4 | 45 件が消失 |
| `permissions.ask` | 配列（dotfiles 側に無い） | 7 | 7 | 保持 |
| `permissions.additionalDirectories` | 配列（dotfiles 側に無い） | 1 | 1 | 保持 |
| `permissions.defaultMode` | スカラー | `acceptEdits` | `auto` | 上書き |
| `env` | object | 11 | 11 | 保持 |

消えた deny には `Bash(sudo *)` / `Bash(kubectl *)` / `Read(~/.aws/credentials)` / `Read(**/.env*)` / `mcp__claude-in-chrome__*` / `Artifact` が含まれる。`ask` と `additionalDirectories` が無傷だったのは dotfiles 側に同名キーが無かったためで、追加された時点で同じ事故が起きる。

問題の性質は 3 つある。

- **失敗が静かに起きる** — setup.sh の出力は `managed-keys sync: updated` の 1 行だけで、消えた件数を報告しない
- **消えるのが防御側である** — allow が消えれば prompt が増えて気づけるが、deny が消えても普段は何も起きない。気づくのは実際に叩かれた時
- **端末差が常態である** — 本番トークンを持つ端末は `defaultMode` を `acceptEdits` にし、MCP の allow も端末ごとに育つ。「dotfiles を正とする」前提そのものが実態に合っていない

### permission 記法の前提

公式ドキュメントに「The `:*` suffix is an equivalent way to write a trailing wildcard, so `Bash(ls:*)` matches the same commands as `Bash(ls *)`」とあり、2 つの書式は等価である。permission ダイアログで「Yes, don't ask again」を選ぶと空白区切りの形が書き込まれるため、配布先には両方が混在する。照合を単純な文字列一致で行うと、等価な別表記を欠落と誤判定する。

あわせて、ルールの評価順は deny → ask → allow であり、broad な deny は narrower な allow を上書きする。deny のベースラインを配る以上、端末側の allow を壊しうる点は設計上の前提になる。

## 設計案

### 案A: 配列を和集合でマージする（却下）

`MERGE_KEYS` の配列を `dest + src | unique` にする。dotfiles の値は必ず入り、配布先の資産も消えない。

却下理由。和集合は追加しか伝播しない。dotfiles から削除したエントリが配布先に残り続け、二度と消せなくなる。ADR-091 のように「approve 系をやめて deny を整理する」方向の変更が伝わらず、`permissions` が足すだけのゴミ箱になる。`hooks` の全置換が ADR-091 の意図を正しく運んだのとは対照的である。

### 案B: permissions を dotfiles で一切管理しない（却下）

`MERGE_KEYS` から `permissions` を外して終わりにする。破壊は止まる。

却下理由。ADR-091 が approve 系 hook を廃止する代償として置いた「read-only な git サブコマンドの allow」が配布されなくなる。それ以上に、`Bash(sudo *)` や認証情報の Read 禁止のような**端末の役割によらず必要なガード**が、入っているかどうか誰も確認しない状態になる。今回の事故で消えたのがまさにこの層である。

### 案C: ベースラインを定義し、setup.sh は検査のみ行う（採用）

dotfiles を「配布物」ではなく「検査基準」として使う。

**1. ベースラインを別ファイルに分離する**

`configs/claude/permissions-baseline.json` を新設し、`configs/claude/settings.json` からは `permissions` を削除する。同じファイルに置くと「dotfiles の settings.json は配布物なのか基準なのか」が曖昧になるため、意味の違うものはファイルで分ける。

- **`required.deny`** — 端末の役割によらず必ず入っているべきガード。`rm -rf` 系、`sudo`、shell 迂回（`bash -c` / `sh` / `source`）、環境変数ダンプ（`env` / `printenv`）、ネットワーク経由の取得と持ち出し（`curl` / `wget` / `nc`）、GitHub の不可逆操作と秘匿情報（`gh auth` / `gh secret` / `gh repo delete` 等）、認証情報の Read
- **`recommended.allow`** — 入っていなくても害はなく、permission prompt が増えるだけのもの。ADR-091 が移した read-only な git サブコマンドがこれにあたる
- **端末固有として除外** — `kubectl` / `helm` / `terraform apply` / `aws` / `gcloud`（クラウド運用端末のみ）、`brew install`（macOS のみ）、`Artifact` / `mcp__claude-in-chrome__*`（その端末のツール禁止ポリシー）、`defaultMode`（端末のリスクプロファイルで決まる）

**2. setup.sh は書き換えず指摘する**

`MERGE_KEYS` から `permissions` を外し、代わりにベースライン検査を追加する。required の欠落は件数と一覧で報告し、recommended の欠落は「prompt が増えるだけで害はない」と添えた note にとどめる。重みを分けるのは、直す必要のない指摘が本当に危ない指摘を埋もれさせないためである。

照合前に `Bash(` / `PowerShell(` で始まるルールの末尾 `:*` を ` *` へ寄せて正規化する。中間のコロンは Claude Code がリテラル文字として扱うため、末尾に限定する。

**3. `--fix` は追加のみ行う**

チェックだけでは、実害の見えない deny の欠落ほど放置される。`--fix` を用意し、配布先に無いエントリの追加だけを行う。削除・置換は一切しない。冪等であり、`ask` / `additionalDirectories` / `defaultMode` を含む配布先固有の値には触れない。

**4. `MERGE_KEYS` の制約をコメントに残す**

`MERGE_KEYS` に値が配列のキーを入れてはならないという制約は、jq の `*` の挙動を知らないと読み取れない。同じ事故を繰り返さないよう、理由をコードのコメントに書く。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/permissions-baseline.json` | dotfiles | 新規。`required.deny` と `recommended.allow` を定義 |
| `configs/claude/settings.json` | dotfiles | `permissions` キーを削除 |
| `configs/claude/setup.sh` | dotfiles | `MERGE_KEYS` から `permissions` を外し、ベースライン検査と `--fix` を追加。`CLAUDE_SETTINGS_DEST` でテストから配布先を差し替え可能にする |
| `tests/claude-permissions-baseline.bats` | dotfiles | 新規。正規化・非破壊・冪等性の回帰テスト |
| `docs/adr/091-remove-approve-hooks-and-prune-redirect-rules.md` | dotfiles | ステータスを部分廃止に更新 |
| `docs/reference.md` | dotfiles | `configs/claude/` の構成にベースライン定義を追記 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-092 セクション）
