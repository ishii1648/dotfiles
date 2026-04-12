# tmux導入 - 運用方法

## 基本構造

```
session（リポジトリ or worktree 単位）
  └── window（作業種別: nvim, shell 等）
        └── pane（ほぼ使わない）
```

- session = 1リポジトリ or 1 worktree
- window = 同一session内での並列作業
- pane = 同時表示が必要な時だけ（ログ監視等）
- prefix キーは `Ctrl+Space`

## 日常ワークフロー

### session管理（tm コマンドに集約）

```bash
# 既存session一覧 + ghqリポジトリを統合表示
# 既存sessionは ● 付き、未作成リポジトリはそのまま表示
tm

# 表示例:
#   ● <org>_<repo>             ← 既存session → 選択で切り替え
#   ● ishii1648_dotfiles       ← 既存session → 選択で切り替え
#     <org>/<repo>             ← ghqリポジトリ → 選択で新規session作成
#     <org>/<other-repo>       ← ghqリポジトリ → 選択で新規session作成
```

### worktreeで並行作業

```bash
# worktreeを作成（tmux session作成 + 切替も自動）
gw_add feature-branch

# worktree作成 + Claude Code自動起動
gw_add -c feature-branch
```

### worktree切り替え（tmw）

```bash
# 既存worktreeをfzfで選択してtmux sessionを作成/アタッチ
tmw
```

### window操作

| 操作 | コマンド |
|------|----------|
| 新規window | `prefix + c` |
| window直接移動 | `Cmd + 数字` または `prefix + 数字` |
| next-window | `Ctrl+Tab` |
| previous-window | `Shift+Ctrl+Tab` |
| window一覧（現session限定） | `prefix + w` |
| window名変更 | `prefix + ,` |

### pane操作

| 操作 | コマンド |
|------|----------|
| pane作成（横分割） | `prefix + n` |
| pane削除 | `prefix + x` |
| 左のpaneへ移動 | `prefix + h` |
| 下のpaneへ移動 | `prefix + j` |
| 上のpaneへ移動 | `prefix + k` |
| 右のpaneへ移動 | `prefix + l` |
| paneリサイズ | `prefix + H/J/K/L` |

### URL操作（Cmd + u）

| 操作 | コマンド |
|------|----------|
| 画面上のURLをfzf一覧表示して開く | `Cmd + u` または `prefix + u` |

`#123` のような PR 番号もカスタムフィルターで GitHub PR URL に変換される。

### session切り替え（prefix + s）

`prefix + s` で `tm` がポップアップで起動する。
Claude Code 等のプログラム実行中でも session 切り替え・新規作成が可能。

| 操作 | コマンド |
|------|----------|
| session切り替え/作成 | `prefix + s`（ポップアップで `tm` 起動） |
| 直前のsessionに戻る | `prefix + m` |
| デタッチ | `prefix + d` |
| session終了 | `tmux kill-session -t <name>` |
| 設定リロード | `prefix + r` |

### コピー

| 操作 | コマンド |
|------|----------|
| コピーモード開始 | `prefix + [` |
| 選択開始 | `v` |
| コピー | `y`（pbcopyに送られる） |
| マウスでコピー | `Shift + ドラッグ` → `Cmd + C` |

## Claude Code 並行作業時の運用

### 複数sessionでClaude実行

```bash
# Session A: dotfiles で Claude 起動
tm → dotfiles → claude

# Session B: other-repo で Claude 起動
tm → other-repo → claude
```

## 使用頻度の目安

| 操作 | 頻度 |
|------|------|
| `tm`（session作成/切替） | 頻繁 |
| `Ctrl+Tab` / `Cmd+数字`（window切替） | 頻繁 |
| `prefix + c`（新規window） | 時々 |
| `prefix + m`（直前のsessionに戻る） | 時々 |
| pane分割 | 稀 |
