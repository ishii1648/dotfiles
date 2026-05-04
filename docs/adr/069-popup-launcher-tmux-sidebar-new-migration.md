# ADR-069: popup launcher を `tmux-sidebar new` に移行し dispatch_launcher.fish を廃止する

## ステータス

採用済み

## 関連 ADR

- 依存: ADR-056（dispatch/orchestrate popup ランチャーの起源 — 本 ADR で `dispatch_launcher.fish` を廃止する方向）
- 依存: ADR-061（popup ランチャーの claude/codex 二値モード — `tmux-sidebar new` に同等機能があることを確認する必要）
- 依存: ADR-062（codex モードの dispatch 化 — `tmux-sidebar new` に同等機能があることを確認する必要）
- 依存: ADR-063（`dispatch.sh` を `tmux-sidebar dispatch` thin wrapper に置き換える方針が示唆されており、本 ADR はその第一歩として popup 起動経路から先に統合する）
- 依存: ADR-064（`no-worktree-repos` のメイン worktree + デフォルトブランチ起動 — `tmux-sidebar new` 経由で同じ挙動になるか Spike で確認）
- 依存: ADR-065（codex 起動時の attached client 待機 — `tmux-sidebar dispatch` に同等の遅延ロジックがあるか Spike で確認）
- 関連: ADR-035（ADR Spike 検証パターン — feature parity 検証フェーズの位置付け）
- 関連: ADR-051（Go 製 tmux-sidebar ツール — popup picker の実装元）

## コンテキスト

ADR-056 で `dispatch_launcher.fish` を popup ランチャーとして導入し、ADR-061/062/064/065 で claude/codex 二値モード・no-worktree デフォルトブランチ・codex attached client 待機などの機能を順次積み上げてきた。`prefix+S`（ghostty 側 `super+shift+s` 経由 = Cmd+Shift+S）を bind に割り当て、日常的な session 起動の主経路となっている。

一方、ishii1648/tmux-sidebar 側で公式 popup picker (`tmux-sidebar new`) が提供され、本リポジトリの ADR-068 完了後に setup.md（main 系）が「primary: `tmux-sidebar new` / fallback: 既存 popup」の棲み分けを推奨する形に更新されている。直前の setup.md コンプライアンス再整合（issues.md「tmux-sidebar setup.md コンプライアンス再整合」）で `prefix+N` に `tmux-sidebar new` を bind 済みだが、`prefix+S` の dispatch_launcher は手付かずで二系統並存となっている。

ADR-063 では「将来 `dispatch.sh` を `tmux-sidebar dispatch` の thin wrapper に置き換えれば、Claude Code skill (`/dispatch`) と picker が同じ Go engine（`internal/dispatch`）を共有することになり、挙動の乖離リスクが消える」と明記されており、長期的には dispatch_launcher.fish を retire する方向性が示唆されている。本 ADR はその第一歩として、popup 起動 UI 層を `tmux-sidebar new` に統一する判断を記録する。

ただし dispatch_launcher.fish には ADR-064/065 で追加した固有機能があり、`tmux-sidebar new` がそれらを内包しているかは未検証（Cmd+Shift+S を `tmux-sidebar new` に差し替えた途端に regression が出ると影響が大きい）。Spike 検証を前段に置く必要がある。

## 設計案

### 案A: prefix+S を `tmux-sidebar new` に切替し dispatch_launcher.fish を完全廃止（採用候補）

- `configs/tmux/tmux.conf` の `bind S display-popup -E "fish -c dispatch_launcher"` を `bind S display-popup -E -w 80 -h 24 'tmux-sidebar new'` に置換
- ghostty 側の `super+shift+s=text:\x00S` は変更不要（prefix+S を送る部分は同一）
- Spike 検証で feature parity が確認できた段階で `configs/fish/functions/dispatch_launcher.fish` を `git rm`
- 関連 helper 関数（`__dl_repo_candidates.fish` / `__dl_fzf_toggle.fish` 等）も併せて削除
- ADR-056/061/062 のステータスを `廃止（ADR-069 で置換）` に更新（実装ロケーションが dotfiles → tmux-sidebar に移ったため）
- ADR-064/065 のステータスは Spike 結果次第で判断（tmux-sidebar 側に同等機能があれば `廃止`、無ければ tmux-sidebar 側に PR を出してから `部分廃止`）

採用理由:
- 二系統並存はメンテ負債（fish 関数群と Go ツールの両方を更新する必要がある）
- ADR-063 で明示された統合方針との整合
- Cmd+Shift+S という既存の筋肉記憶を温存できる（bind 先だけ差し替え）

### 案B: prefix+S を `tmux-sidebar new` に切替するが dispatch_launcher.fish は別 bind で fallback 維持（却下候補）

- `bind S` を `tmux-sidebar new` に切替
- `dispatch_launcher` を `prefix+M` 等の別 key に再 bind
- ghostty 側で `super+shift+m` 等の追加 keybind を定義

却下理由:
- 二系統並存のメンテ負債は解消されない
- 「fallback として残す」運用は ADR-063 の統合方針に逆行
- 二つの popup picker が並存する UX 上の混乱（どちらを使えばいいか毎回判断）

### 案C: 現状維持（prefix+N で `tmux-sidebar new`、prefix+S で dispatch_launcher）（却下候補）

- bind 変更なし
- `tmux-sidebar new` は prefix+N からのみアクセス、Cmd+Shift+S は dispatch_launcher のまま

却下理由:
- ADR-063 の統合方針と整合しない
- prefix+N は Cmd 経路がなく Cmd+Shift+S と比べてアクセス頻度が下がりやすい
- 二系統の機能差分が時間とともに広がりメンテコストが増える

### 案D: dispatch_launcher を残し prefix+S を完全廃止（却下）

- `bind S` を unbind し、`prefix+N` を唯一の popup launcher とする
- ghostty 側の `super+shift+s` も削除

却下理由:
- 既存の筋肉記憶を破壊する
- ghostty 側の keybind を変更すると dotfiles 範囲外（端末固有 sandbox）にも影響しうる

### Spike 検証項目（採用前提のチェックリスト）

案A 採用前に以下を `tmux-sidebar new` で実機検証する（spike/069 ブランチで実施）:

1. **claude モード**: `tmux-sidebar new` の launcher 選択で `claude` を選び、ghq repo を選択 → worktree が作られ Claude Code が初期 prompt 付きで起動する
2. **codex モード**: 同上で `codex` を選び、ghq repo を選択 → worktree + 初期 prompt + attached client 待機の遅延ロジックが効くか確認（ADR-065 相当）
3. **no-worktree-repos**: `~/.config/dispatch/no-worktree-repos` に登録した repo を選んだ場合、メイン worktree のデフォルトブランチで起動するか（ADR-064 相当）
4. **既存ブランチ checkout**: dispatch_launcher の `:<branch>` 記法相当の機能があるか（無ければ「未対応」と記録）
5. **orchestrate モード**: `tmux-sidebar new` に orchestrate（ADR-060 で復活したエージェントチェーン）の起動経路があるか（無ければ別途 bind を残す or upstream に PR）
6. **focus 制御**: dispatch 完了後、フォーカスが呼び出し元に留まるか（issues.md L685 課題と同質の regression が無いか）

Spike 結果が NG（特に項目 2/3/5）の場合は、本 ADR を `却下` または `部分採用` に切り替え、tmux-sidebar 側に upstream PR を出してから再 Spike する。

### Spike 検証結果（2026-05-03 実施 — `ishii1648/tmux-sidebar` main HEAD）

実機の対話テストではなく、`internal/dispatch/dispatch.go` / `internal/dispatch/branch.go` / `internal/picker/picker.go` の上流ソース読みによる静的検証。

| # | 項目 | 結果 | 根拠 |
|---|---|---|---|
| 1 | claude モード（worktree + prompt 投入） | ✅ PASS | `dispatch.Launch` が `CreateWorktree(repoPath, opts.Branch)` → prompt file 書き込み → `sendLauncherKeys` の流れを実装。`BranchFromPrompt`/`slugify` が `dispatch_launcher.fish` のスラッグ生成（`feat/<slug>`、40 文字、英数のみ）を 1:1 で移植している（`branch.go` のコメントに明記） |
| 2 | codex モード + ADR-065 attached client 待機 | ✅ PASS | `dispatch.go` L259 で `waitForAttachedClient(sessionName, 5*time.Minute)` を呼ぶ。コメントで ADR-065 と OSC 11 background-color query への対応を明示。タイムアウト 5 分も dotfiles 版 (`ADR-065` 受け入れ条件) と一致 |
| 3 | no-worktree-repos → デフォルトブランチ起動 | ✅ PASS | `dispatch.go` L177-218 で `MatchesNoWorktreeConfig(short)` (`~/.config/dispatch/no-worktree-repos`) を読み、ヒット時に `configMatched=true` → `workDir = CheckoutDefaultBranch(repoPath)` を実行。ADR-064 受け入れ条件と完全互換 |
| 4 | `:<branch>` 記法（既存 remote branch checkout） | ✅ PASS | `branch.go` の `ParseBranchPrefix` が prompt 先頭行 `:<name>` を検出し `checkoutMode=true` を返す。picker 側 (`picker.go` L289-291) は checkout 時 `opts.Branch=branch / opts.NoPrompt=true` を設定 |
| 5 | orchestrate モードの起動経路 | ❌ NG（要判断） | `picker.go` の wizard step は `stepRepo` / `stepPrompt` の 2 段のみ。launcher は `LauncherClaude` / `LauncherCodex` の二値で `toggleLauncher` も Tab で claude↔codex を切替えるだけ。popup から orchestrate を起動する経路が存在しない。dispatch_launcher.fish の Step 2 内 dispatch↔orchestrate トグル（claude モード時のみ）は upstream 未対応 |
| 6 | focus 制御（呼び出し元に留まる） | ✅ PASS | `picker.go` L280-285 で `Switch is left off so the user's current pane / session is not hijacked` と明示コメントあり。dispatch_launcher.fish の `run-shell -b switch-client` 強制遷移問題（issues.md L54/L685、ADR 未割当）が upstream 側で構造的に解消されている |

**総合判定: 5/6 PASS、orchestrate のみ未対応**

orchestrate に関するトレードオフ:

- 失われる経路: dispatch_launcher.fish の claude モード Step 2 で Tab を押して orchestrate 起動
- 残る経路: 任意の Claude session 内から `/orchestrate` slash command（ADR-067 codex-sync で codex 側にも symlink 配布済み）
- 影響評価: `/orchestrate` は ADR-060 でエージェントチェーン化されており、popup から「タスク記述 → 即 orchestrate 起動」したい頻度は低い（dispatch の方が遥かに使用頻度が高い想定）。orchestrate が必要なケースでは、まず claude session を `tmux-sidebar new` で起動してから `/orchestrate` を打てば等価。ステップ数 +1 のコストはあるが popup launcher 二系統並存のメンテ負債と比較すれば許容できる
- 代替: 将来 upstream の `tmux-sidebar new` に launcher の三値化 (claude/codex/orchestrate) を PR する選択肢もあるが、本 ADR では先送り（orchestrate 自体が dotfiles 固有概念であり、upstream に組み込ますコストが高い）

**判定**: 案A 採用可能。orchestrate トグル喪失は許容トレードオフとして ADR に記録。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/tmux/tmux.conf` L86 | dotfiles | 削除（`bind S display-popup -E "fish -c dispatch_launcher"`） |
| `configs/tmux/tmux.conf` | dotfiles | 追加（`bind S display-popup -E -w 80 -h 24 'tmux-sidebar new'`） |
| `configs/fish/functions/dispatch_launcher.fish` | dotfiles | 削除（`git rm`、Spike OK 確定後） |
| `configs/fish/functions/__dl_repo_candidates.fish` | dotfiles | 削除（`git rm`、dispatch_launcher 廃止に伴う helper） |
| `configs/fish/functions/__dl_fzf_toggle.fish` | dotfiles | 削除（`git rm`、dispatch_launcher 廃止に伴う helper） |
| `configs/fish/functions/__dl_*` 系の他の helper | dotfiles | 削除（`git rm`、要列挙） |
| `docs/adr/056-dispatch-orchestrate-popup-launcher.md` | dotfiles | ステータスを `廃止（ADR-069 で置換）` に更新し、起動 UI が `tmux-sidebar new` に移管された旨を注記 |
| `docs/adr/061-popup-launcher-claude-codex-modes.md` | dotfiles | ステータスを `廃止（ADR-069 で置換）` に更新 |
| `docs/adr/062-popup-launcher-codex-dispatch-phase2.md` | dotfiles | ステータスを `廃止（ADR-069 で置換）` に更新 |
| `docs/adr/064-dispatch-no-worktree-default-branch.md` | dotfiles | Spike 結果次第で `廃止（ADR-069 で置換）` か `部分廃止（ADR-069 で一部変更）` に更新 |
| `docs/adr/065-dispatch-codex-wait-for-attached-client.md` | dotfiles | Spike 結果次第で `廃止（ADR-069 で置換）` か `部分廃止（ADR-069 で一部変更）` に更新 |
| `docs/issues.md` L54（dispatch_launcher のフォーカス遷移課題） | dotfiles | dispatch_launcher 廃止に伴い `~~取り消し線~~` で打消し or 「ADR-069 で解消」と注記 |
| `docs/issues.md` L685（同上の受け入れ条件） | dotfiles | 同上 |
| `docs/reference.md` | dotfiles | popup 起動経路の説明を `tmux-sidebar new` ベースに書き換え |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-069 セクション）
