# ADR-029: 端末ごとの SSH 鍵生成方式への移行

## ステータス

採用済み

## 関連 ADR

- 依存: ADR-028（overlay manifest + setup-github-ssh.sh を前提）

## コンテキスト

ADR-028 で pub 鍵（`private_ed25519_github.pub` / `private_ed25519_github_sign.pub`）を `configs/git/` に移動してリポジトリ管理する方針を採用した。しかし以下の問題がある。

1. **秘密鍵を配布できない**: セキュリティ上、秘密鍵を複数端末に配布すべきではない。端末ごとに鍵ペアを生成し、GitHub に個別登録するのが正しい運用
2. **pub 鍵のリポ管理が無意味**: 対応する秘密鍵がなければ pub 鍵だけリポジトリにあっても使えない。端末ごとに鍵を生成するなら pub 鍵も端末ごとに異なる
3. **セットアップ手順の欠落**: 鍵が存在しない新端末でのセットアップフロー（鍵生成 → GitHub 登録 → overlay manifest 設定）が未整備

## 設計案

### 端末ごとの鍵生成 + overlay manifest 設定（採用）

ADR-028 の pub 鍵リポ管理を廃止し、端末ごとに鍵ペアを生成する方式に変更する。

セットアップフロー:

1. 端末で `ssh-keygen` して鍵ペア作成（`~/.ssh/` に配置）
2. GitHub に pub 鍵を登録（Authentication key + Signing key）
3. `scripts/setup-manifest.local.yml` に鍵パスを記入
4. `bash scripts/setup.sh` → `~/.gitconfig` 配布 + `~/.ssh/config` 追加 + `user.signingkey` 設定 + `ssh-add`

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `configs/git/private_ed25519_github.pub` | dotfiles | 削除 |
| `configs/git/private_ed25519_github_sign.pub` | dotfiles | 削除 |
| `README.md` | dotfiles | SSH セットアップセクションに鍵生成手順を追加 |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-029 セクション）
