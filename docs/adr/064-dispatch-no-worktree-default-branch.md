# ADR-064: no-worktree-repos の popup 起動はメインworktree+デフォルトブランチに揃える

## ステータス
廃止（ADR-069 で置換）

> `~/.config/dispatch/no-worktree-repos` を読みメイン worktree のデフォルトブランチで起動する挙動は upstream `tmux-sidebar` の `internal/dispatch` に `MatchesNoWorktreeConfig` + `CheckoutDefaultBranch` として完全互換で移植された（ADR-069 Spike で確認）。`dispatch_launcher.fish` 経由で実装していたロジックは `git rm` 済み。

## 関連 ADR
- 依存: ADR-062（`~/.config/dispatch/no-worktree-repos` を dispatch.sh の共通参照として確立）
- 関連: ADR-056（popup ランチャー全体方針）
- 関連: ADR-044（`tmw_worktree_repos.conf` によるオプトイン worktree パターン — `no-worktree-repos` は思想的に逆方向の opt-out 設定）

## コンテキスト

popup ランチャー（`cmd+shift+s`）から `~/.config/dispatch/no-worktree-repos` に登録されたリポジトリ（例: dotfiles）を選んで起動すると、`dispatch.sh launch --no-worktree` 経由でメインリポジトリをそのまま `cd` して claude/codex を起動していた。

このため起動直後の HEAD は「最後に手元で操作していた任意のブランチ」になる。具体的には：

- 直前に別の作業ブランチで commit していた場合、そのブランチで起動する
- worktree フローでないため新ブランチも切らない
- 結果として「dotfiles を popup から開いたら作業途中の `fix/foo` ブランチだった」という事故が起きうる

popup から no-worktree 対象リポジトリを開く利用者意図は「クリーンなデフォルトブランチで新しい作業を始める」であり、現状の挙動はこれと食い違う。

なお `dispatch.sh` には `repo_path` を経由する複数の入口がある：

1. popup ランチャー → `dispatch_launcher.fish` 内で config 判定 → `--no-worktree` 付きで `dispatch.sh` 呼び出し
2. `dispatch.sh launch <repo>` 直接呼び出し（config 自動判定で `no_worktree=true` に昇格）
3. `dispatch.sh launch <repo> --no-worktree`（明示フラグ。設定マッチに依らず）

(1)(2) は「リポジトリ単位で no-worktree が宣言された」ケース、(3) は「ad-hoc に worktree を作りたくない」ケースであり、ブランチ切替の意図表明としては異なる。

## 設計案

### 案A: dispatch.sh 内で config_match を追跡し、設定経由トリガー時のみ checkout（採用）

`dispatch.sh` の `no-worktree-repos` 判定ロジックを以下の通り変更する：

- `config_match` ローカル変数を追加し、`~/.config/dispatch/no-worktree-repos` にマッチしたかを追跡する（呼び出し元が既に `--no-worktree` を渡していた場合でも常にチェックする）
- `--no-worktree` が有効かつ `config_match=true` の場合のみ、`checkout_default_branch()` を呼び出す
- `checkout_default_branch()` の挙動：
  - `git worktree list --porcelain` の先頭エントリをメインworktreeとして取得し `work_dir` に設定
  - `origin/HEAD` を解決してデフォルトブランチを特定（フォールバック `refs/heads/main` → `refs/heads/master`）
  - 作業ツリーが clean かつ HEAD ≠ デフォルトブランチの場合のみ `git checkout <default>` を実行
  - dirty な場合は `tmux display-message` で警告し、現在ブランチのまま起動（データ損失防止）
  - checkout 失敗時も警告のみで起動は継続

明示的に `--no-worktree` を渡しただけ（`config_match=false`）のケースは従来挙動（カレントブランチ維持）を保つ。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/skills/dispatch/dispatch.sh` | dotfiles | `config_match` フラグ追加、`checkout_default_branch()` 関数追加、`--no-worktree` パスでの `elif config_match` 分岐追加 |
| `~/.claude/skills/dispatch/dispatch.sh` | dotfiles 配布先 | `~/.claude/skills/dispatch` ディレクトリ symlink 経由で自動反映（編集不要） |
| `docs/issues.md` | dotfiles | 受け入れ条件の追記 |

### 案B: dispatch_launcher.fish 側で git checkout してから dispatch.sh を呼ぶ（却下）

popup ランチャー側でブランチを切替えてから `dispatch.sh launch --no-worktree` を呼ぶ案。

却下理由：

- popup 以外の caller（CLI 直接利用・orchestrate 経由など）が同じ振る舞いを得るには再実装が必要
- `no-worktree-repos` 判定がランチャーと dispatch.sh で二重化し、保守時に乖離するリスクが高い
- 「メインworktree path の解決」「デフォルトブランチ特定」は dispatch.sh の `create_worktree` と既に同じ知識を持っており、責務集約の観点でも dispatch.sh が望ましい

### 案C: --no-worktree 単独でも常にデフォルトブランチに切替える（却下）

`config_match` を見ず、`--no-worktree` フラグだけで判定する案。

却下理由：

- 直接 CLI で `dispatch.sh launch some-repo --no-worktree --prompt "..."` を呼んだ利用者は、現在のブランチ状態を維持したい意図がある可能性が高い
- 設定駆動（リポジトリ単位の宣言）と ad-hoc 利用（その場限りのフラグ）で挙動を分ける方が、利用者の意図に近い
- 既存の CLI 利用者に対する破壊的変更を避けるため

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-064 セクション）
