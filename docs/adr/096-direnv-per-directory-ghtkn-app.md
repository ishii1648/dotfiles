# ADR-096: direnv でディレクトリごとに ghtkn の App を切り替える

## ステータス

採用済み（2026-10-18）

## 関連 ADR

- 依存: ADR-094（ghtkn。`gh` の既定は read の App）
- 関連: ADR-095（board。ワーカーは起点のリポジトリの worktree で Issue・PR・コメントを書く）

## コンテキスト

起点のリポジトリ（この端末では ishii1648/hub）では、マスターとワーカーが Issue の起票・コメント・PR 作成・push を日常的に行う。`gh` の既定は read の App（ADR-094）なので、毎回 `GHTKN_APP=write` / `GHTKN_GIT_APP=write` を付ける必要があり、付け忘れると失敗する。このリポジトリでだけ write を既定にしたい。

ghtkn には、リポジトリやディレクトリごとに App を選ぶ設定が無い。選び方は `GHTKN_APP`（`gh`）と `GHTKN_GIT_APP`（Git）、App の `git_owner(s)` だけで、`git_owner(s)` は Git の credential helper にしか効かず、単位も所有者（hub と dotfiles はどちらも `ishii1648`）なので区別できない。ghtkn の `docs/multiple-apps.md` は、direnv の `.envrc` で `GHTKN_APP` を切り替える方法を示している。

## 設計案

### 案A: direnv の `.envrc` で切り替える（採用）

- direnv を aqua で導入し、fish の `conf.d/direnv.fish` で hook を有効にする
- 起点のリポジトリに `.envrc`（`export GHTKN_APP=write` と `export GHTKN_GIT_APP=write`）を置く。App の名前だけで秘密ではないのでコミットしてよい
- direnv は `.envrc` をパスごとに `direnv allow` しないと読まない。ワーカーの worktree は dispatch のたびに新しいパスにできるので、`~/.config/direnv/direnv.toml` の `[whitelist] prefix` で自動で許可する。対象（起点のリポジトリの clone、Orca の worktree の置き場所）は端末ごとに違うので、`setup-manifest.local.yml` の `components.direnv.setup_args.whitelist_prefix` から setup.sh が生成する
- Claude Code のセッションは起動した fish の環境変数を引き継ぐので、起点のリポジトリで起動したセッションの `gh` と `git push` も write になる

### 案B: dotfiles の `gh` ラッパーが、リポジトリ内の印を見て App を決める（却下）

依存は増えないが、ghtkn に無い自前の仕組みになり、`git push`（credential helper）には別に手当てが要る。

### 案C: 起点のリポジトリの `.claude/settings.json` の `env` に書く（却下）

Claude Code のセッションにしか効かず、人が端末で打つ `gh` と食い違う。

## 結果

- whitelist の prefix に入れたディレクトリの `.envrc` は確認なしで読み込まれる。自分のリポジトリと Orca の worktree の置き場所だけに限る
