# ADR-056: Docker サンドボックスのネットワーク egress 制御

## ステータス
Draft

## 関連 ADR
- 依存: ADR-030（Docker コンテナ隔離の基本設計。フェーズ 3 の Enforce を具体化する）

## コンテキスト

ADR-030 で Docker サンドボックスを採用し、ファイルシステム隔離は実現した。しかしネットワーク egress は現在無制限であり、deny ルールのバイパス手段（awk, perl, /dev/tcp 等）を通じた認証情報の exfiltration リスクが残っている。

settings.json の deny ルールでは `curl`, `wget`, `python3 -c`, `node -e` 等を個別にブロックしているが、新たなバイパス手段が無限に存在するため deny ルール単体では根本的な対策にならない。ネットワーク層での制御が必要。

ADR-030 ではフェーズ 1（Shadow）→ 2（Tune）→ 3（Enforce）の段階的導入を計画しているが、具体的な実装方針が未決定。

### 検討が必要な課題

- `--network=none` にすると `git push`, `gh pr create`, `npm install` 等が全て使えなくなる
- allowlist 方式にするには、必要な通信先の洗い出しが必要
- コンテナ内の iptables は `--cap-add=NET_ADMIN` が必要で、セキュリティトレードオフがある

## 設計案

### 案A: init-firewall.sh（iptables allowlist）

Anthropic 公式 devcontainer の init-firewall.sh を参考に、コンテナ内で iptables による egress allowlist を構成する。

- entrypoint.sh の root フェーズで iptables ルールを設定し、その後 claude ユーザーにドロップ
- allowlist: github.com, api.anthropic.com, registry.npmjs.org, deb.nodesource.com 等
- `--cap-add=NET_ADMIN` が必要

### 案B: Docker network + proxy

Docker ネットワークと forward proxy（squid 等）を組み合わせ、コンテナからの通信を proxy 経由に限定する。

- `--cap-add=NET_ADMIN` 不要
- proxy の運用コストが発生する

### 案C: --network=none + 事前キャッシュ

依存パッケージを事前にイメージに含め、ネットワーク不要で動作させる。git push/pull は SSH ソケット転送で対応。

- 最もセキュア
- パッケージ更新のたびにイメージ再ビルドが必要

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/docker/run.sh` | dotfiles | ネットワーク制御オプションの追加 |
| `configs/claude/docker/entrypoint.sh` | dotfiles | iptables ルール設定（案A の場合） |
| `configs/claude/docker/Dockerfile` | dotfiles | 必要パッケージ追加（iptables 等） |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-056 セクション）
