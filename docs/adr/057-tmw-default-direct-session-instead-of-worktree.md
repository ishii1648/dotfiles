# ADR-057: tmw_pick のデフォルト動作を worktree 強制から直接セッションに反転する

## ステータス
採用済み

## 関連 ADR
- 関連: ADR-033（tmux popup リグレッションテスト。tmw 関連動作の e2e テスト対象）

## コンテキスト

`tmw_pick` は ghq リポジトリ一覧から fzf で選択し、tmux セッションを起動する関数である。現在の実装ではデフォルトで git worktree の作成を強制する。例外的に `$__fish_config_dir/conf.d/tmw_direct_repos.conf` に登録されたリポジトリのみ、worktree を作成せずにメインリポジトリで直接セッションを開くことができる。

実際の利用では、worktree を強制したいリポジトリの方が少数派であり、大多数のリポジトリはメインリポジトリで直接開くことが望ましい。現状では直接開きたいリポジトリを都度 `tmw_direct_repos.conf` に追記する必要があり、オプトイン管理が煩雑になっている。

- worktree を使わないリポジトリをすべて `tmw_direct_repos.conf` に列挙する必要がある
- 新しいリポジトリを追加するたびに設定ファイルへの追記が必要
- worktree を強制したいリポジトリは少数（例: dotfiles など特定用途リポジトリのみ）

## 設計案

### 案A: デフォルト直接開き + worktree オプトイン（採用）

デフォルト動作を反転し、`tmw_pick` はデフォルトでメインリポジトリで直接セッションを開く。worktree 作成フローが必要なリポジトリは `tmw_worktree_repos.conf`（オプトイン）に列挙する。

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/fish/functions/tmw_pick.fish` | dotfiles | デフォルト動作を worktree 強制から直接セッション開きに変更。`tmw_direct_repos.conf` 参照を `tmw_worktree_repos.conf` 参照に変更 |
| `configs/fish/conf.d/tmw_direct_repos.conf` | dotfiles | 廃止（`tmw_worktree_repos.conf` に改名・役割変更） |
| `configs/fish/conf.d/tmw_worktree_repos.conf` | dotfiles | 新規追加（worktree を強制するリポジトリを列挙するオプトイン設定ファイル） |

**動作仕様**:

- `tmw_worktree_repos.conf` に登録されているリポジトリ: worktree 作成フロー（従来の worktree 強制動作）
- それ以外のリポジトリ: メインリポジトリで直接 tmux セッションを開く

### 案B: tmw_direct_repos.conf に全リポジトリを列挙する（却下）

メンテコストが高く、新リポジトリ追加のたびに設定ファイル更新が必要。スケールしない。

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-057 セクション）
