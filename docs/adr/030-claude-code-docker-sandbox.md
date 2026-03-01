# ADR-030: lab 環境の Claude Code を Docker コンテナで隔離実行する

## ステータス
採用済み

## 関連 ADR
- 関連: ADR-015（Claude Code settings.json の管理 — コンテナへの設定同期に影響）
- 関連: ADR-019（dotfiles の Linux 対応 — Docker 内は Linux 環境）

## コンテキスト

Mac mini（lab 環境）で Claude Code を `--dangerously-skip-permissions` 付きで自律実行したい。home-lab の [009-agent-sandbox](https://github.com/ishii1648/home-lab/blob/main/docs/proposals/009-agent-sandbox.md) では SandVault（sandbox-exec ベース）+ Cloudflare Gateway を推奨していたが、調査の結果 SandVault では不十分であることが判明した。

### Claude Code Built-in Sandbox の限界

| 問題 | 詳細 | Issue |
|------|------|-------|
| 組み込みツールがバイパス | Write/Read/Glob は sandbox-exec を経由せずアプリ層で動作。deny 設定を無視 | [#15789](https://github.com/anthropics/claude-code/issues/15789) (NOT_PLANNED) |
| escape hatch が自動発動 | `allowUnsandboxedCommands: false` を設定してもシステムプロンプトが優先し `dangerouslyDisableSandbox: true` でリトライ | [#13583](https://github.com/anthropics/claude-code/issues/13583) |
| git/SSH が不安定 | `allowedNetworkHosts` は HTTP/HTTPS のみ。SSH (port 22) は対象外で `git push` が頻繁に失敗 | [#11481](https://github.com/anthropics/claude-code/issues/11481) (NOT_PLANNED) |

SandVault も同じ sandbox-exec 基盤のため、同様の問題が発生する。Anthropic 公式は[コンテナ + `--dangerously-skip-permissions`](https://code.claude.com/docs/en/devcontainer) を推奨パターンとしている。

### 参考実装

- **Anthropic 公式 devcontainer**: Dockerfile + init-firewall.sh (iptables allowlist) + devcontainer.json
- **agent-workspace** ([hiragram/agent-workspace](https://github.com/hiragram/agent-workspace)): Go 製 CLI。deny-by-default マウント、SSH 鍵 RO マウント、一方向設定同期、非 root 実行

## 設計案

### 案A: Docker コンテナ隔離 + Cloudflare Gateway（採用）

009 提案書の SandVault を Docker に置換し、Cloudflare Gateway はそのまま採用する。dotfiles に Docker イメージ定義・entrypoint・起動スクリプトを配置し、任意の端末で利用可能にする。

#### 配置するファイル

`configs/claude/docker/` ディレクトリに以下を配置する:

- `Dockerfile` — Claude Code 実行用コンテナイメージ（debian:bookworm-slim ベース、Node.js 22、git、gh CLI、非 root ユーザー `claude`）
- `entrypoint.sh` — SSH 鍵コピー・パーミッション修正・権限ドロップ・Claude Code インストール
- `run.sh` — ホストから実行する起動スクリプト。マウント構成・環境変数注入・`docker run` を実行

#### ファイルシステム隔離（Docker）

agent-workspace のマウントポリシーを参考にした deny-by-default 方式。`run.sh` が以下のマウントを構成する:

| マウント元 (Host) | マウント先 (Container) | アクセス | 目的 |
|---|---|---|---|
| プロジェクトディレクトリ（引数） | 同パス | R/W | 作業対象 |
| `claude-code-local` (named volume) | `/home/claude/.local` | R/W | Claude Code インストール永続化 |
| `~/.claude` | `/home/claude/.claude` | R/W | Claude Code 設定 |
| `~/.ssh` | `/home/claude/.ssh-host` | **Read-Only** | SSH 鍵 |
| `~/.gitconfig` | `/home/claude/.gitconfig` | R/W | Git 設定（存在時のみ） |
| `~/.config/gh` | `/home/claude/.config/gh` | R/W | gh CLI 認証（存在時のみ） |

ホストの `~/.zshrc`, `~/.local/bin`, LaunchAgent 等はマウントしない。

#### ネットワーク egress 制御（段階的導入）

iptables と Cloudflare Gateway を段階的に導入する。最初から DROP すると必要なドメインが不明なまま動作不能になるため、まず Cloudflare Gateway のログで通信先を観察してから allowlist を確定する。

| フェーズ | iptables | Cloudflare Gateway | 動作 |
|---------|----------|-------------------|------|
| 1. Shadow | **なし**（全許可） | Shadow（全許可 + ログ） | 全通信を許可しつつ Gateway ダッシュボードで通信先を観察（1〜2週間） |
| 2. Tune | **なし** | Shadow | ログから必要ドメインを洗い出し allowlist を作成 |
| 3. Enforce | **デフォルト DROP + allowlist** | Enforce（allowlist 外ブロック） | 二重構成で運用開始 |

init-firewall.sh は Enforce フェーズで追加する（本 ADR のスコープ外）。

#### Credential 管理

| 方針 | 詳細 |
|------|------|
| SSH 鍵 | RO マウント → entrypoint で writable コピー（パーミッション修正） |
| Claude Code 認証 | `~/.claude` マウントでホストの subscription 認証を共有 |
| Git credentials | `~/.config/gh` マウント or `GIT_ASKPASS` |

#### 実行ユーザー

entrypoint で root セットアップ → `claude` ユーザー（非 root）にドロップして実行。

### 案B: SandVault + Cloudflare Gateway（却下）

009 提案書の元案。sandbox-exec ベースのため Claude 組み込みツールのバイパス問題を解決できない。Apple が deprecated としており将来リスクもある。

### 案C: Docker コンテナ隔離のみ（却下）

init-firewall.sh でネットワーク制御は可能だが、DNS レベルのログ可視化やセキュリティカテゴリ自動ブロックが得られない。Cloudflare Gateway (Free) のコストはゼロなので併用しない理由がない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/docker/Dockerfile` | dotfiles | 新規作成（Claude Code 実行用コンテナイメージ） |
| `configs/claude/docker/entrypoint.sh` | dotfiles | 新規作成（SSH 鍵コピー・権限ドロップ・Claude Code インストール） |
| `configs/claude/docker/run.sh` | dotfiles | 新規作成（マウント構成・環境変数注入・docker run 起動スクリプト） |

## setup.sh プロファイル制約

docker / colima / docker-compose の Homebrew インストールおよび colima の自動起動は `remote` プロファイル時のみ実行される（`scripts/lib/deps-macos.sh`）。`full`（メイン Mac）では不要なためスキップする。

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-030 セクション）
