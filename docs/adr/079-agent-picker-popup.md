# ADR-079: navigate mode を spaces / agents に分けられないため、agents 側を自前ピッカーで補う

## ステータス

Draft

## 関連 ADR

- 依存: [ADR-076](076-herdr-migration-from-tmux.md)（tmux から herdr へ移行し、セッション横断のナビゲーションを `focus_agent` / `workspace_picker` / `goto` に割り当てた決定 — 本 ADR はその欠けている部分を補う）
- 経緯: [ADR-050](050-tmux-split-window-fish-sidebar.md) / [ADR-046](046-statusbar-popup-role-separation.md) の `claude-session-switch`（tmux 時代は一覧を辿ってセッションを選べた）
- 型を踏襲: [ADR-077](077-new-workspace-ghq-picker.md)（`[[keys.command]]` の popup + fzf でピッカーを実装する構成）

## コンテキスト

herdr のサイドバーは spaces（workspace）と agents の 2 セクションに分かれて表示される（`[ui.sidebar.spaces]` / `[ui.sidebar.agents]`）。一方でキーボードから一覧を辿る手段は次の 3 つしかない。

| 手段 | 対象 | 割り当て |
|---|---|---|
| `workspace_picker` | spaces のみ | `prefix+s` = Cmd+S |
| `goto`（navigate mode / 内部名 `OpenNavigator`） | workspace とペインのツリー | `prefix+g` = Cmd+G |
| `focus_agent` | agents（番号指定、1..9） | `prefix+alt+1..9` |

**navigate mode を spaces と agents に分ける設定は存在しない**。根拠:

- `herdr --default-config` のキー一覧に navigate mode を開くアクションは `goto` 1 つしかなく、対象を絞るオプションも無い
- herdr バイナリ内のアクション enum（`strings` で確認）は `...ToggleSidebar, CyclePaneNext, CyclePanePrevious, ReloadConfig, OpenNotificationTarget, OpenNavigator` で打ち止めで、`FocusSidebar` 相当は無い。`toggle_sidebar` は表示/非表示のトグルのみでフォーカスは移らない
- `navigate_workspace_up/down` / `navigate_pane_left/…` は「navigate mode を開いた後の移動キー」であって、モードの対象を変える設定ではない
- `agent_panel_sort` や `[ui.sidebar.*]` はサイドバーの描画設定で、navigate mode には関与しない

結果として spaces 側は Cmd+S で一覧から選べるのに、**agents 側は「番号を目視してから `prefix+alt+<数字>`」しか無い**。エージェントが 9 個を超えると届かず、番号とエージェントの対応もサイドバーを見て数える必要がある。tmux 時代の `claude-session-switch` が持っていた「一覧を j/k で辿って選ぶ」操作が失われている。

## 設計案

### 案A: `[[keys.command]]` の popup 型で agents 専用の fzf ピッカーを作る（採用）

- Cmd+A（ghostty から `\x00a` = `prefix+a`）に `type = "popup"` のカスタムコマンドを割り当て、`configs/herdr/agent-picker.sh` を起動する
- スクリプトは `herdr api snapshot` から agents / workspaces / tabs を 1 回で取り、`<状態アイコン> <workspace>/<tab>  <agent>  <タイトル>` の一覧を fzf に流す
- 選択したら `herdr agent focus <pane_id>` でそのペインへ飛ぶ
- 一覧の移動は j/k（後述）

採用理由:

- 組み込みの navigate mode を分割する手段が無い以上、agents 専用の一覧は外から作るしかない
- popup は「セッションモーダルな端末を開き、コマンドが終わるまで全入力（Esc 含む）を受け取る」仕様で fzf をそのまま動かせる（ADR-077 で実績あり）
- `herdr agent list` / `herdr agent focus` が socket API 経由で提供されており、workspace を跨いだ一覧とフォーカス移動が CLI だけで完結する
- 表示内容を `[ui.sidebar.agents].rows` に寄せられるため、サイドバーの見え方と揃えられる

### 案B: `next_agent` / `previous_agent` を bind する（却下）

herdr には未バインドの `next_agent` / `previous_agent` が存在する。

却下理由: 一覧を見ずに隣へ移るだけで、「どこに何があるか」が分からない。目的のエージェントに着くまで prefix を押し直しながら複数回叩く必要があり（herdr の prefix モードに tmux の `bind -r` に相当する連打機能は無い）、エージェントが増えるほど当たらなくなる。案 A のピッカーが上位互換になる。

### 案C: `focus_agent`（`prefix+alt+1..9`）で足りるとみなす（却下）

却下理由: 現状これしか無く、それが課題そのもの。番号をサイドバーで目視してから押す必要があり、10 個目以降には到達できない。

### 案D: 上流に navigate mode の分割を要望する（見送り）

見送り理由: 対応を待つ必要があり、確実性が無い。案 A で完全に代替できるうえ、herdr 本体の更新にも追従しやすい。

## 設計上の判断

- **絞り込みではなく j/k を取る**: fzf は検索欄がある限り `j` / `k` を打つと絞り込み文字列として消費されるため、`--bind 'j:down,k:up'` と入力欄は両立しない。`--no-input`（fzf 0.68）で検索欄ごと隠し、j/k を移動に割り当てる。実測で `jj` → 3 行目、`G` → 末尾、`Gk` → 1 つ上、任意の文字列（`abc`）を打っても選択行が動かない（絞り込みが起きない）ことを確認した。エージェント数はサイドバーに収まる規模で、絞り込みより j/k の一貫性を優先する（ユーザー選択）。補助として `g`/`G`（先頭/末尾）、`Ctrl+D`/`Ctrl+U`（半画面）、`q`（キャンセル）も割り当てる。
- **バインド先は `prefix+a`（小文字）**: herdr は端末から届いたリテラル大文字を shift 付きとして解釈しない（ADR-077 / close_workspace で判明済み）。ghostty から到達させるアクションは `prefix+<小文字>` に限る。`prefix+a` は herdr 既定でも本 config でも未使用。
- **ghostty の `super+a=select_all` を潰すことは許容する**: ghostty にアプリ別・条件別のキーバインドは無いため、Cmd+A は herdr 以外のウィンドウでも全選択でなくなる。herdr セッションでは `[ui] copy_on_select = true` と `copy_mode`（Cmd+I）があり、全選択の用途は薄いと判断した。
- **データ源は `herdr api snapshot` 1 回**: `herdr agent list` は `workspace_id` / `tab_id` しか返さず、表示用のラベルを別途引く必要がある。`api snapshot` は `agents` / `workspaces` / `tabs` を 1 レスポンスで返すため、jq で join すれば呼び出しは 1 回で済む。
- **状態アイコンは自前で描く**: popup は herdr の描画層の外なので、サイドバーの `state_icon` トークンを再利用する手段が無い。`agent_status`（`working` / `idle` / `blocked` / `waiting` / `attention` / `starting` / `exited` / `unknown`）に ANSI 色付きの記号を割り当て、フォーカス中のエージェントには `▸` を付ける。
- **`pane_id` は行に埋めて隠す**: 表示行に ID を出すと邪魔なので、`<pane_id>\t<表示行>` の TSV にして fzf の `--with-nth=2..` で 2 列目以降だけを見せる。選択結果から 1 列目を取り出して `herdr agent focus` に渡す。
- **エラー処理は ADR-077 と同型**: PATH / `AQUA_GLOBAL_CONFIG` の明示補強、fzf の終了コードを「1・130 のみキャンセル、それ以外は異常」として扱う、失敗時は popup をキー入力待ちで保持しつつ `$XDG_STATE_HOME/herdr/agent-picker.log` に残す。エージェントが 0 件のときも同様に一瞬で閉じず、メッセージを出して待つ。

## 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/herdr/agent-picker.sh` | 新規。`herdr api snapshot` → fzf（j/k）→ `herdr agent focus` |
| `configs/herdr/config.toml` | `prefix+a` に `[[keys.command]]`（popup）を追加 |
| `configs/ghostty/config` | `super+a=text:\x00a` を追加（組み込みの `select_all` を上書き） |
| `scripts/setup-manifest.yml` | `~/.local/bin/herdr-agent-picker` の symlink を herdr コンポーネントに追加 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-079 セクション）
