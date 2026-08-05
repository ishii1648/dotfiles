# ADR-081: main worktree での git switch/checkout を PreToolUse hook でブロックする

## ステータス
採用済み（一部 ADR-082 で拡張）

> 追記（ADR-082）: 本 ADR は main worktree のみを対象にしていたが、linked worktree では branch を自由に切替できてしまう（下記「受け入れ条件」2 項目目・issues.md 参照）ギャップが見つかり、ADR-082 で hook のスコープを全 worktree に拡張した。`block-main-worktree-branch-switch.py` は `block-worktree-branch-switch.py` にリネームされている。本 ADR が記録する main worktree 側の設計判断・懸念はそのまま有効。

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

- **main worktree 判定** — `git rev-parse --git-dir` と `--git-common-dir` が一致する場合のみ「main worktree」とみなす（グローバル CLAUDE.md の既存判定式をそのまま流用）
- **default branch 解決** — `git symbolic-ref refs/remotes/origin/HEAD` → 失敗時 `git config init.defaultBranch` → 最終フォールバック `main`
- **検出** — コマンド文字列を `&&`/`||`/`;`/`|` で分割し、各セグメントで `git switch`/`git checkout` の呼び出しを検出。ターゲットのブランチ名を抽出し、default branch と不一致なら `hookSpecificOutput.permissionDecision: "deny"` を返す
- **誤検知対策** — `git checkout <ref> -- <path>` のようなファイル復元系は `--` 検出で除外。`git checkout <path>`（曖昧系）は対象パスが cwd 上に実在すればファイル復元とみなし除外する
- **`-C <path>` の解決**（Codex stop-review 指摘 1 を受けて追加。初版は cwd 固定で判定していた）: セグメントごとに `-C` を解析し、そのセグメントの「実効ディレクトリ」を求めたうえで main worktree 判定・default branch 解決を行う。`-C` は git 本来の挙動どおり直前の実効ディレクトリに対して相対解決し、複数回指定にも対応する。これにより (a) main worktree の外から `git -C <main worktree> switch ...` を打つ回避経路と (b) main worktree の中から `git -C <linked worktree> switch ...` を打つ正当な操作の誤ブロックの両方を防ぐ
- **`cd` の追跡**（Codex stop-review 指摘 2 を受けて追加。上記 `-C` 対応だけでは `cd <dir> && git switch ...`（`-C` すら不要な回避）や `cd <dir> && git -C <相対パス> switch ...`（`-C` の相対解決基点がずれる回避）を検知できなかった）: コマンドをセグメントに分割したあと、左から順に走査しながら `running_cwd` を疑似シェルとして追跡する。`cd <path>` セグメントは `running_cwd` を更新し（相対パスは直前の `running_cwd` に対して解決、`cd` 単独は `~`）、以降の `git`/`-C` はすべてこの更新後の `running_cwd` を基点に解決する。`-C` は git 本来の挙動どおりその 1 回の呼び出しにしか効かないため `running_cwd` 自体は更新しない（`cd` との非対称性を明示的にテストで担保）
- `hook_input` の `cwd` フィールド（Claude Code が追跡するセッション実際の cwd）があればそれを起点にし、無ければ hook プロセス自身の `os.getcwd()` にフォールバックする
- **heredoc 本文の除外**（自己回帰: 本 ADR 自体の commit メッセージが `cd /main && git switch bar` という説明文を含んでいたため、`git commit -m "$(cat <<'EOF' ... EOF)"` の heredoc 本文がそのまま `&&`/`cd`/`git switch` として誤検知された）: セグメント分割の前に heredoc（`<<DELIM` 〜 `DELIM` 行）の本文を丸ごとスキップする前処理を追加した。heredoc は shell 構文ではなく任意のテキストなので、本文中に `cd`/`git switch` という**文字列**が現れても実行されるコマンドではない
- **fail-open** — パース不能・git 実行失敗・非 git リポジトリなど例外時は常に許可（既存 hook スクリプト群と同じ設計思想）
- `permission_mode` による skip は行わない。`defaultMode: "auto"` では通常の permission プロンプトが出ないため、まさにこの hook の deny が唯一の歯止めになる

### 却下: 全 Edit/Write を main worktree でブロックする案

却下理由: グローバル CLAUDE.md の「main worktree の未コミット変更を引き継ぐ場合は分離しない」という正当な例外運用と衝突し、継続作業中の正当な編集まで誤ブロックする。footgun の発生源である `switch`/`checkout` そのものを狙う方が副作用が少ない。

### 却下: `permissionDecision: "ask"` にする案

却下理由: `defaultMode: "auto"` の設計思想（「人間への確認を最小化」「モデルが自己解決する」）に反する。モデル自身の footgun を防ぐのが目的であり、人間を割り込ませる必要はない。`deny` + 理由文言で完結させ、モデルに EnterWorktree での再試行を促す。

## 懸念

- shell 構文の完全パースはしていないため、複雑な引用符入れ子コマンドでは検出漏れ／誤検知の可能性がある（fail-open なので検出漏れ側に倒す）
- `git switch -`（直前ブランチへの復帰）は現状検出対象外
- `git config alias.sw switch` のような git alias 経由の呼び出しは `switch`/`checkout` という subcommand 名の一致でしか検出しないため素通りする（fail-open の許容範囲として受容）
- `--git-dir`/`--work-tree` は個別の実効ディレクトリ解決は行わず global flag としてスキップのみ行う（`-C` ほど一般的な用法ではないため優先度を下げた）
- `pushd`/`popd`・サブシェル `( cd x && git switch y )`・`$(cd x && pwd)` のようなコマンド置換内の `cd` は追跡対象外（`cd`/`git`/`-C` のみを疑似シェルとして追跡しており、bash の完全な構文解析はしていない）

### 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/claude/scripts/block-main-worktree-branch-switch.py` | 新規 hook スクリプト |
| `configs/claude/scripts/tests/test_block_main_worktree_branch_switch.py` | 単体テスト（文字列パース + 実 git worktree を使った統合テスト） |
| `configs/claude/settings.json` | `hooks.PreToolUse` に新規エントリ追加 |
| `docs/issues.md` | 受け入れ条件追記 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-081 セクション）
