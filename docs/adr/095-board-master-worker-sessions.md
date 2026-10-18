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

- Orca の標準機能と Control room（board）で受け持ちを分ける。セッション単位で今その場で対応すべきもの（エージェントの入力待ち・要対応の検知、デスクトップとスマートフォンへの通知、未読、端末への移動）は Orca に任せる。ワーカーは自分の端末で問いを出してターンを終えるだけで、Orca がアイドルへの遷移を検知して通知する。Control room は Issue 単位で、まだセッションが無いもの・セッションをまたぐもの（未着手と起動、依存待ちと自動起動、Epic / Project の階層とフェーズ、進捗の滞り、close 後の片付け）を受け持つ。cross-session messaging は使わない
- Control room の状態は GitHub と worktree の有無だけで決める（判断待ち・レビュー待ち・作業中・依存待ち・未着手・完了）。レビュー待ちは Issue を `Closes` で参照する open な PR から判定する。判断待ちは Issue 単位で人の判断が要るもの（同時に起動待ちになった Task の確認、子 Task がすべて閉じた Epic）だけで、ワーカーの入力待ちは出さない。Orca のエージェント状態（`orca worktree ps` の `agents[].state`）は安定した API と言い切れないので、状態の判定には使わない
- 進捗の時刻は、board の event、Issue と紐付く PR の updatedAt、Orca のワークツリーの lastActivityAt のうち最も新しいものとする
- マスターは起票と計画の窓口だけを担う（起票、Project の分割、Issue をまたぐ判断）。報告の通り道には入らない。起点のリポジトリの main のカードで `claude --permission-mode auto` として開き、`/master` を実行する
- Issue の内容・open / close・PR は GitHub を正とする。ローカルの追記専用ログ `~/.local/state/board/events.jsonl` には、ワーカーを起動した事実（`dispatched` / `started`）だけを `board event` / `board dispatch` で追記する
- `board serve`（LaunchAgent `com.user.board`）がログを 1 秒ごとに読み、GitHub（60 秒ごと）と `orca worktree ps`（10 秒ごと）と合わせて board を作り、`127.0.0.1:7342` から SSE で配信する
- Orca のカードの status は board サーバーだけが書く。未読は Orca が付けるものなので board は触らず、ワーカーのカードのコメントはワーカー自身が書く
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

人が話す相手は 1 つで済むが、マスターのターンがすべてのやりとりの待ち行列になり、人が見るのはマスターの要約だけになる。質問への回答は、文脈を持つワーカー本人に直接伝えるほうが速く、情報も落ちない。代わりに、どのワーカーが人を待っているかを Orca の通知と未読で見えるようにする。

### 案E: ワーカーの確認待ちを board event で記録し、Control room が通知する（却下）

当初はこの形で実装した。ワーカーが `question` / `blocked` / `pr` を記録し、board が確認待ちとして並べて macOS 通知を出す。しかし Orca は同じことを標準機能で、実際のエージェントの状態から行い、スマートフォンにも届く。board の通知は記録を忘れると出ず、Mac にしか届かず、同じ出来事で通知が二重になる。さらに board がカードに `--read` を書いて Orca の未読を消していた。

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
