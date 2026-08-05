# ADR-087: 新しい tab / workspace を repo の default worktree で開く

## ステータス

Draft

## 関連 ADR

- 依存: [ADR-076](076-herdr-migration-from-tmux.md)（herdr への移行。`[terminal] new_cwd` と `[[keys.command]]` の存在が前提）
- 関連: [ADR-077](077-new-workspace-ghq-picker.md)（Cmd+Shift+S の repo ピッカー。こちらは既に default worktree のみを候補に出している）
- 関連: [ADR-082](082-pin-every-worktree-to-single-branch.md)（worktree と branch を 1:1 に固定する運用。linked worktree に居る時間が長い前提を作っている）
- 関連: [ADR-086](086-herdr-new-workspace-auto-claude-launch.md)（同じ `[[keys.command]]` 層での workspace 作成時の振る舞い）

## コンテキスト

herdr の `[terminal] new_cwd = "follow"` により、新しい tab / workspace は呼び出し元ペインの cwd を継承する。

ADR-082 の運用（worktree と branch を 1:1 に保ち、作業ごとに linked worktree を作る）では linked worktree に居る時間が長い。この状態で新しい tab を開くと、その linked worktree が cwd になる。しかし新しい tab を開く動機は「repo 本体で別の作業を始める」ことが主で、直前の作業ブランチを引き継ぎたいわけではない。

`new_cwd` の設定値は `follow` / `home` / `current` / 固定パス の 4 つのみで（`herdr --default-config` で確認）、「repo の default worktree」を表現する選択肢は無い。

なお Cmd+Shift+S の repo ピッカー（ADR-077）は `.git` がディレクトリのものだけを候補にしているため、この経路で作る workspace は既に default worktree になっている。本 ADR で扱うのは残る 2 経路（組み込みの `new_tab` / `new_workspace`）である。

## 設計案

### 案A: `new_tab` / `new_workspace` を `[[keys.command]]` に差し替える（採用）

組み込みアクションのキーバインドを空文字にして無効化し、同じキーに `type = "shell"` のカスタムコマンドを割り当てる。スクリプトが呼び出し元ペインの cwd から default worktree を解決し、`herdr tab create --cwd` / `herdr workspace create --cwd` を明示的に呼ぶ。

採用理由:

- `--cwd` を明示すれば `new_cwd` のポリシーを経路ごとに上書きできる。`new_cwd = "follow"` 自体は pane 分割で有効なままにできる（分割は「今の作業の続き」なので継承が正しい）
- 既存の `[[keys.command]]` 3 本（ADR-077/079）と同じ構成で、追加の依存が無い
- default worktree の解決は `git rev-parse --git-common-dir` 1 コマンドで済む

### 案B: `[terminal] new_cwd` を固定パスにする（却下）

却下理由: 固定パスは 1 箇所しか指定できず、repo ごとに変わる default worktree を表現できない。

### 案C: fish 側で新規シェル起動時に default worktree へ `cd` する（却下）

却下理由: herdr が把握している pane の cwd と実際のシェルの cwd が食い違い、pane cwd を参照する既存機能（ADR-076 の PR キャッシュ等）と齟齬が出る。また linked worktree でシェルを開きたい正当なケース（pane 分割・`herdr worktree open`）まで巻き込む。

## 設計上の判断

- **解決は `--git-common-dir` の親** — linked worktree からでも共有 `.git`（= default worktree の `.git`）を返すため、その親が default worktree になる。default worktree 自身から呼んだ場合も同じパスに解決されるので冪等。`.git` で終わらない場合（bare repo は repo ディレクトリ自身、submodule は `.git/modules/<name>`）は前提が崩れるため、解決せず呼び出し元の cwd をそのまま使う
- **git 管理外では従来どおり** — repo の外で押した場合は解決に失敗するので、呼び出し元の cwd をそのまま使う（`new_cwd = "follow"` と同じ挙動）
- **呼び出し元 cwd は pane の `cwd` を使う** — `foreground_cwd` は「pane 内の何らかの foreground 子プロセスの cwd」に過ぎず、Claude Code が spawn した MCP サーバーの一時ディレクトリや linked worktree を拾うことが実測で分かっている（ADR-076）。カスタムコマンドには `HERDR_ACTIVE_PANE_CWD` も渡るが、それが `cwd` / `foreground_cwd` のどちらに対応するかは未確認なので、`herdr pane get` の `cwd` を一次情報にし、`HERDR_ACTIVE_PANE_CWD` → `$PWD` の順でフォールバックする
- **`type = "shell"` を使う** — UI を出さない一発コマンドなので popup は不要。detach 実行で TTY を持たないため、`new-workspace.sh` の `die()`（キー入力待ちでエラーを見せる）は使えず、原因追跡はログ（`~/.local/state/herdr/new-default-worktree.log`）に委ねる
- **1 スクリプトを引数で分岐する** — カスタムコマンドの文字列は `/bin/sh -lc` 経由で実行されるため引数を渡せる（公式ドキュメントで確認）。`tab` / `workspace` で共通するのは cwd 解決部分なので、スクリプトを 2 本に分けず引数で切り替える
- **workspace モードは常に新規作成する** — 組み込みの `new_workspace` と同じ挙動を保つ。同名 workspace があれば focus する ADR-077 のピッカーとは意図的に振る舞いが異なる
- **pane 分割は対象外** — `split_vertical` / `split_horizontal` は「今の作業の続きを隣に開く」用途なので、cwd 継承のままが正しい
- **claude の自動起動はしない** — ADR-086 の自動起動は repo ピッカー経由の workspace 作成に紐づく。本 ADR の経路に広げるかは別の判断なので、今回は付けない

## 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/herdr/new-default-worktree.sh` | 新規。pane cwd → default worktree を解決し `tab create` / `workspace create` を呼ぶ |
| `configs/herdr/config.toml` | `new_tab` / `new_workspace` を空文字で無効化し、同じキーに `[[keys.command]]`（`type = "shell"`）を追加 |
| `nix/symlinks.nix` | `~/.local/bin/herdr-new-default-worktree` を追加 |
| `scripts/setup-manifest.yml` | 同上（`nix_managed: true`。remote / linux profile 用） |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-087 セクション）
