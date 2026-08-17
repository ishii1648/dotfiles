# ADR-082: worktree と branch を 1:1 に固定し、linked worktree でも branch 切替をブロックする

## ステータス
採用済み

## 関連 ADR
- 依存: ADR-081（本 ADR はその hook のスコープを main worktree のみから全 worktree に拡張する）
- 依存: グローバル `~/.claude/CLAUDE.md`「並列セッションの衝突回避（worktree isolation）」— worktree:branch 1:1 の不変条件を明記する拠り所
- 関連: ADR-042（hook ヘッダ規約・settings.json への登録方式）

## コンテキスト

sre-docs リポジトリで作業中、default worktree が `docs/adr-production-feature-flag-id-base-policy-removal` ブランチをチェックアウトしたまま放置されている状態が見つかった。ADR-081 の hook は main worktree での `git switch`/`checkout` を既にブロックしているため、この特定インスタンスは hook 導入前の drift か、Claude Code の Bash tool を経由しない操作（手動 git 操作・別ツール経由）によるものと考えられ、本 ADR の hook 変更で遡って直るものではない。

ただし、これを機にグローバル CLAUDE.md の worktree isolation ルールを再点検した結果、ADR-081 が意図的にスコープ外とした部分に構造的なギャップが見つかった。

1. **linked worktree は branch を自由に切替できる**: ADR-081 の hook は main worktree のみを対象にしており、linked worktree では `git switch`/`checkout` が無制限に許可されていた（同 ADR の受け入れ条件・統合テストで明記済みの仕様）。これにより、EnterWorktree で「この branch のために」作った worktree が、セッション途中で別の branch を掴んでしまい、worktree ⇔ branch の対応関係が壊れうる。
2. **CLAUDE.md の例外が ADR-081 の狙いと矛盾する**: 「main worktree の未コミット変更を引き継ぐ場合は分離しない」という運用上の例外があり、これは「未コミット変更を持ち込みたいから main worktree に居座って作業ブランチに切り替える」判断を正当化してしまう。ADR-081 が防ごうとした footgun（main worktree が作業ブランチに乗っ取られる事故）と方向性が矛盾する。

「default worktree は常に default branch」に加えて「worktree と branch は 1:1」という不変条件を明文化し、hook とルール文書の両方をこれに揃える。

## 設計案

### 採用: hook のブロック対象を全 worktree に拡張し、linked worktree は「現在の branch」に固定する

`configs/claude/scripts/block-main-worktree-branch-switch.py` を `block-worktree-branch-switch.py` にリネームし、判定ロジックを拡張する。

- **main worktree** — 引き続き default branch に固定（ADR-081 と同じ。drift していても常に default が正とみなす）
- **linked worktree** — `git branch --show-current` で得られる「現在チェックアウトしている branch」に固定する。target がそれと一致しない `switch`/`checkout`（`-b`/`-c` による新規作成含む）は deny する
- **detached HEAD** — `git branch --show-current` が空文字を返す（=判定不能）場合は fail-open で許可する。rebase 中などの一時的な detached 状態を誤ってブロックしないため
- 検出・`-C`/`cd` 追跡・heredoc 除外・fail-open といった既存の仕組みは ADR-081 のものをそのまま流用する（変更なし）

### CLAUDE.md の例外を stash ベースの手順に置き換える

「main worktree の未コミット変更を引き継ぐ場合は分離しない」という例外を削除し、代わりに `git stash push` → `EnterWorktree` → 新 worktree 内で `git stash pop` する手順を明記する。stash はリポジトリ共有（`.git/refs/stash` は worktree ごとではない）でどの worktree からも参照できるため、未コミット変更を持ち込みたいケースは main worktree に留まらなくても解決できる。

### 却下: linked worktree のブロックを見送り、cleanup 運用の強化のみで対応する案

却下理由: ADR-081 のコンテキストで既に「リンク worktree が 224 個も放置されており main を掴んだまま忘れられていた」という cleanup 側の問題は別途 `code-flow:clean_gone` 等で対処する方針が確立している。しかし cleanup は事後対応であり、途中で branch が壊れること自体は防げない。1:1 の不変条件を hook で機械的に強制する方が、根本原因（linked worktree 内で自由に switch できること）に直接効く。

### 却下: linked worktree の switch を `permissionDecision: "ask"` にする案

却下理由: ADR-081 と同じ理由（`defaultMode: "auto"` の設計思想に反する）で却下。

## 懸念

- 本 hook は Claude Code の PreToolUse（Bash matcher）経由でのみ機能する。Codex CLI など他のツールや、手動の git 操作からの `switch`/`checkout` はブロックできない。今回発端になった sre-docs の drift はこの経路で起きた可能性が高く、本 ADR のスコープ外
- 既に branch がずれてしまっている worktree を自動修復するものではない（fail-open 設計であり、事後の手動修復が必要）
- ADR-081 と同じ懸念（shell 完全パースをしていない・git alias 経由は素通り等）を引き続き継承する

### 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/claude/scripts/block-main-worktree-branch-switch.py` → `block-worktree-branch-switch.py` | リネーム + linked worktree もブロック対象にする判定ロジック追加 |
| `configs/claude/scripts/tests/test_block_main_worktree_branch_switch.py` → `test_block_worktree_branch_switch.py` | リネーム + linked worktree 向けテストの反転・追加 |
| `configs/claude/settings.json` | hook パスをリネーム後のファイル名に更新 |
| `configs/claude/CLAUDE.md` | worktree:branch 1:1 の不変条件を明記し、main worktree に居座る例外を stash ベースの手順に置き換え |
| `docs/issues.md` | ADR-081 セクションの該当受け入れ条件に反転の注記を追加 + ADR-082 セクション新設 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-082 セクション）
