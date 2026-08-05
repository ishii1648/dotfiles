# ADR-016: SSH先（リモート環境）での dotfiles セットアップ対応

## ステータス

採用済み

## 関連 ADR

- [ADR-023](023-tmux-nested-architecture-decision.md) — ネスト構成が前提

## コンテキスト

dotfiles を lab（Mac mini）などの SSH 先にもデプロイして使いたいが、ローカル PC とリモート環境では必要な設定が異なる。

具体的な差異：
- **tmux** — リモート環境では tmux がネストされるため、ローカル側に F12 パススルートグル（ローカル tmux を一時無効化してリモート tmux にキーを透過させる）が必要
- **tmux** — リモート側では Ghostty user-keys 系のキーバインドが不要（Ghostty はローカルにしかない）
- **fish abbreviations** — macOS では `ggrep`/`gsed` 等の GNU toolchain エイリアスが必要だが、Linux では不要
- **Claude Code hooks** — tmux/Ghostty 連携の hooks はリモート（GUI なし）環境では不要な場合がある

現在の `setup-symlinks.sh --profile remote` は symlink 対象の絞り込みのみで、設定内容の環境別切り替えは行っていない。ただし、tmux (`source-file -q ~/.tmux.local.conf`) や fish (`conf.d/` ファイル単位 symlink) には既にローカルオーバーライドの仕組みがある。

## 設計案

新しい opts/条件分岐の仕組みは導入せず、既存のローカルオーバーライドパターンを活用する。

1. **リモート用 tmux テンプレート追加**: `configs/tmux/tmux.remote.conf.example` を用意し、リモート環境で `~/.tmux.local.conf` としてコピーして使う
2. **ローカル用 tmux テンプレート更新**: `configs/tmux/tmux.local.conf.example` に F12 パススルートグルを追加（ローカル側に必要な設定）
3. **SSH 先 tmux 接続用 fish 関数**: `tms` 関数で SSH 先の tmux にアタッチするワンライナーを提供
4. **setup-symlinks.sh の remote profile にtmux追加**: remote profile でも `~/.tmux.conf` の symlink を作成する

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `configs/tmux/tmux.local.conf.example` | dotfiles | F12 パススルートグル追加 |
| `configs/tmux/tmux.remote.conf.example` | dotfiles | 新規作成（リモート用テンプレート） |
| `configs/fish/functions/tms.fish` | dotfiles | 新規作成（SSH先 tmux 接続関数） |
| `scripts/setup-symlinks.sh` | dotfiles | remote profile に tmux symlink 追加 |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-016 セクション）
