# ADR-041: settings.json の dotfiles 管理キーを setup.sh で自動同期する

## ステータス
採用済み

## 関連 ADR
- 依存: ADR-027（copy + validate 方式を前提）
- 関連: ADR-015（jq マージ方式 — ADR-027 で廃止済み）
- 関連: ADR-052（claudedog 移動で hooks パスが変更された契機）

## コンテキスト

`~/.claude/settings.json` は ADR-027 で `copies: if_missing: true` による初回配布 + validate 方式に移行した。しかし、`configs/claude/settings.json` の dotfiles 管理キー（`hooks`, `statusLine`）を変更しても、既に `~/.claude/settings.json` が存在する環境には変更が伝播しない。

ADR-052 で hook パスを `~/.claude/scripts/` → `~/.claude/claudedog/hooks/` に変更した際にこの問題が顕在化した。validate は WARN を出すが自動修正しないため、ユーザーが手動で dest を編集するか、dest を削除して再コピーする必要がある。

settings.json のキーは2種類に分類できる。

| 種類 | キー | 管理元 |
|---|---|---|
| dotfiles 管理 | `hooks`, `statusLine` | `configs/claude/settings.json`（git 管理、常にソースが正） |
| ローカル固有 | `env`, `language`, `effortLevel`, `attribution` | 端末ごとに異なる可能性がある |

ADR-015 で廃止された jq マージは「settings.json 全体の base + overlay マージ」であり、本 ADR の「特定キーのみソースから同期」とはスコープが異なる。

## 設計案

### 案A: setup.sh で特定キーのみ jq 同期（採用）

`configs/claude/setup.sh` に同期処理を追加する。対象キーをスクリプト内にハードコードし、非 dry-run 時にソースからデストへ上書きする。

```bash
# dotfiles 管理キーをソースから同期
SYNC_KEYS=("hooks" "statusLine")
src="configs/claude/settings.json"
dest="$HOME/.claude/settings.json"

if [[ -f "$dest" ]]; then
    tmp=$(mktemp)
    cp "$dest" "$tmp"
    for key in "${SYNC_KEYS[@]}"; do
        jq -s --arg k "$key" '.[0][$k] as $v | .[1] | .[$k] = $v' "$src" "$tmp" > "$tmp.new" && mv "$tmp.new" "$tmp"
    done
    mv "$tmp" "$dest"
fi
```

dry-run 時は差分を検出して WARN を出す（既存の validate と統合）。

- 良い点: 実装がシンプル（5-10 行追加）。マニフェスト構文の変更不要
- 懸念: 同期対象キーがハードコード → 対象は `hooks` と `statusLine` の2つのみで増加の見込みが薄いため許容

### 案B: マニフェストに sync_keys を追加（却下）

```yaml
copies:
  - src: configs/claude/settings.json
    dest: ~/.claude/settings.json
    if_missing: true
    sync_keys: [hooks, statusLine]
```

却下理由: たった2キーのためにマニフェスト構文を拡張し、`process_copy` と `validate_json` を改修するのはオーバーエンジニアリング。

### 案C: validate フェーズでパッチ（却下）

validate_json を拡張し、差分検出時に非 dry-run なら自動修正する。

却下理由: validate は「チェック」の責務であり「変更」を兼ねると責務が肥大する。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/setup.sh` | dotfiles | dotfiles 管理キーの同期処理を追加 |
| `scripts/lib/validate.sh` | dotfiles | hooks スクリプト存在チェックの対象パスに `~/.claude/claudedog/` を追加 |

## 受け入れ条件
> [issues.md](../issues.md)（ADR-041 セクション）
