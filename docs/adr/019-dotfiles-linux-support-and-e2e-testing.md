# ADR-019: dotfiles の Linux 対応と Docker ベース e2e テスト

## ステータス

採用済み

## コンテキスト

ADR-018 で統合セットアップスクリプト（`scripts/setup.sh`）を導入したが、e2e テスト（クリーンな環境でのセットアップ完走確認）を実行する手段がない。

現在の dotfiles は macOS 前提で作られているが、実際のセットアップ対象（fish / nvim / tmux / claude / aqua）は OS 非依存のファイル操作（symlink 作成・JSON マージ・ファイルコピー）のみで構成されている。Mac 固有のコンポーネントは ghostty だけであり、これはマニフェストのプロファイルで既に分離可能な設計になっている。

macOS のクリーン環境をインスタントに用意するのは困難（VM・CI runner ともにコストが高い）だが、Linux であれば Docker コンテナで即座にプレーンな環境を作れる。dotfiles を Linux 対応にすることで、Docker ベースの e2e テストが実現できる。

### 現状の OS 依存度

| コンポーネント | OS 依存度 | setup がやること |
|:---|:---:|:---|
| fish | なし | symlink 作成（config.fish, functions/, conf.d/） |
| nvim | なし | symlink 作成（~/.config/nvim） |
| tmux | なし | symlink 作成（~/.tmux.conf） |
| claude | なし | symlink 作成 + settings.json マージ（Python + jq） |
| aqua | なし | symlink 作成（aqua.yaml） |
| ghostty | **Mac のみ** | symlink 作成（~/.config/ghostty/config） |
| wezterm | なし | symlink 作成（wezterm.lua） |

## 設計案

### 1. マニフェストに `linux` プロファイルを追加

`remote` プロファイルと同様に、ghostty を除外した `linux` プロファイルを定義する。

```yaml
profiles:
  full:         # macOS（デフォルト）
    - fish
    - nvim
    - ghostty
    - wezterm
    - tmux
    - claude
    - aqua
  remote:       # SSH 先（Linux/macOS）
    - fish
    - nvim
    - tmux
    - claude
    - aqua
  linux:        # Linux（Docker e2e テスト用）
    - fish
    - nvim
    - wezterm
    - tmux
    - claude
    - aqua
```

### 2. Docker ベースの e2e テスト環境

Dockerfile でクリーンな Linux 環境を構築し、`scripts/setup.sh --profile linux` の完走を検証する。

```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y fish tmux neovim jq python3 curl git
# aqua のインストール
RUN curl -sSfL https://raw.githubusercontent.com/aquaproj/aqua-installer/v3.1.1/aqua-installer | bash
COPY . /dotfiles
WORKDIR /dotfiles
RUN bash scripts/setup.sh --profile linux
RUN bash scripts/setup.sh --dry-run --profile linux
```

### 3. CI 統合

GitHub Actions の Linux runner で Docker ベースの e2e テストを実行する。

```yaml
# .github/workflows/e2e.yml
on: [push, pull_request]
jobs:
  e2e-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t dotfiles-e2e -f tests/Dockerfile .
```

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `scripts/setup-manifest.yml` | dotfiles | `linux` プロファイルを追加 |
| `tests/Dockerfile` | dotfiles | 新規作成（e2e テスト用 Docker イメージ） |
| `.github/workflows/e2e.yml` | dotfiles | 新規作成（CI で e2e テストを実行） |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-019 セクション）
