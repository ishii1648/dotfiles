# ADR-039: setup validate でフックスクリプトの存在チェックを追加する

## ステータス

採用済み

## 関連 ADR

- 依存: [ADR-027](027-config-copy-validate-pattern.md) — copy + validate 方式の基本設計
- 関連: [ADR-036](036-remove-obsolete-pr-url-hooks.md) — 廃止 hook の削除（本 ADR の問題の発端）

## コンテキスト

ADR-027 で採用した copy + validate 方式では、`configs/claude/settings.json` を `~/.claude/settings.json` に `if_missing: true` でコピーする。validate は `src` のトップレベルキーが `dest` に存在するかのみを確認するため、以下の状況を検出できない。

- `src`（dotfiles）でフック設定を削除しても、`dest`（`~/.claude/settings.json`）の古いエントリが残る
- 参照スクリプト（`~/.claude/scripts/session-index-post-tool.sh` 等）が削除されても、`dest` のフック設定は残る

この問題は ADR-044 で `session-index-post-tool.sh` を削除した際に顕在化した。`configs/claude/settings.json` から該当エントリは削除されたが、既存の `~/.claude/settings.json` は `if_missing: true` により上書きされず、スクリプトが存在しないフック設定が残り続けた。結果として `PostToolUse:Bash hook error` が毎回発生した。

### validate_json の現在の動作

```bash
keys=$(jq -r 'keys[]' "$src")
for key in $keys; do
    if ! jq -e --arg k "$key" 'has($k)' "$dest"; then
        WARN
    fi
done
```

チェック内容: `src` のトップレベルキーが `dest` に存在するか（一方向のみ）
未検出: `dest` に存在する余分なエントリ、参照ファイルの実在性

### なぜ hooks だけを特別扱いするか

`dest` が `src` より多くの設定を持つことは意図的に許容されている（`env.ANTHROPIC_BASE_URL`、`enabledPlugins` 等の端末固有設定）。そのため双方向チェックは不適切。一方 `hooks` の `command` エントリが参照するスクリプトが存在しないことは、どのような端末固有設定であっても誤りである。

## 設計案

### 案A: validate_json に hooks スクリプト存在チェックを追加（採用）

`validate.sh` の `validate_json` 関数に、`hooks` キーを特別処理するロジックを追加する。

**チェック内容**: `dest` の `hooks.*[].hooks[].command`（`type: command` のもの）が `~/.claude/scripts/` を参照する場合、そのスクリプトファイルが実在するか確認する。

**変更対象**:

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `scripts/lib/validate.sh` | dotfiles | `validate_json` に hooks スクリプト存在チェックを追加 |

次のようなチェックロジック（擬似コード）を追加する。

```bash
# dest の hooks 内の全コマンドを列挙（type: command のみ）
commands=$(jq -r '
  .hooks // {} | to_entries[] | .value[] | .hooks[] |
  select(.type == "command") | .command
' "$dest")

for cmd in $commands; do
  # 引数を除いたスクリプトパスを取得し ~ を展開
  script_path=$(echo "$cmd" | awk '{print $1}' | sed "s|~|$HOME|")
  if [[ "$script_path" == "$HOME/.claude/scripts/"* ]] && [[ ! -f "$script_path" ]]; then
    WARN: script not found: $cmd
  fi
done
```

### 案B: hooks キーを双方向チェック（却下）

`dest.hooks` が `src.hooks` と完全一致するか検証する。

却下理由: 端末固有リポの `settings.local.json` で hooks を追加するユースケースが将来発生した場合に対応できない。また `env`/`enabledPlugins` との一貫性がない（それらは追加を許容している）。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-039 セクション）
