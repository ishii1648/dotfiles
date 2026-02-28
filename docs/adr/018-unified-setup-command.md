# ADR-018: setup コマンドの一本化と理想状態の宣言的管理

## ステータス

Draft

## コンテキスト

dotfiles のセットアップには現在 3〜4 段階のコマンド実行が必要で、順序依存がある：

1. `bash configs/fish/setup.sh` — fish の個別 symlink 作成
2. `bash scripts/setup-symlinks.sh` — 全コンポーネントの symlink 設定
3. `bash configs/claude/setup.sh` — Claude Code settings.json のマージ生成
4. `bash <端末固有リポジトリ>/setup.sh` — 端末固有設定（オプション）

問題は 2 点ある：

### 1. セットアップ手順が複雑

- 実行順序を間違えると正しくセットアップできない（fish/setup.sh は setup-symlinks.sh より先に実行が必要）
- プロファイル（full / remote）によって手順が異なる
- リモート環境ではさらに `cp configs/tmux/tmux.remote.conf.example ~/.tmux.local.conf` の手動コピーが必要
- 新しい端末をセットアップするたびに README を参照する必要がある

### 2. 理想状態の定義がない

- ADR は個別の課題に対する設計判断を記録しているが、「dotfiles が正しくセットアップされた状態」の全体像を定義していない
- setup-symlinks.sh の `--dry-run` は symlink の状態のみ検証するが、fish の個別 symlink や Claude settings.json の状態はチェックしない
- 何をもって「セットアップ完了」とするかが曖昧で、新コンポーネント追加時にどのスクリプトに追加すべきか判断しにくい
- 理想状態をスクリプト内に埋め込むと、fish/setup.sh・setup-symlinks.sh・claude/setup.sh に分散したまま保守が困難になる

## 設計案

宣言的マニフェスト（`scripts/setup-manifest.yml`）で理想状態を定義し、統合スクリプト（`scripts/setup.sh`）がマニフェストを読んで検証・適用する。

### マニフェストの構造

```yaml
# scripts/setup-manifest.yml
# dotfiles の理想状態を宣言的に定義する
# scripts/setup.sh がこのファイルを読んで検証・適用する

profiles:
  full:
    - fish
    - nvim
    - ghostty
    - wezterm
    - tmux
    - claude
    - aqua
  remote:
    - fish
    - nvim
    - tmux
    - claude
    - aqua

components:
  fish:
    setup: configs/fish/setup.sh
    symlinks:
      # conf.d/ と functions/ の個別 symlink は setup.sh 内で管理
      - link: ~/.config/fish/config.fish
        target: configs/fish/config.fish
      # ... (fish/setup.sh が管理する個別ファイルを列挙)

  nvim:
    symlinks:
      - link: ~/.config/nvim
        target: configs/nvim

  ghostty:
    symlinks:
      - link: ~/.config/ghostty/config
        target: configs/ghostty/config

  wezterm:
    symlinks:
      - link: ~/.config/wezterm/wezterm.lua
        target: configs/wezterm/wezterm.lua

  tmux:
    symlinks:
      - link: ~/.tmux.conf
        target: configs/tmux/tmux.conf
      - link: ~/.local/bin/tmux-fzf-url-pr-filter
        target: configs/tmux/tmux-fzf-url-pr-filter

  claude:
    setup: configs/claude/setup.sh
    symlinks:
      - link: ~/.claude/agents
        target: configs/claude/agents
      - link: ~/.claude/CLAUDE.md
        target: configs/claude/CLAUDE.md
      - link: ~/.claude/commands
        target: configs/claude/commands
      - link: ~/.claude/scripts
        target: configs/claude/scripts
      - link: ~/.claude/skills
        target: configs/claude/skills
      - link: ~/.claude/statusline.js
        target: configs/claude/statusline.js

  aqua:
    symlinks:
      - link: ~/.config/aquaproj-aqua/aqua.yaml
        target: aqua.yaml
```

### 統合スクリプト

```bash
# 使い方
bash scripts/setup.sh                  # full プロファイルで適用
bash scripts/setup.sh --profile remote # remote プロファイルで適用
bash scripts/setup.sh --dry-run        # 検証のみ（全コンポーネント一括）
```

動作:
1. マニフェストを読み込み、プロファイルに応じたコンポーネント一覧を取得
2. 各コンポーネントの `setup` スクリプトがあれば実行（fish/setup.sh, claude/setup.sh）
3. 各コンポーネントの `symlinks` を検証・作成
4. `--dry-run` 時は全コンポーネントの状態を一括レポート

### マニフェストの責務境界

マニフェストはすべてを一元管理するのではなく、**コンポーネントごとに責務を委譲**する設計とする。

| 責務レベル | 管理者 | 例 |
|-----------|--------|-----|
| プロファイル定義（どのコンポーネントを含むか） | マニフェスト | `profiles.full: [fish, nvim, ...]` |
| 静的 symlink（パスが固定） | マニフェスト | nvim, ghostty, wezterm, tmux, aqua の全 symlink |
| 動的 symlink（ファイル追加で自動拡張） | 各 `setup.sh` に委譲 | fish の `conf.d/*.fish`, `functions/*.fish` |
| 設定ファイルのマージ生成 | 各 `setup.sh` に委譲 | claude の `settings.json` |
| `.example` テンプレートのコピー | マニフェスト（`copies` アクション） | `tmux.remote.conf.example` → `~/.tmux.local.conf` |

委譲先の `setup.sh` は `--dry-run` 引数を受け取り、検証のみモードに対応する。これにより `scripts/setup.sh --dry-run` が委譲先も含めて一括検証できる。

#### copies アクション

symlink ではなくファイルコピーが必要なケース（`.example` テンプレート等）をマニフェストで表現する：

```yaml
  tmux:
    symlinks:
      - link: ~/.tmux.conf
        target: configs/tmux/tmux.conf
    copies:
      - src: configs/tmux/tmux.remote.conf.example
        dest: ~/.tmux.local.conf
        profile: remote        # このプロファイル時のみ実行
        if_missing: true       # dest が存在しない場合のみコピー（既存設定を上書きしない）
```

### マニフェスト更新のワークフロー

マニフェストの更新が必要になるタイミングと手順：

| シナリオ | 更新先 | 手順 |
|----------|--------|------|
| 静的 symlink の追加・変更（claude に新ディレクトリ等） | マニフェストの `symlinks` | エントリを追加し `--dry-run` で検証 |
| 動的 symlink 対象ファイルの追加（fish function 等） | 更新不要 | `configs/fish/functions/` にファイルを置くだけで `setup.sh` が自動検出 |
| 新コンポーネントの追加 | マニフェストの `profiles` + `components` | コンポーネント定義を追加し、必要なら `setup.sh` も作成 |
| 既存 symlink のパス変更 | マニフェストの `symlinks` | `target` を修正し `--dry-run` で検証 |
| `.example` テンプレートの追加 | マニフェストの `copies` | エントリを追加 |

### マニフェストの整合性検証

`scripts/setup.sh --dry-run` はマニフェスト自体の整合性も検証する：

1. **target 実在チェック** — マニフェストの各 `target` パスがリポジトリ内に存在することを確認。存在しなければ `ERROR: target not found` を報告
2. **委譲先の検証** — `setup` を持つコンポーネントは委譲先の `setup.sh --dry-run` を実行し、その結果を統合レポートに含める
3. **copies の検証** — `copies` エントリの `src` がリポジトリ内に存在することを確認

> **スコープ外**: 「リポジトリ内の config ファイルがマニフェストに漏れなく記載されているか」の網羅性チェックは本 ADR のスコープ外とする。これは ADR-010（リグレッションテスト）で将来的に対応する可能性がある。

### 既存スクリプトとの関係

- `configs/fish/setup.sh` — そのまま残す。マニフェストの `fish.setup` から呼び出される。`--dry-run` 引数対応を追加
- `configs/claude/setup.sh` — そのまま残す。マニフェストの `claude.setup` から呼び出される。既に dry-run 相当の検証ロジックあり
- `scripts/setup-symlinks.sh` — マニフェストベースの新スクリプトに機能を統合。移行完了後に廃止

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `scripts/setup-manifest.yml` | dotfiles | 新規作成（理想状態の宣言的定義） |
| `scripts/setup.sh` | dotfiles | 新規作成（統合エントリポイント、マニフェスト読み込み・整合性検証） |
| `configs/fish/setup.sh` | dotfiles | `--dry-run` 引数対応を追加 |
| `scripts/setup-symlinks.sh` | dotfiles | 削除（setup.sh に機能統合後） |
| `README.md` | dotfiles | セットアップ手順を `scripts/setup.sh` に簡略化 |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-018 セクション）
