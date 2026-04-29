# ADR-065: dispatch 経由の codex 起動を attached client が来るまで遅延させる

## ステータス
採用済み

## 関連 ADR
- 依存: ADR-062（`dispatch.sh launch --launcher codex` の起動経路を確立）
- 関連: ADR-061（popup ランチャーの codex モード）

## コンテキスト

popup ランチャー（`prefix+S`）の codex モードから dispatch.sh 経由で codex を起動すると、codex TUI の入力エリア（prompt textarea）に背景色（`SGR 48;2;51;53;67`）が描画されないまま起動する。応答処理を 1 往復 LLM に通すと再描画イベントで色が出るが、起動直後・応答中断のままだと「色が抜けたプレーンな表示」が続く。

調査の結果、原因は upstream の挙動に行き着いた：

- codex TUI は起動時に **OSC 11**（背景色 query）を outer terminal に送り、入力エリアの色をその応答から計算している
- tmux 3.4+ は OSC 11 query を **attached client** に passthrough する（[tmux a41a92744](https://github.com/tmux/tmux/commit/a41a92744188ec5c8a8d4ddc100ec15b52d04603)）。attached client が無い場合は応答が返らない
- 既知 issue: [openai/codex#4744](https://github.com/openai/codex/issues/4744)（tmux バージョン古いと再現、3.4+ で解消）

`dispatch.sh` は `tmux new-session -d`（detached）で session を作り、`sleep 0.5` 後に即 `tmux send-keys` で codex を起動する。この時点では新 session に attached client が居ないため、codex の起動時 OSC 11 query が解決できず「背景色不明」モードで TUI が初期化される。後からユーザが session に attach してきても、codex は再 query しないため色は出ないまま固定される。

検証で観察した事実：

| pane | 状態 | 入力エリア背景色 ESC |
|---|---|---|
| dispatch 経由・起動直後（中断のみ） | attached なしで codex 初期化 | **なし** |
| dispatch 経由・LLM 応答完了後 | 応答処理中の再描画で色が解決 | **あり** `[48;2;51;53;67m` |

ユーザの client は dispatch 完了後に新 session に switch するフロー（dispatch_launcher は `switch-client` を呼ばない）であり、attach タイミングは「codex 起動後」になる。これが恒常的に「背景色なし」を引き起こしている。

claude では同様の問題が観測されない（OSC 11 query を起動時に使っていない、または応答待ちをしないため）。

## 設計案

### 案A: dispatch.sh で codex 起動時のみ attached client を待機してから send-keys（採用）

`dispatch.sh` の `cmd_launch` 内、`sleep 0.5` の後・`send-keys` の前に、launcher が `codex` の場合のみ「target session に attached client が来るまで待機する」ロジックを追加する：

- `tmux list-clients -t "=$session_name"` の出力行数を 0.5 秒間隔でポーリング
- 行数が 1 以上になったら待機を抜けて `send-keys`
- 上限は 600 反復（300 秒 = 5 分）でタイムアウトし、それでも send-keys を実行（永久ハング防止）

ユーザの操作モデルは「popup → ghq repo 選択 → prompt 入力 → Enter → 自分で session に switch する」のままで変わらず、codex の起動だけが「ユーザが switch して attach した瞬間」に開始されるようになる。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/skills/dispatch/dispatch.sh` | dotfiles | codex launcher 用に attached client 待機ループを追加 |
| `~/.claude/skills/dispatch/dispatch.sh` | dotfiles 配布先 | symlink 経由で自動反映（編集不要） |
| `docs/issues.md` | dotfiles | 受け入れ条件追記 |

### 案B: `tmux new-session -d` の直後に `tmux switch-client -t <session>` で強制 attach（却下）

popup を閉じた直後にユーザの client を新 session に切り替える案。

却下理由：

- popup 直後に画面が切り替わる UX 変化が大きく、複数 dispatch を連投したいケースで作業フローが破壊される
- `dispatch_launcher.fish` が意図的に `switch-client` を呼ばず「ユーザが任意で切り替える」設計になっており（issues.md「dispatch 後フォーカス自動遷移」課題と整合）、その方針と矛盾する
- orchestrate 等、別 caller が同じ dispatch.sh を使う将来の拡張で副作用が広がる

### 案C: codex 起動コマンドに `Ctrl+L` などの再描画トリガを送る（却下）

`send-keys` 後に短い sleep を挟んで `C-l` を送り、codex に再描画させる案。

却下理由：

- codex TUI が `Ctrl+L` で必ず OSC 11 を再 query するかは未保証（codex の内部実装依存）
- 仮に動いても「attached client が居ない」根本原因は変わらず、最初の query 失敗後に再 query で復旧する hack に過ぎない
- 「attach されてから起動する」案A の方が因果として素直で、副作用が小さい

### 案D: codex 側で fallback の入力エリア色を持つよう upstream に依頼（却下）

`openai/codex` に issue で報告して TUI 側で対応してもらう案。

却下理由：

- 実装まで時間がかかる、または採択されない可能性がある
- ローカル側の dispatch 設計で完結できる問題なので外部依存を増やす意味が薄い
- ただし関連 issue は既に [#4744](https://github.com/openai/codex/issues/4744) として報告・closed 済みであり、tmux 3.4+ の前提では「attach 状態で起動する」が回答方針として確立している

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-065 セクション）
