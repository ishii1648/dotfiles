# ADR-089: グローバル CLAUDE.md を行動ルールに絞り、背景を ADR に退避する

## ステータス

Draft

## 関連 ADR

- 関連: [ADR-081](081-block-main-worktree-branch-switch.md)（main worktree の branch 切替ブロック。CLAUDE.md 側の説明を hook 参照に置き換える対象）
- 関連: [ADR-082](082-pin-every-worktree-to-single-branch.md)（worktree と branch の 1:1 不変条件。同上）
- 関連: [ADR-084](084-nix-home-manager-package-symlink-layer.md)（`~/.claude/` が nix home-manager の生成物になった。CLAUDE.md の「dotfiles へのシンボリックリンク」という記述が実態と合わなくなった原因）

## コンテキスト

グローバル CLAUDE.md（`configs/claude/CLAUDE.md`、実体は `~/.claude/CLAUDE.md`）が 50 行 / 6.1KB まで育った。全セッションのコンテキスト先頭に常時ロードされるため、内容の質がそのまま全作業の質に効く。

問題は分量そのものではなく、次の 3 つが混ざっていることだった。

**行動ルールと背景説明の混在** — 「なぜこのルールがあるか」の経緯（過去に作業が崩壊した話、advisor が使えない理由）が、守るべき行動と同じ密度で書かれていた。モデルが実行時に必要とするのは行動のほうで、経緯は読み手の納得材料でしかない。

**実態と乖離した記述** — 3 点が古くなっていた。

- 「`~/.claude/CLAUDE.md` は dotfiles へのシンボリックリンク」— ADR-084 以降、実際は nix home-manager の store を 2 段経由する（`~/.claude/CLAUDE.md` → `/nix/store/...-home-manager-files/.claude/CLAUDE.md` → `/nix/store/...-hm_CLAUDE.md` → dotfiles の実体）。編集先が dotfiles という結論は変わらないが、リンクの説明が誤り
- 「read-only の巻き添えキャンセルは修正済／mutating は未修正」— Claude Code のバージョンに依存する内部事情で、検証も更新もされないまま常時ロードされ続けていた
- 「`~/.claude/settings.json` の `CLAUDE_CODE_DISABLE_ADVISOR_TOOL: "1"` で無効化済み」— 手元の実ファイルには存在するが、dotfiles 側の `configs/claude/settings.json` には無かった。新しいマシンに展開すると記述が嘘になる状態

**トピックの混在** — 「ツール呼び出しの規律」の 1 セクションに、並列キャンセル対策・出力の信頼性・外向き操作の再試行・シンボリックリンクの編集先という 4 つの別テーマが同居していた。最後の 1 つはプロジェクト CLAUDE.md 側の「グローバル `~/.claude/` は参照専用」とも重複していた。

## 設計案

### 案A: 行動ルールだけ CLAUDE.md に残し、背景は ADR に退避する（採用）

CLAUDE.md には「何をする / してはいけないか」だけを置き、「なぜ」は本 ADR に移して参照だけ残す。hook が機械的に強制している内容（worktree と branch の 1:1）は、判定ロジックの説明を削って結論と ADR 参照に置き換える。

採用理由:

- 常時ロードされる領域は実行時に効く情報の密度を最大化すべきで、経緯は必要になったときに ADR を引けばよい
- 既に ADR-081/082 のように「ルールは CLAUDE.md、理由は ADR」という分担が部分的に成立しており、それに揃うだけ
- 腐りやすい記述（harness のバージョン依存の挙動）を ADR 側に隔離すると、CLAUDE.md の更新頻度が下がる

### 案B: 章構成を保ったまま圧縮のみ行う（却下）

却下理由: 冗長な言い回しを削るだけでは、陳腐化した記述とトピックの混在がそのまま残る。分量は減っても「読んでも実行に効かない行」の割合は変わらない。

### 案C: 規律を skill 化してオンデマンドで読ませる（却下）

却下理由: ツール呼び出しの規律は**事前に**守られていなければ意味がなく、事故が起きてから読むのでは間に合わない。`~/.claude/rules/` への移設も検討したが、rules は CLAUDE.md と同じく常時ロードされるためコンテキスト削減にはならず、置き場所が増えるだけになる。

## 設計上の判断

- **削るのは背景であって、ルールの数ではない** — 実効性のあるルール（fish / BSD、`|| true`、`git add -A` 禁止、worktree の残置確認をしない）は 1 つも落とさない。削減率を目的にすると、モデルが既定では守らない項目まで削れてしまう
- **hook が強制しているものは結論だけ書く** — worktree と branch の 1:1 は `block-worktree-branch-switch.py` がブロックする。モデルが知る必要があるのは「branch を変えたいなら新しい worktree を作る」だけで、`--git-dir` と `--git-common-dir` を比較する判定手順まで書かなくてよい。ただし「既に worktree 内かどうか」の判定はモデル自身が行うため、そちらは 1 箇所だけ残す
- **バージョン依存の挙動は断定形で書かない** — 「read-only は修正済み / mutating は未修正」のような harness の内部状態は、書いた時点でしか正しくない。CLAUDE.md 側は「混ぜない」「`|| true` を付ける」という、どちらに転んでも損しない行動だけを書く
- **編集先の記述はグローバル側に 1 行だけ残す** — プロジェクト CLAUDE.md と重複するが、dotfiles 以外のリポジトリで作業しているときにプロジェクト側は読まれない。グローバルから消すと `~/.claude/` を直接編集する事故が戻る
- **settings.json の乖離も同時に直す** — advisor 無効化はドキュメントだけが真実になっていた。`configs/claude/settings.json` に `CLAUDE_CODE_DISABLE_ADVISOR_TOOL` を追加し、記述と設定を一致させる

## 退避した背景

CLAUDE.md から削った経緯を、失われないようここに残す。

### 並列ツール呼び出しの巻き添えキャンセル

過去に「同一コマンドの重複送信」と「BSD 非対応フラグの混入」が連鎖して作業が崩壊したことがある。1 つのツール呼び出しが非 0 で終わると、同じバッチの無関係な兄弟呼び出しまで `Cancelled: parallel tool call errored` で巻き添えキャンセルされるのが原因だった。read-only 系については後に修正されたが、mutating 系で同じ保証があるかは確認していない。

厄介なのは失敗の見え方で、キャンセルされた Edit が「成功したように見えて未適用」になる。ここから「状態確認は `git diff` を唯一の真実とする」というルールが出ている。同じ理由で、Edit の成功表示・直後の Read・スクリプトの `OK` 出力も信用しない（表示層が古い内容や存在しない diff を返すことがあった）。

### built-in advisor を使わない理由

built-in の `advisor` ツールは server-side tool のため `permissions.deny` の対象外で、deny しても「matches no known tool」の警告が出るだけで無効化できない。`env.CLAUDE_CODE_DISABLE_ADVISOR_TOOL: "1"` でのみ止められる。セカンドオピニオンが必要な場合は `codex-advise` skill（Codex / GPT-5 への相談、openai-codex plugin 経由）を使う。codex-advise が使えない状況（plugin 未導入・未ログイン等）でも advisor には戻さず、不足をユーザに伝えて判断を仰ぐ。

### `~/.claude/` の実態

ADR-084 の nix home-manager 層により、`~/.claude/CLAUDE.md` は dotfiles への直接シンボリックリンクではなくなり、`/nix/store/...-home-manager-files/` を経由するようになった。ただし `nix/symlinks.nix` は `mkOutOfStoreSymlink` を使っているため、store 内のファイル自体が dotfiles の実体を指す symlink であり、最終的な参照先は変わっていない（`configs/` を編集するたびに `home-manager switch` が要る store コピー方式を避けるための設計）。

したがって「実体を編集すれば即反映される」という運用は維持されている。CLAUDE.md 側は `~/.claude/` を参照専用として扱い、編集は dotfiles の実体に対して行う、という指示だけを持てばよい。

## 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/claude/CLAUDE.md` | 行動ルールのみに再構成。背景・経緯を削除し ADR 参照に置き換え、陳腐化した 3 点を修正 |
| `configs/claude/settings.json` | `env.CLAUDE_CODE_DISABLE_ADVISOR_TOOL` を追加し、CLAUDE.md の記述と実態を一致させる |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-089 セクション）
