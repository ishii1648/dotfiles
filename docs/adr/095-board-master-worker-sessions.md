# ADR-095: master / worker セッションのタスク board を dotfiles に置く

## ステータス

採用済み（2026-10-18）

## 関連 ADR

- 関連: ADR-083（worktree の 72 時間自動削除。dispatch した worktree は Issue が open の間 lock して守る）
- 関連: ADR-092（permissions は配布しない。board 用の allow ルールは起点のリポジトリ側に置く）
- 関連: ADR-094（ghtkn。board サーバーの gh は ghtkn agent から token を受け取る）

## コンテキスト

実作業を Issue ごとの worktree で動くワーカーのセッションに任せ、人がどこで何が起きているかを把握するコストをできるだけゼロに近づけたい。Issue の open / close は GitHub を正とし、進捗は Orca のブラウザで live に見たい。

当初は、人は 1 つの Claude Code セッション（マスター）とだけ話し、ワーカーとのやりとりは cross-session messaging でマスターが中継する形を考えた。しかしマスターは 1 つの会話なので 1 ターンずつしか処理できず、中継・dispatch・状態更新のすべてがマスターのターン待ちになる。人が見るのはマスターの要約なので、各ワーカーが実際に何をしているかも追いづらい。マスターは外部の出来事（PR のマージで Issue が閉じたなど）では起きないので、依存が解けた後続 Task の起動も止まる。

起点のリポジトリ（Issue を起票し worktree を切るリポジトリ）は端末ごとに違う。この端末では ishii1648/hub。

## 設計案

### 案A: board CLI と常駐サーバーを dotfiles に置く（採用）

- 把握と操作の入口は Control room（board）に集める。人の判断が要るワーカーは確認待ちとして並び、macOS 通知も出る。人は「開く」ボタンか通知のクリックでそのワーカーの端末へ飛び（`orca terminal switch`）、直接答える。ワーカーは自分の端末で問いを出して止まり、`board event` で記録する。cross-session messaging は使わない
- マスターは起票と計画の窓口だけを担う（起票、Project の分割、Issue をまたぐ判断）。報告の通り道には入らない。起点のリポジトリの main のカードで `claude --permission-mode auto` として開き、`/master` を実行する
- 状態の正本はローカルの追記専用ログ `~/.local/state/board/events.jsonl`。マスターとワーカーは `board event` で直接追記し、互いを待たない。Issue の内容と open / close は GitHub から読む
- `board serve`（LaunchAgent `com.user.board`）がログを 1 秒ごとに読み、GitHub（60 秒ごと）と `orca worktree ps`（10 秒ごと）と合わせて board を作り、`127.0.0.1:7342` から SSE で配信する
- Orca のカードは board サーバーだけが書く。カードと board の表示が同じ規則で決まり、ずれない
- dispatch は `board dispatch <N>` の 1 コマンド。worktree の作成と lock、Orca の端末でのワーカー起動、`dispatched` の追記を行い、ロックファイルで直列化して 1 つの Issue に 2 つのワーカーが起動しないようにする
- Epic の子 Task は、依存が解けたら board サーバーが自動で dispatch する。5 つ以上が同時に起動待ちになったら起動せず、人の確認を待つ
- research Task の成果物も、起点のリポジトリの `docs/<topic>/` に commit して PR にする。正本を GitHub に揃え、受け入れを PR のマージで表すことで、通常の Task と同じ流れで閉じる
- Issue が閉じたら、board サーバーが `board cleanup` を自動で行う（`.repos/*` を `--force` 無しで remove し、worktree の lock を外す）。commit していない変更があれば止まり、Control room に表示する
- 操作の API は起動ボタンの `POST /api/dispatch/<N>` と「開く」ボタンの `POST /api/open/<N>` だけ。Host・Origin・`Sec-Fetch-Site` と、画面に埋め込んだトークンで、別のページや DNS rebinding からの呼び出しを拒否する
- 起点のリポジトリが端末ごとに違うので、端末をまたいで使う開発環境の道具として dotfiles に置く。起点のリポジトリは `setup-manifest.local.yml` の `components.board.setup_args` で渡し、setup.sh が `~/.config/board/config.json` を書く
- master / worker skill も dotfiles に置く。skill は events.jsonl を直接書かず、必ず `board event` / `board dispatch` を通す。イベントの形を知るのは board だけになる
- 起点のリポジトリには、その中でだけ効く設定（allow ルール、`.gitignore` の `.repos/`）だけを置く
- ファイルの監視は fsnotify を使わず 1 秒ごとのポーリングにする。外部依存を持たずに済み、1 秒の遅れは board の用途では問題にならない

### 案B: 起点のリポジトリ（hub）の `tools/board` に置く（却下）

repo-index の基準（hub 以外で作業するときにも効いてほしいか）では hub になる。しかし起点のリポジトリが端末ごとに変わるうえ、ビルド・PATH への導入・LaunchAgent の登録という dotfiles が既に持つ仕組みを hub に重ねることになる。worktree ごとにソースのコピーができ、ワーカーが呼ぶ `board` の版も曖昧になる。

### 案C: 人はマスターとだけ話し、マスターが中継する（却下）

人が話す相手は 1 つで済むが、マスターのターンがすべてのやりとりの待ち行列になり、人が見るのはマスターの要約だけになる。質問への回答は、文脈を持つワーカー本人に直接伝えるほうが速く、情報も落ちない。代わりに、どのワーカーが人を待っているかを Control room と通知で見えるようにする。

### 案D: 状態をマスターだけが書く（却下）

書き手が 1 つで競合は無いが、マスターのターンがすべての状態遷移の待ち行列になり、並列性が下がる。

### 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `tools/board/` | board 本体（Go、外部依存なし） |
| `configs/board/setup.sh` | ビルド、`config.json` の生成、`board setup` による LaunchAgent の登録 |
| `configs/claude/skills/master/`、`configs/claude/skills/worker/` | master / worker の手順 |
| `scripts/setup-manifest.yml`、`nix/symlinks.nix` | board component と skill の symlink |
| `scripts/setup-manifest.local.yml.example` | `components.board.setup_args` の例 |

## 結果

- aqua の go1.22.2 の内部リンカが出すバイナリは LC_UUID を持たず、macOS 26 の dyld が起動を拒否する。setup.sh は `-ldflags=-linkmode=external` でビルドする。この経路では ld の署名の後に go がバイナリを書き換えて署名が壊れ、起動時に SIGKILL されるため、ビルド後に `codesign -s -` で署名し直す。go を上げたら両方とも外す

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-095 セクション）
