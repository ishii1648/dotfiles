# ADR-078: SSH 接続中は herdr のタブラベルを接続先ホストにする

## ステータス

Draft

## 関連 ADR

- 依存: [ADR-076](076-herdr-migration-from-tmux.md)（tmux から herdr へ移行。Phase 4 で fish 関数 `ssh`（リモート tmux 自動アタッチ）を撤去した — 本 ADR は同じファイル名で別目的のラッパを新設する）

## コンテキスト

herdr のタブラベルは作成時の連番（`1`, `2`, …）のままで、ペインの中で何が動いているかは表示されない。ssh でリモートに入っているタブと手元で作業しているタブが見分けられず、タブを 1 つずつ覗いて確認する必要がある。

herdr 0.7.5 を調べた結果、この用途に使える組み込み機能は無い。

- `herdr --default-config` と公式 [config reference](https://herdr.dev/docs/config-reference/) にタブラベルの自動命名・ターミナルタイトル追従の設定は存在しない。タブ関連の設定は `keys.new_tab` / `keys.rename_tab` / `ui.hide_tab_bar_when_single_tab` / `ui.prompt_new_tab_name` のみ。
- ペインの OSC タイトルは `pane list` の `terminal_title` / `terminal_title_stripped` として API には出ているが、タブラベルには反映されない。サイドバーの `[ui.sidebar.agents] rows` には出せるものの、これはエージェント行の表示であってタブバーではない。
- 一方で、ペインの中には `HERDR_TAB_ID` / `HERDR_PANE_ID` / `HERDR_SOCKET_PATH` が入っており、シェルから `herdr tab rename $HERDR_TAB_ID <label>` を呼べる（実機で自タブをリネーム → 復元して確認済み）。

## 設計案

### 案A: fish の `ssh` ラッパから `herdr tab rename` を呼ぶ（採用）

- `ssh` を fish 関数でラップし、接続先ホスト名を引数から取り出して `<色付きアイコン> <host>` にリネームする
- 元のラベルは `herdr tab get` で控えておき、ssh 終了後に書き戻す
- `HERDR_TAB_ID` が無い環境（herdr の外、remote プロファイルの fish など）では何もせず素の `ssh` に委譲する

採用理由:

- タブバーに直接出る唯一の手段（他の案はタブバーに出ないか、実装コストが見合わない）
- 追加コンポーネント無し。fish 関数 3 本 + conf.d 1 本で完結し、herdr 本体の更新に追従しやすい
- tmux 時代にも `ssh` の fish ラッパ（リモート tmux 自動アタッチ、ADR-022）を持っていた前例があり、引数解析はその実装を流用できる

### 案B: `herdr pane rename` でペインに名前を付ける（却下）

却下理由: `--clear` があり復元は確実だが、表示先はペイン境界であってタブバーではない。分割していないタブでは境界自体が出ないため、単一ペインで ssh する通常ケースで何も見えない。

### 案C: herdr プラグインで `terminal_title` をタブラベルに自動追従させる（見送り）

`herdr plugin` にはマニフェストの `[[events]]` でイベント発火時にコマンドを実行する仕組みがあり、`pane.updated`（`terminal_title_stripped` の変化で発行される）を拾って `tab.rename` を呼ぶことは理屈上できる。ssh に限らず任意のコマンドを識別できる点で汎用的。

見送り理由: 公式ドキュメントが「起動フックは一度きりの初期化であり監視デーモンではない」「ランタイムでのアクション登録は v1 では未サポート」と明記しており、常駐相当の実現可否が読み切れない。まず案 A で運用し、対象を ssh 以外にも広げたくなった時点で再検討する。

### 案D: `fish_title` で OSC タイトルを整える（却下）

却下理由: herdr はターミナルタイトルをタブラベルに反映しない（コンテキスト参照）。加えて ssh 中のタイトルはリモート側のシェルが出すため、ローカルの `fish_title` では制御できない。

## 設計上の判断

- **復元は `fish_prompt` イベントに一本化する** — fish は前景ジョブが SIGINT で終了すると関数の残りを実行しない（`function f; command sleep 5; echo AFTER; end` に SIGINT を送ると `AFTER` が出ないことを実測）。ssh 関数の末尾で書き戻す実装だと、接続待ちに Ctrl-C した場合にラベルが `🔵 host` のまま残る。そのためラッパ側は「元ラベルをグローバル変数に保存してリネームする」だけにし、書き戻しは次のプロンプト描画時のイベントハンドラで行う。Ctrl-C でも正常終了でも必ずプロンプトが出るので、経路が 1 本で済む。
- **元ラベルは保存する（クリアでは戻らない）** — `herdr tab rename <id> ""` は `label: ""` になるだけで、自動採番のラベルには戻らない（実測）。`tab rename` に `pane rename` のような `--clear` は無い。よってリネーム前の `herdr tab get` の `label` を控えて書き戻す。
- **1 コマンドラインで複数 ssh を続けた場合は最初の元ラベルを保つ** — `ssh a; ssh b` ではプロンプトが最後に 1 度しか出ない。保存済みの変数があるときは上書きしないことで、最終的に本来のラベルへ戻る。
- **ホスト名は「値を取るオプションを飛ばした最初の非オプション引数」** — ADR-022 版 `ssh.fish` と同じ解析。`user@host` の `user@` は表示上のノイズなので落とす。ホストが取れなければリネームせず素通しする。
- **リモートコマンド付きの `ssh host cmd` も一律リネームする** — 対話接続かどうかの判定を持つと解析が増える割に、得られるのは「一瞬ラベルが変わって戻るのを避けられる」だけ。実害が無いので判定は持たない。
- **`herdr` CLI の失敗は握り潰す** — サーバ停止中などで `tab rename` が失敗しても ssh 自体は成功させたい。リネーム系の呼び出しはすべて出力・終了ステータスを捨てる。
- **色は絵文字で出す（ANSI エスケープは使えない）** — タブを色分けできれば一番分かりやすいが、herdr にその手段が無い。`[theme]` / `[theme.custom]` はテーマ全体の色トークンを差し替えるだけで、タブ個別の色は指定できない。`tab rename` に ANSI エスケープ入りの文字列を渡すと `herdr tab get` ではそのまま保存されるものの、タブバーは制御文字として解釈せず表示が崩れる（実機確認）。色付き絵文字（🔴🟠🟡🟢🔵🟣）は崩れずに描画されるため、これをラベル先頭に置く。
- **アイコンはホスト名から決定的に選ぶ** — 固定色だと「ssh 中かどうか」しか分からない。ホスト名の `cksum` で 6 色から選ぶことで、同じホストは常に同じ色、別ホストは別の色になりやすくなり、複数ホストへ同時に繋いだときにタブを見分けられる。`cksum` は POSIX 由来でどの環境にもあり、`md5` / `md5sum` のような macOS と Linux の差も無い。
- **ヘルパー関数名は `_` 始まり（`__` は使えない）** — `.gitignore` に `configs/fish/functions/__*` があり、`__` 始まりのファイルは git 管理外になる。ローカルでは動くが clone 先には配布されず、CI（`tests/Dockerfile`）でも存在しない。既存の `_fzf_*` と同じくアンダースコア 1 つに揃える。なお ADR-076 で撤去した `tm` 系のテストが `__tm_session_name.fish` を参照したまま残っていたのも同じ理由で、本 ADR の実装に合わせて削除した。

## 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/fish/functions/ssh.fish` | 新規。ホスト名を取り出してタブをリネームし、素の `ssh` に委譲 |
| `configs/fish/functions/_ssh_tab_host.fish` | 新規。ssh の引数から接続先ホスト名を取り出す（単体テスト対象） |
| `configs/fish/functions/_ssh_tab_icon.fish` | 新規。ホスト名から色付きアイコンを決める（単体テスト対象） |
| `configs/fish/conf.d/herdr-ssh-tab.fish` | 新規。`fish_prompt` イベントで元のタブラベルへ書き戻す |
| `configs/fish/setup.sh` | conf.d の symlink 対象に `herdr-ssh-tab.fish` を追加 |
| `tests/fish-functions.bats` | `_ssh_tab_host` の引数解析と `_ssh_tab_icon` のアイコン選択テストを追加。撤去済み `__tm_session_name` のテスト 3 件を削除 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-078 セクション）
