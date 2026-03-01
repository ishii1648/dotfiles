# ADR-027: 設定ファイルの管理を copy + validate 方式に統一する

## ステータス

採用済み

## 関連 ADR

- 依存: ADR-018（setup-manifest.yml による宣言的管理を前提）
- 関連: ADR-015（settings.json の base+local マージ — 本 ADR で置換）
- 関連: ADR-020（ローカルオーバーライドの端末固有リポ統合 — .gitconfig.local に関する決定を本 ADR で変更）

## コンテキスト

dotfiles には「共通設定 + 端末固有設定」という構造を持つ設定ファイルが複数ある。

| ファイル | 現在の管理方式 | 問題 |
|---------|-------------|------|
| `settings.json` | base + overlay を jq マージ（ADR-015） | overlay を端末固有リポで管理する必要があり、マージロジックが複雑 |
| `.gitconfig` | リポルートに置いてあるだけで未配布 | setup.sh で管理されていない |

ADR-015 の jq マージ方式は正しく動作しているが、以下のメンテナンス上の課題がある。

- 端末固有リポに `settings.local.json` を維持する必要がある
- マージ結果の diff 判定ロジック（behind / ローカル編集）が複雑
- 設定を変更するたびに「どちらのファイルを編集すべきか」の判断が必要

`.gitconfig` も同様に「共通設定 + 端末固有設定」の構造を持つが、現在は管理外にあり、`[include] path = ~/.gitconfig.local` で分離する設計が入っているものの配布されていない。

## 設計案

### copy + validate 方式（採用）

共通設定を `copies: if_missing: true` で初回配布し、`validate` で共通設定の存在を継続的に検証する。端末固有設定はユーザーが直接編集する。

```
dotfiles/configs/git/gitconfig          (共通設定の定義)
      ↓ copies (if_missing: true)
~/.gitconfig                            (ユーザーが直接編集可能)
      ↑ validate (共通キーの存在チェック)
```

#### manifest の拡張

```yaml
components:
  git:
    copies:
      - src: configs/git/gitconfig
        dest: ~/.gitconfig
        if_missing: true
    validate:
      - type: gitconfig
        src: configs/git/gitconfig
        dest: ~/.gitconfig

  claude:
    setup: configs/claude/setup.sh
    symlinks:
      - link: ~/.claude/CLAUDE.md
        target: configs/claude/CLAUDE.md
      - link: ~/.claude/scripts
        target: configs/claude/scripts
      - link: ~/.claude/statusline.js
        target: configs/claude/statusline.js
    copies:
      - src: configs/claude/settings.json
        dest: ~/.claude/settings.json
        if_missing: true
    validate:
      - type: json
        src: configs/claude/settings.json
        dest: ~/.claude/settings.json
```

#### validate の動作

| type | チェック方法 | 失敗時 |
|------|------------|--------|
| `gitconfig` | src の各 section.key を `git config --file dest --get` で確認 | WARN 出力して続行 |
| `json` | src の各トップレベルキーが dest に存在するか `jq` で確認 | WARN 出力して続行 |

validate 失敗時は警告のみで `exit 1` しない（ユーザーが意図的に変更した可能性があるため）。

#### .gitconfig の変更

共通部分から除去するもの:
- `credential.helper = osxkeychain`（macOS 依存）
- `[include] path = ~/.gitconfig.local`（copy 方式では不要）

共通部分として残すもの:
- `[alias]` セクション全体
- `[url "git@github.com:"] insteadOf`

#### settings.json の変更

- `configs/claude/setup.sh` から jq マージロジックを廃止
- setup.sh は symlink 等の他の処理のみ担当（またはマニフェストに完全移行）

### 現状の jq マージ方式を維持（却下）

ADR-015 の方式を `.gitconfig` にも拡張する案。却下理由: overlay ファイルの管理コストが増えるだけで根本的な問題が解決しない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `.gitconfig` | dotfiles | `configs/git/gitconfig` に移動。credential.helper と include を除去 |
| `scripts/setup-manifest.yml` | dotfiles | git コンポーネント追加、claude コンポーネントに copies + validate 追加 |
| `scripts/setup.sh` | dotfiles | validate 処理を追加（gitconfig 型・json 型） |
| `configs/claude/setup.sh` | dotfiles | jq マージロジックを廃止 |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-027 セクション）
