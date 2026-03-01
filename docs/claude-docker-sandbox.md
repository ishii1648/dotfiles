# Claude Code Docker サンドボックス

Docker コンテナ内で Claude Code を `--dangerously-skip-permissions` 付きで安全に自律実行する。

> 設計の背景・判断根拠は [ADR-030](adr/030-claude-code-docker-sandbox.md) を参照。

## 前提条件

- Docker がインストールされていること
- colima 使用時はメモリ 16GiB 以上で起動すること（複数コンテナ並列実行に対応。`setup.sh` 実行時は `--cpu 4 --memory 16` で自動起動される）
- Claude Code の subscription が有効であること（ホストの `~/.claude` をマウントして認証を共有）

## 使い方

```bash
# カレントディレクトリのプロジェクトで起動
bash configs/claude/docker/run.sh

# プロジェクトディレクトリを指定して起動
bash configs/claude/docker/run.sh ~/projects/my-app
```

初回実行時は Docker イメージのビルドが自動で行われる。2回目以降はキャッシュ済みイメージを使用する。

### イメージの再ビルド

Dockerfile を更新した場合など、手動で再ビルドするには:

```bash
docker build -t claude-code-sandbox configs/claude/docker/
```

## マウント構成

deny-by-default 方式。明示的にマウントしたディレクトリのみコンテナからアクセスできる。

| ホスト | コンテナ | アクセス | 用途 |
|---|---|---|---|
| プロジェクトディレクトリ | 同パス | R/W | 作業対象 |
| `claude-code-local` (named volume) | `/home/claude/.local` | R/W | Claude Code インストール永続化 |
| `~/.claude` | `/home/claude/.claude` | R/W | Claude Code 設定・セッション |
| `~/.ssh` | `/home/claude/.ssh-host` | **Read-Only** | SSH 鍵（entrypoint で writable コピー） |
| `~/.gitconfig` | `/home/claude/.gitconfig` | R/W | Git 設定（存在時のみ） |
| `~/.config/gh` | `/home/claude/.config/gh` | R/W | gh CLI 認証（存在時のみ） |

ホストの `~/.zshrc`, `~/.local/bin`, LaunchAgent 等はマウントされない。

## GitHub アクセス

コンテナから GitHub にアクセスする経路は2つ。

| 用途 | プロトコル | 認証ソース |
|------|-----------|-----------|
| `git push/pull` | SSH | `~/.ssh` (RO マウント → コンテナ内コピー) |
| `gh pr create` 等 | HTTPS | `~/.config/gh` (存在時のみバインドマウント) |

ホストに `~/.config/gh` がない場合はコンテナ起動前にホスト側で `gh auth login` を実行しておくこと（[初回セットアップ](#初回セットアップ-gh-cli-認証)参照）。

### SSH config の OS 分岐

`setup-github-ssh.sh` が `~/.ssh/config` の `Host github.com` エントリを生成する際、`uname -s` で OS を判定し macOS のみ `UseKeychain yes` を追加する。Linux（Docker コンテナ含む）では付与されないため、ホスト側でセットアップ済みの `~/.ssh/config` をそのままマウントしても問題ない。

## セキュリティモデル

| 項目 | 方式 |
|------|------|
| ファイルシステム | deny-by-default マウント。プロジェクトディレクトリ以外のホストファイルにアクセス不可 |
| 実行ユーザー | entrypoint で root セットアップ後、`claude` ユーザー（非 root）にドロップ |
| SSH 鍵 | Read-Only マウント → コンテナ内で writable コピー。ホスト側の鍵は変更不可 |
| 認証 | ホストの `~/.claude` をマウントして subscription 認証を共有 |
| ネットワーク | 現在は制限なし。将来的に iptables + Cloudflare Gateway で egress 制御予定 |

## コンテナ内の環境

| ツール | バージョン |
|--------|-----------|
| OS | Debian Bookworm (slim) |
| Node.js | 22.x |
| git | Debian パッケージ版 |
| gh CLI | GitHub 公式リポジトリ版 |
| Python | 3.x |
| pnpm | corepack 経由 |
| Claude Code | 初回起動時に自動インストール（named volume で永続化） |

## 初回セットアップ: gh CLI 認証

ホストに `~/.config/gh` がない場合、コンテナ起動前にホスト側で gh CLI を認証しておく:

```bash
# ホスト側で実行
gh auth login --with-token <<< "ghp_xxxxx"
```

GitHub の [Personal Access Token](https://github.com/settings/tokens) を発行して使用する。SSH 先などブラウザが開けない環境ではトークン認証が必要。

認証後 `~/.config/gh` が作成され、`run.sh` がコンテナにバインドマウントする。

## トラブルシューティング

### SSH 認証エラー

ホストの `~/.ssh` に GitHub 用の鍵が配置されていることを確認する。コンテナ内では `/home/claude/.ssh` にコピーされる。

### パーミッションエラー

named volume のオーナーが合わない場合に発生することがある。volume を削除して再作成する:

```bash
docker volume rm claude-code-local
```
