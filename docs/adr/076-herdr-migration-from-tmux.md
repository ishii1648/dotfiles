# ADR-076: ghostty + tmux + tmux-sidebar から ghostty + herdr へ移行する

## ステータス

Spike中

## 関連 ADR

- 依存: [ADR-035](035-adr-spike-validation-pattern.md)（Spike パターン）
- 依存: [ADR-040](040-spike-adr-lifecycle.md)（Spike ADR ライフサイクル）
- 影響: [ADR-051](051-go-tmux-sidebar-tool.md)（tmux-sidebar 本体 — 廃止対象）
- 影響: [ADR-007](007-tmux-claude-pane-state.md) / [ADR-063](063-tmux-codex-pane-state.md)（pane state — herdr integration に置換）
- 影響: [ADR-045](045-claude-session-always-on-display-ui.md)（セッション常時俯瞰 UI — herdr サイドバーに置換）
- 影響: [ADR-069](069-popup-launcher-tmux-sidebar-new-migration.md) / [ADR-075](075-picker-launch-popup-to-new-window.md)（picker — 廃止対象）
- 影響: [ADR-023](023-tmux-nested-architecture-decision.md)（tmux ネスト構成 — `herdr --remote` で不要化）

## コンテキスト

現構成は ghostty（起動時に `ghostty-tmux-init` が tmux `main` へ無限ループでアタッチ）+ tmux + 自作 tmux-sidebar（Go バイナリ + hook 8 個 + state file）。

2026-07-17 に herdr（Rust 製、エージェント認識マルチプレクサ）への移行を検討し、「一括移行はせず並走トライアル」と判断した。herdr 0.7.4 の導入と `~/.config/herdr/config.toml` の作成までは実施したが、**1〜2 週間の評価が実行されないまま立ち消えになり、ADR 化もされていない**。

再検討の動機は 3 点:

1. **tmux-sidebar の安定性**。幅ドリフトと hook 発火漏れは tmux の hook モデル（差分 `resize-pane`、イベントの穴）に構造的に起因し、対症療法（`relayout` の hook 追加、`window-resized` / `client-session-changed` の拡張）を重ねている。herdr は自前レンダラで毎フレーム全体を再計算するため、この種の不安定さは構造的に存在しない。
2. **worktree 事前作成方式の放棄**。「セッション作成時に先に worktree を作る」方式は (a) 起動が遅れる (b) worktree isolation は Claude セッション起動後に CLAUDE.md の指示で必要に応じて行えば足りる。この転換により picker の 2 段階 UI・dispatch の worktree 生成・branch 命名まわりが丸ごと不要になる。
3. **tmux の残存価値が URL 表示と Claude セッション管理の 2 点に集約されている**。どちらも herdr 側に対応機能がある。

### 2026-07 の却下理由の現在地

| 却下理由（2026-07） | 2026-08 時点 |
|---|---|
| v0.7 で目玉機能（agent 状態検出）にバグ | 0.7.5 まで進行。0.7.2〜0.7.5 で検出精度を継続修正。**0.7.5 で Claude Code への送信が bracketed-paste 対応**（`A != B` がシェルモードを誤爆する不具合を修正）。0.7.4 で copy-mode に smart-case 検索と tmux 風 word motion |
| 移行コストが過大 | 方針転換で激減。sidebar と picker を捨てる前提になり、ghostty keybind も `text:\x00X` の間接送信を廃せるため**むしろ単純化する** |
| tmux-sidebar と機能非等価 | 廃止前提のため阻害要因ではない（機能後退は後述） |
| SSH リモート運用の再設計が必要 | `herdr --remote <host>` がネイティブ。0.7.2 で Homebrew/mise/Nix 検出・OpenSSH 接続多重化・keepalive 自動付与。**F12 パススルー（tmux 入れ子回避）の仕組み自体が不要になる** |
| copy-mode / osc52 が未検証 | copy-mode は 0.7.4 で強化済み。`copy_on_select` / クリップボードトースト / `edit_scrollback` あり。osc52 相当のみ Spike で実測 |
| エコシステムが tmux に及ばない | 実依存は `wfxr/tmux-fzf-url` 1 個のみ、しかも自前 popup で上書き済み。**実質ゼロ** |
| AGPL-3.0 | 変わらず（個人利用は問題なし） |

## 設計案

### 置換マッピング

| 現行 | herdr |
|---|---|
| tmux.conf のキーバインド全般 | `[keys]`（split / focus / zoom / tab / resize すべて存在） |
| ghostty keybind 15 個以上の `\x00` 間接送信 | herdr 直接バインド（ghostty config が痩せる） |
| tmux-sidebar（Go バイナリ + hook 8 個 + state file） | ネイティブサイドバー + `herdr integration install claude/codex` |
| `claude-pane-state.sh`（hook 4 箇所） | integration が生成する `herdr-agent-state.sh` → `pane report-agent` に 1:1 置換 |
| `codex/hooks.json` の tmux-sidebar hook 3 個 | `herdr integration install codex` |
| `claude-notify.sh` | `[ui.toast] delivery = "system"` + `[ui.sound]`（スクリプト自体が不要） |
| claude-session-switch + claude-nav キーテーブル | `focus_agent = "prefix+alt+1..9"` / `workspace_picker` / `goto` |
| `tmw`（worktree → session） | `herdr worktree create/open` + `[worktrees] directory` |
| `tm`（fzf セッション切替） | workspace picker / session navigator |
| `tms` + F12 パススルー + `ssh.fish` | `herdr --remote <host>` |
| `prefix+u` の URL/PR popup | `[[keys.command]] type="popup"` + スクリプトを `herdr pane read` ベースに移植（**唯一の実移植作業**） |
| dispatch / orchestrate の `tmux new-window` + `send-keys` | `herdr agent start` / `agent send` / `wait agent-status` |
| tmux-sidebar picker | 廃止（worktree isolation は CLAUDE.md の指示に移す） |

### 受け入れる機能後退

- **pinned / hidden セッション管理**（tmux-sidebar 独自）
- **graveyard / undo close**（`u` キーで閉じたウィンドウ/セッションを復元）
- ghq 横断の repo fuzzy picker（fish 関数 + `herdr workspace create` で再実装は可能）

### トレードオフ

自作 tmux-sidebar（Go・自分で直せる）を捨てて、v0.7 の外部ツール（Rust・AGPL・upstream 待ち）に依存する。安定性が単純に上がるのではなく、**バグの種類が「自分で直せるもの」から「直せないもの」に変わる**。この取引を許容する判断である。

### 段階

| Phase | 内容 | tmux への影響 |
|---|---|---|
| 0 | herdr 0.7.5 + integration 導入、`configs/herdr/config.toml` 作成、実機検証 | 無傷 |
| 1 | 並走運用（`ghostty --command=herdr` で別ウィンドウ） | 無傷 |
| 2 | URL/PR popup・dispatch・orchestrate を herdr CLI へ移植 | 無傷 |
| 3 | ghostty の `command` を herdr に切替、keybind を直接バインドへ整理 | 切替 |
| 4 | tmux 一式・tmux-sidebar・claude-pane-state.sh・tm/tms/tmw を撤去 | 撤去 |

Phase 0 の結果を本 ADR に追記し、`Spike完了` へ遷移させたうえで Phase 1 以降の可否を判断する。**日本語 IME が実用水準に達しない場合は移行そのものを中止する。**

## Spike の記録

### 2026-08-01: integration 導入で判明した dotfiles 管理との衝突

`herdr integration install <agent>` は hook スクリプトを展開するだけでなく、**エージェントの設定ファイルにも hook 定義を書き込む**。

- `~/.claude/settings.json`（実ファイル）: `SessionStart` に `herdr-agent-state.sh session` を 1 件追加。既存 hook は全て保持されたが、JSON のキー順がソートされ末尾改行が失われる
- `~/.codex/hooks.json`（**dotfiles への symlink**）: herdr は symlink を追跡し、**dotfiles の実体 `configs/codex/hooks.json` を書き換える**

対策として以下を入れた:

1. `configs/herdr/setup.sh` は `herdr integration status` が `current` を返す間は install を実行しない（実行のたびに JSON を書き直して差分ノイズを出すため）。`status` の行頭は `<agent>: current (vN)` 形式で、`installed` ではない
2. install 直後に `~/.codex/hooks.json` / `~/.claude/settings.json` の末尾改行を補う
3. manifest の profile 順で `herdr` を `claude` / `codex` の **後** に置く。逆順だと新規マシンで `~/.claude/settings.json` が存在しないまま herdr が生成してしまい、`if_missing: true` の copy がスキップされて dotfiles の設定が反映されない事故になる

Phase 4 で tmux-sidebar の hook（`tmux-sidebar hook ... --kind codex`, `agent-pane-state.sh`）を撤去する際は、この herdr hook だけが残る形になる。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-076 セクション）
