# ADR-028: Git SSH 鍵・gitconfig プロファイル分離

## ステータス

採用済み

## 関連 ADR

- 依存: ADR-018（setup-manifest.yml による宣言的管理を前提）
- 依存: ADR-027（copy + validate 方式を前提とし、git コンポーネントを拡張）
- 関連: ADR-016（リモートプロファイル対応 — profile 別 copies の先行事例）

## コンテキスト

ADR-027 で `.gitconfig` を copy + validate 方式で管理するようになったが、以下の課題が残っていた。

1. **gitconfig が OS 非依存の単一ファイル**: `credential.helper = osxkeychain` は macOS 専用だが、ADR-027 では共通設定から除去しただけで macOS 向けの配布手段がなかった
2. **SSH 認証鍵の pub 鍵がリポジトリ未管理**: `private_ed25519_github.pub` / `private_ed25519_github_sign.pub` がリポジトリルートに散在していた
3. **SSH 鍵セットアップが完全手動**: `~/.ssh/config` への GitHub Host 設定追加、`user.signingkey` 設定、`ssh-add` 登録をすべて手動で行う必要があった
4. **setup スクリプトへのパラメータ渡し手段がない**: マニフェストの `setup` フィールドはスクリプトパスのみで、鍵パスなどの環境依存値を渡す仕組みがなかった。マニフェスト本体に環境依存値を埋め込むと共有性が損なわれる

## 設計案

### gitconfig プロファイル分離 + overlay manifest + SSH セットアップスクリプト（採用）

3 つの変更を組み合わせて解決する。

#### 1. gitconfig プロファイル分離

`configs/git/gitconfig`（linux 用）と `configs/git/gitconfig.macos`（full/remote 用）に分割。macos 版は linux 版の内容に `[credential] helper = osxkeychain` を追加したもの。

マニフェストの copies で profile フィルタを使い分ける:

```yaml
copies:
  - src: configs/git/gitconfig
    dest: ~/.gitconfig
    if_missing: true
    profile: linux
  - src: configs/git/gitconfig.macos
    dest: ~/.gitconfig
    if_missing: true
    profile: full
  - src: configs/git/gitconfig.macos
    dest: ~/.gitconfig
    if_missing: true
    profile: remote
```

#### 2. overlay manifest による setup_args 注入

環境依存の値をマニフェスト本体に埋め込まず、overlay manifest（`scripts/setup-manifest.local.yml`、gitignore 済み）で上書きする。

- ベースマニフェスト（`scripts/setup-manifest.yml`）: git コンポーネントに `setup_args` を定義しない
- overlay マニフェスト（`scripts/setup-manifest.local.yml`）: ユーザーが環境依存値を設定
- `.example` テンプレート（`scripts/setup-manifest.local.yml.example`）: 記入例を提供

```yaml
# scripts/setup-manifest.local.yml.example
components:
  git:
    setup_args:
      auth_key: ~/.ssh/private_ed25519_github
      sign_key: ~/.ssh/private_ed25519_github_sign
```

`setup.sh` のマニフェスト読み込みフェーズで、overlay が存在すれば Python の deep merge でベースに結合する。overlay は `components` 内のフィールドのみ上書きでき、`profiles` の変更は想定しない。

setup_args の各キーは `SETUP_` prefix + 大文字化して環境変数として setup スクリプトに渡される:
- `auth_key` → `SETUP_AUTH_KEY`
- `sign_key` → `SETUP_SIGN_KEY`

`null` または空値のキーは skip される。

#### 3. SSH 鍵セットアップスクリプト

`configs/git/setup-github-ssh.sh` が以下を実行:

1. `~/.ssh/config` に `Host github.com` 設定を追加（既存なら skip）
2. `git config --global user.signingkey` を設定
3. `ssh-add --apple-use-keychain` で鍵を登録
4. `ssh -T git@github.com` で接続テスト

dry-run 対応済み。環境変数未設定時は WARN を出して skip。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `configs/git/private_ed25519_github.pub` | dotfiles | リポジトリルートから移動 |
| `configs/git/private_ed25519_github_sign.pub` | dotfiles | リポジトリルートから移動 |
| `configs/git/gitconfig` | dotfiles | `[core]` セクション追加 |
| `configs/git/gitconfig.macos` | dotfiles | 新規作成（gitconfig + credential） |
| `configs/git/setup-github-ssh.sh` | dotfiles | 新規作成（SSH 鍵セットアップ） |
| `scripts/setup-manifest.yml` | dotfiles | git コンポーネントにプロファイル分離 + setup 追加 |
| `scripts/setup-manifest.local.yml.example` | dotfiles | 新規作成（overlay 記入例） |
| `scripts/setup.sh` | dotfiles | overlay manifest 結合 + setup_args → 環境変数変換機構を追加 |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-028 セクション）
