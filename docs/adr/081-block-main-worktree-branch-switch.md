# ADR-081: main worktree での git switch/checkout を PreToolUse hook でブロックする

## ステータス
採用済み

## 関連 ADR
- 依存: グローバル `~/.claude/CLAUDE.md`「並列セッションの衝突回避（worktree isolation）」— main worktree は常に default branch であるべき、というルールの拠り所
- 関連: ADR-064（廃止・ADR-069 で置換）— popup 起動時に no-worktree-repos リポジトリをデフォルトブランチへ揃える類似の狙いを持つが、起動時点の `checkout` であり本 ADR はセッション**中**の `switch`/`checkout` をブロックする点が異なる（両者は排他ではなく補完関係）
- 関連: ADR-042（hook ヘッダ規約・settings.json への登録方式）
- 関連: ADR-017 / ADR-037（PreToolUse hook で `permissionDecision` を返す既存パターンの踏襲元）

## コンテキスト

sre-hub リポジトリで作業中、main worktree（`/Users/sho-ishii/ghq/github.com/C-FO/sre-hub`）が `learnings/ssh2node-pasture-ssm-agent-race` ブランチをチェックアウトしたままの状態になっており、`git switch main` が失敗する事故が発生した。調査の結果、原因は 2 つあった。

1. リンク worktree が 224 個も放置されており、そのうち 1 つが `main` を掴んだまま忘れられていた（cleanup 運用の問題。hook では解決しない、別途 `code-flow:clean_gone` 等の定期実行で対処する）
2. main worktree 自体で `git switch`/`checkout` を直接実行し、非 default branch で作業していた（グローバル CLAUDE.md の「ファイルを編集するタスクは最初の Edit/Write の前に EnterWorktree で専用 worktree に移る」というルール違反）

2 は既存ルールとして明文化されているが、モデルが実行時に忘れる／守らないリスクがあり、記憶頼みでは再発を防げない。「自動化すべき挙動は hook で機械的に強制する」という既存方針（ADR-013/014/017/037 等）に従い、hook で動作制御する。

## 設計案

### 採用: PreToolUse (Bash matcher) hook で `git switch`/`git checkout` の branch-changing 呼び出しを main worktree でのみブロックする

`configs/claude/scripts/block-main-worktree-branch-switch.py` を新設し、`settings.json` の `hooks.PreToolUse` に `approve-safe-commands.py` と並列のエントリとして追加する。

- **main worktree 判定**: `git rev-parse --git-dir` と `--git-common-dir` が一致する場合のみ「main worktree」とみなす（グローバル CLAUDE.md の既存判定式をそのまま流用）
- **default branch 解決**: `git symbolic-ref refs/remotes/origin/HEAD` → 失敗時 `git config init.defaultBranch` → 最終フォールバック `main`
- **検出**: コマンド文字列を `&&`/`||`/`;`/`|` で分割し、各セグメントで `git switch`/`git checkout` の呼び出しを検出。ターゲットのブランチ名を抽出し、default branch と不一致なら `hookSpecificOutput.permissionDecision: "deny"` を返す
- **誤検知対策**: `git checkout <ref> -- <path>` のようなファイル復元系は `--` 検出で除外。`git checkout <path>`（曖昧系）は対象パスが cwd 上に実在すればファイル復元とみなし除外する
- **fail-open**: パース不能・git 実行失敗・非 git リポジトリなど例外時は常に許可（既存 hook スクリプト群と同じ設計思想）
- `permission_mode` による skip は行わない。`defaultMode: "auto"` では通常の permission プロンプトが出ないため、まさにこの hook の deny が唯一の歯止めになる

### 却下: 全 Edit/Write を main worktree でブロックする案

却下理由: グローバル CLAUDE.md の「main worktree の未コミット変更を引き継ぐ場合は分離しない」という正当な例外運用と衝突し、継続作業中の正当な編集まで誤ブロックする。footgun の発生源である `switch`/`checkout` そのものを狙う方が副作用が少ない。

### 却下: `permissionDecision: "ask"` にする案

却下理由: `defaultMode: "auto"` の設計思想（「人間への確認を最小化」「モデルが自己解決する」）に反する。モデル自身の footgun を防ぐのが目的であり、人間を割り込ませる必要はない。`deny` + 理由文言で完結させ、モデルに EnterWorktree での再試行を促す。

## 懸念

- shell 構文の完全パースはしていないため、複雑な引用符入れ子コマンドでは検出漏れ／誤検知の可能性がある（fail-open なので検出漏れ側に倒す）
- `git switch -`（直前ブランチへの復帰）は現状検出対象外
- `git -C <path> switch <branch>` のように `-C` で別ディレクトリを明示された場合、「main worktree かどうか」の判定は Bash プロセスの `cwd` で行っており `-C` の指定先までは辿らない（今回の実インシデントである「cwd 上で直接 switch する」ケースをカバーすることを優先した）

### 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/claude/scripts/block-main-worktree-branch-switch.py` | 新規 hook スクリプト |
| `configs/claude/scripts/tests/test_block_main_worktree_branch_switch.py` | 単体テスト（文字列パース + 実 git worktree を使った統合テスト） |
| `configs/claude/settings.json` | `hooks.PreToolUse` に新規エントリ追加 |
| `docs/issues.md` | 受け入れ条件追記 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-081 セクション）
