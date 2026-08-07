# ADR-090: herdr agent の permission 待ちをクリックでジャンプできる macOS 通知で知らせる

## ステータス
Draft

## 関連 ADR
- 依存: ADR-076（herdr 移行）— agent 状態検知を herdr に一元化した前提の上に乗る
- 依存: ADR-084（nix home-manager 層）— 通知バイナリ terminal-notifier の導入経路として home.packages を使う
- 関連: ADR-083（worktree launchd 自動削除）— launchd agent 導入の setup.sh パターンとロギング規約（`~/.local/state/`）を踏襲する
- 関連: ADR-003 / ADR-009（tmux 時代の通知クリック遷移・permission ask 対応）— 同じ動機の課題。tmux 前提の実装は herdr 移行で実質失効しており、本 ADR が herdr 環境での後継にあたる

## コンテキスト

claude/codex セッションが permission（承認）待ちで止まっても気づけない。herdr の macOS toast は

1. クリックしても発生元のペイン/タブへ移動できない（herdr は OS 通知にアクションを紐付けない）
2. claude / codex のどちらが待っているのか判別できない

ため `configs/herdr/config.toml` で `[ui.toast] delivery = "off"` にして無効化済み。状態把握はサイドバーの state_icon 頼みで、別アプリ作業中は取りこぼす。

調査（`.outputs/claude/permission-notify-investigation.md`）で確認した事実:

- herdr は claude/codex 両方の「入力待ち」を **`agent_status: blocked`** として一元検知している。claude 側は画面内容ルール（`bash_permission_prompt` = "do you want to proceed?"、`live_blocked_form` = AskUserQuestion/plan 承認系。`~/.local/state/herdr/agent-detection/remote/claude.toml`）、codex 側は integration 配線済みの `permission_request` hook。**permission 待ち ⊂ blocked**（blocked は AskUserQuestion 等の入力待ち全般を含むが、通知目的にはむしろ望ましい）
- `herdr agent list` が JSON で `agent`（claude/codex）・`agent_status`・`pane_id`・`terminal_title` を返し、`herdr agent focus <pane_id>` で任意ペインへジャンプできる。herdr CLI は HERDR 環境変数なし（launchd 環境）でもデフォルトソケットで動作することを実測済み
- herdr 本体（0.7.5）の `[ui.toast]` にはクリックアクションを付ける設定が無く、状態変化フックの config も無い
- Rosetta 未導入の Apple Silicon 環境のため、x86_64 のみのバイナリ配布（vjeantet/alerter の GitHub Releases 等）は動かない。nixpkgs の `terminal-notifier` 2.0.0 は arm64 ネイティブであることをビルドして実測確認済み。aqua 標準 registry にはどちらも無い

## 設計案

### 案A: 第三者プラグイン yankewei/herdr-focus-notify（却下）

blocked/done でクリックジャンプ付き通知を出す既製プラグインで要件をそのまま満たすが、状態変化のたびに走る第三者コード + brew tap 経由の alerter という依存が増える。ユーザ判断により不採用。

### 案B: 自前 watcher（採用）

herdr の既存機構だけを部品に、通知の出し方をこちらで握る最小実装。

- **検知 — `herdr agent list` を 2 秒間隔でポーリング**する常駐 python3 スクリプト。各ツールに個別の hook を仕込まず herdr の `blocked` 状態に一元化する（claude/codex 両対応が 1 箇所で済み、herdr が新 agent に対応すれば自動追従する）
  - 却下: `herdr agent wait --until blocked` — 単一 agent の待ち受けのみで、動的に増減する全 agent の監視には向かない
  - 誤検知対策として **blocked が 2 回連続で観測されたときだけ通知**する（画面ルール検知のフラつきと、ユーザが見ている前で即応答されたケースの空振りを除外。通知遅延は最大 4 秒程度）
- **通知 — terminal-notifier（nixpkgs, arm64 ネイティブ）**。タイトルで `Claude` / `Codex` を判別し、本文にリポジトリ名（cwd basename）とターミナルタイトルを載せる。`-execute` に `herdr agent focus '<pane_id>'` + `open -a Ghostty` を渡し、**通知クリックで該当ペインへジャンプ**する。`-group <pane_id>` で同一ペインの古い通知を置換する
  - 却下: alerter — GitHub Releases が x86_64 のみで Rosetta 必須。brew tap（ソースビルド）は導入経路が増える
  - 却下: `osascript display notification` — クリックアクションを持てない
- **抑制 — 発生元ペインを注視中なら通知しない**。agent の `focused: true` かつ frontmost アプリが Ghostty（`lsappinfo` で判定、TCC 権限不要）の場合はスキップする
- **常駐 — launchd agent（RunAtLoad + StartCalendarInterval 毎分 + flock 単一インスタンスガード）**。ADR-083 と同じ setup.sh 導入パターン、ログは `~/.local/state/herdr/agent-notify.log`。herdr サーバ停止中は接続エラーを検知して長めの間隔で再試行する
  - 却下: `KeepAlive` — 実装時のデプロイ検証で、この macOS（Darwin 25）の launchd が KeepAlive / RunAtLoad の nondemand spawn を `pended nondemand spawn = speculative/inefficient` として無期限に保留し、kill 後の自動再起動が起きないことを実測した（`ProcessType: Interactive` でも回避不可、BTM は enabled/allowed、AC 電源・Low Power Mode オフでも発生）
  - 却下: `StartInterval` — 同様に `pended nondemand spawn = interval` として保留され、120 秒間隔の設定で 200 秒以上待っても発火しなかった（実測）
  - カレンダー spawn（`StartCalendarInterval`）だけは worktree-auto-cleanup（ADR-083）の実績（毎日 04:00 指定、slack 数分以内で毎回発火）で信頼でき、空 dict 指定（全フィールド wildcard = 毎分）+ watcher 側の flock で「死んでいたら次の分で復活」させる。setup.sh は load 直後に `launchctl kickstart` して初回起動の保留も回避する

### 案C: herdr 設定のみ（却下）

`[ui.toast] delivery = "system"` + `open_notification_target`（prefix+o）でキーボードジャンプ。設定 1 行だがクリック遷移と agent 判別という不満点を解決しない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/herdr/agent-notify.py` | dotfiles | 新規 — blocked 遷移を検知して通知する常駐 watcher |
| `configs/herdr/launchd/com.user.herdr-agent-notify.plist` | dotfiles | 新規 — watcher を KeepAlive で常駐させる launchd agent |
| `configs/herdr/setup.sh` | dotfiles | launchd agent 導入ブロック追加（ADR-083 パターン） |
| `nix/symlinks.nix` | dotfiles | `~/.local/bin/herdr-agent-notify` の symlink 追加 |
| `nix/home.nix` | dotfiles | `terminal-notifier` を darwin パッケージに追加 |
| `configs/herdr/config.toml` | dotfiles | `[ui.toast]` コメント更新（クリック遷移は watcher で実現済みと明記） |
| `docs/issues.md` | dotfiles | 受け入れ条件追記 |

## 懸念

- blocked 検知（claude 側）は画面内容のパターンマッチであり、Claude Code の UI 文言変更で検知漏れしうる。検知マニフェストは herdr が `herdr update` で更新するため追従は herdr 任せになる
- terminal-notifier は初回実行時に macOS の通知許可が必要（一度だけ手動で許可する）
- macOS の通知スタイルが「バナー」（既定）だと数秒で消える。permission 待ちを確実に拾うには terminal-notifier の通知スタイルを「通知パネル」に変更するのが望ましい（手動設定）

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-090 セクション）
