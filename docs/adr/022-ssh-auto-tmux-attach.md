# ADR-022: SSH 実行時にリモート先の tmux セッションへ自動アタッチ

## ステータス

採用済み

## 関連 ADR

- [ADR-021](021-ssh-visual-indicator.md) — SSH 関連（視覚的インジケーター）
- [ADR-023](023-tmux-nested-architecture-decision.md) — ネスト構成が前提

## コンテキスト

現在、リモートサーバーの tmux セッションに入るには `tms <host>` コマンドを使用する必要がある（ADR-016 で実装済み）。しかし、`ssh <host>` を直接実行した場合はシェルが起動するだけで tmux セッションには入らない。

リモートサーバーでの作業は基本的に tmux セッション内で行うため、SSH 接続後に毎回手動で `tmux attach` や `tmux new-session` を実行するのは手間である。`ssh` コマンド実行時に自動でリモート先の tmux セッションにアタッチ（既存セッションがなければ新規作成）できれば、ワークフローが簡素化される。

## 設計案

### 案 1: fish の ssh ラッパー関数（採用）

`ssh` を fish function でラップし、接続時にリモート側で `tmux new-session -A -s main` 等を自動実行する。

### 案 2: SSH の RemoteCommand 設定（却下）

`~/.ssh/config` に `RemoteCommand` を設定してリモート側で tmux を起動する。

### 案 3: `tms` コマンドの拡張（却下）

`tms` を `ssh` のエイリアス的に使えるよう拡張し、パススルーモード切り替えも含めた統合体験を提供する。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `configs/fish/functions/__tmux_passthrough_on.fish` | dotfiles | 新規作成: パススルーモード ON ヘルパー |
| `configs/fish/functions/__tmux_passthrough_off.fish` | dotfiles | 新規作成: パススルーモード OFF ヘルパー |
| `configs/fish/functions/ssh.fish` | dotfiles | 新規作成: ssh ラッパー（インタラクティブ時 tmux 自動アタッチ） |
| `configs/fish/functions/tms.fish` | dotfiles | 修正: パススルーモードをヘルパー呼び出しに置換 |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-022 セクション）
