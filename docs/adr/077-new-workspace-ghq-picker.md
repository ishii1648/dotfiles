# ADR-077: Cmd+Shift+S の workspace 作成に ghq リポジトリピッカーを挟む

## ステータス

Draft

## 関連 ADR

- 依存: [ADR-076](076-herdr-migration-from-tmux.md)（tmux から herdr へ移行し、Cmd+Shift+S を herdr の `new_workspace` に割り当てた決定 — 本 ADR はその起動対象を差し替える）
- 経緯: [ADR-069](069-popup-launcher-tmux-sidebar-new-migration.md) / [ADR-075](075-picker-launch-popup-to-new-window.md)（tmux 時代の Cmd+Shift+S は `tmux-sidebar new` = repo 選択ピッカーだった）

## コンテキスト

tmux 時代の Cmd+Shift+S は `tmux-sidebar new`（ghq リポジトリを選んでセッションを作るピッカー）に割り当てられていた（ADR-069/075）。ADR-076 で herdr へ移行した際、このキーは herdr 組み込みの `new_workspace` アクションに置き換わり、**リポジトリ選択のステップが失われた**。

herdr の `new_workspace` は押した瞬間に workspace を作るだけで、cwd は `[terminal] new_cwd = "follow"` に従って呼び出し元ペインを継承する。`[ui] prompt_new_workspace_name = true` にしても聞かれるのは workspace 名だけで、cwd は選べない。`herdr --default-config` および公式 config reference を確認した限り、リポジトリ選択を挟むフックは存在しない。

結果として「新しい repo で作業を始める」たびに、作られた workspace の中で手で `cd` する運用になっており、tmux 時代より一手増えている。

## 設計案

### 案A: `[[keys.command]]` の popup 型で自前の fzf ピッカーに差し替える（採用）

- `new_workspace` を Cmd+Shift+S から降ろし、herdr 既定の `prefix+shift+n` に残す（cwd 継承で素早く作る用途は温存）
- Cmd+Shift+S の送出先を `\x00S`（= `prefix+shift+s`）から `\x00p`（= `prefix+p`）に変え、そこに `type = "popup"` のカスタムコマンドを割り当てて `configs/herdr/new-workspace.sh` を起動する
- スクリプトは `ghq list -p | fzf` で選ばせ、`herdr workspace create --cwd <repo> --label <basename> --focus` を呼ぶ
- 選んだ repo をカレントディレクトリに持つ workspace が既にある場合は、二重に作らず `herdr workspace focus` する

採用理由:

- herdr の popup は「セッションモーダルな端末を開き、コマンドが終わるまで全入力（Esc 含む）を受け取る」仕様で、fzf のような TUI をそのまま動かせる（公式例が lazygit）
- Cmd+Shift+S という筋肉記憶を壊さない（ghostty が送るシーケンスだけ差し替える）
- `herdr workspace create` は socket API 経由なので、popup の中から呼んでも問題なく効く
- 実装は shell スクリプト 1 本で、herdr 本体の更新に追従しやすい（既存の `open-pr.sh` と同じ構成）

### 案B: `[ui] prompt_new_workspace_name = true` にする（却下）

却下理由: 聞かれるのは名前だけで cwd は変わらない。`cd` する手間はそのまま残るので、課題を解決しない。

### 案C: herdr 本体に repo ピッカーの機能追加を要望する（却下）

却下理由: 上流の対応を待つ必要があり、ghq 前提のディレクトリ規約は個人環境固有で一般化しにくい。案 A で十分に代替できる。

### 案D: ピッカーに worktree 作成の分岐も持たせる（見送り）

herdr には `new_worktree`（`prefix+shift+g`）が既にあり、`herdr worktree create --cwd <repo> --branch <name>` も CLI から呼べる。ただし本 ADR のスコープ（失われた repo 選択の復旧）を超えるため、必要になった時点で別途検討する。

## 設計上の判断

- **バインド先は `prefix+p`（小文字）**: herdr は端末から届いたリテラル大文字を shift 付きとして解釈しない。従来の `super+shift+s=text:\x00S` は herdr 側で `prefix+s` と等価に扱われ、`new_workspace`（`prefix+shift+s`）ではなく `workspace_picker` が開いていた（close_workspace / close_tab で先に判明していた同種の問題）。ghostty から到達させるアクションは `prefix+<小文字>` に限る必要があるため、未使用の `prefix+p`（picker）を割り当て、ghostty 側を `\x00p` に変更する。
- **既存 workspace の判定は「pane の cwd の完全一致」**: `herdr api snapshot` の `panes[].cwd` が選択した repo パスと一致する workspace を既存とみなす。前方一致（配下を含む）にすると worktree（`.claude/worktrees/*` 等）で作業中のペインまで拾ってしまい、repo ルートの workspace を新規に作りたいケースを潰すため、完全一致に限定する。
- **PATH の明示補強**: popup のコマンドは herdr サーバから起動されるため、ログインシェル（fish）の PATH と一致する保証がない。スクリプト先頭で aqua（`fzf`）と homebrew（`ghq`）の bin ディレクトリを PATH に前置する。
- **エラー時はキー入力待ちで止める**: popup はコマンド終了と同時に閉じるため、失敗メッセージが一瞬で消える。`open-pr.sh` と同じくログにも残しつつ、popup 上では任意キー待ちで表示を保持する。

## 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/herdr/new-workspace.sh` | 新規。ghq ピッカー → `herdr workspace create/focus` |
| `configs/herdr/config.toml` | `new_workspace` を `prefix+shift+n` へ移動し、`prefix+p` に `[[keys.command]]`（popup）を追加 |
| `configs/ghostty/config` | `super+shift+s` の送出を `text:\x00S` → `text:\x00p` に変更 |
| `scripts/setup-manifest.yml` | `~/.local/bin/herdr-new-workspace` の symlink を herdr コンポーネントに追加 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-077 セクション）
