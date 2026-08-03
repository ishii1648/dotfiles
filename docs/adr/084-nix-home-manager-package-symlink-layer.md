# ADR-084: Nix (home-manager) をパッケージ導入と静的 symlink 配置の層として限定導入する

## ステータス

Spike中

## 関連 ADR

- 依存: [ADR-018](018-unified-setup-command.md) — `setup.sh` + `setup-manifest.yml` による宣言的セットアップを前提とし、その下層を Nix に譲る
- 関連: [ADR-015](015-claude-settings-json-base-local-merge.md) [ADR-027](027-config-copy-validate-pattern.md) [ADR-041](041-settings-json-managed-keys-sync.md) — mutable な設定ファイルを copies/validate/managed-keys で扱うパターン。Nix に載らない責務の根拠
- 関連: [ADR-019](019-dotfiles-linux-support-and-e2e-testing.md) — Linux Docker e2e。本 ADR のスコープ外に置く根拠
- 関連: [ADR-032](032-setup-sh-modularization.md) — `scripts/lib/` の分割構造

## コンテキスト

2026-07-17 に Nix の全面導入を検討し、以下の4点を理由に却下した（ADR 化されておらず、セッションログにのみ残っていた）。

1. ghostty のような GUI アプリは Homebrew cask が必要で、Nix と Homebrew の二重管理になる
2. aqua が既に宣言的・checksum 付きの CLI 管理を提供しており re-invent する理由がない
3. Nix 言語の学習・保守コストが1人運用の dotfiles に見合わない
4. 既存の Docker e2e で cross-platform 動作は担保済みで、determinism が追加で解決する痛みがない

このうち **理由 1 は現時点で成立しない**。nixpkgs の `ghostty` は Darwin で broken のままだが、公式 .dmg を再パッケージした `ghostty-bin` が nixpkgs にあり、nix-homebrew 経由で cask を宣言的に扱う手段もある（実際この Mac の Homebrew cask は obsidian のみで、ghostty は既に cask 管理外である）。**理由 3 も、記述コストを coding agent が吸収するため弱い**。

一方、`setup.sh` 系（`scripts/setup.sh` 277行 + `scripts/lib/*` 406行 + `configs/*/setup*.sh` 805行 = 約 1,490行）を責務で分類すると、Nix が置換できるのは全体の半分弱にとどまる。

**Nix に載る（約 600〜700行）**

- 静的 symlink 配置（manifest の `symlinks`、fish/claude の個別 symlink 生成ループ）
- Homebrew パッケージ導入（`scripts/lib/deps-macos.sh`）
- launchd agent 登録
- manifest 整合性検証（Phase 1 の target 実在チェック — Nix では eval 時に落ちるため検証コード自体が不要になる）
- profile 分岐（homeConfigurations を複数持てば表現できる）

**Nix に載らない、または載せると悪化する（約 700〜800行）**

| 責務 | 該当 | 理由 |
|---|---|---|
| `~/.claude/settings.json` の managed-keys sync | `configs/claude/setup.sh` | Claude Code 自身と `herdr integration install` が実行時に書き換える。home-manager の管理ファイルは /nix/store への read-only symlink なので不可能。「`hooks`/`statusLine` は上書き、`env` はマージ、ローカル固有キーは保持」という部分マージのセマンティクスも Nix にはない |
| herdr 本体の導入・更新 | `configs/herdr/setup.sh` | 公式 install script 経由でないと `herdr update` が使えない（同ファイル冒頭のコメント参照） |
| `~/.codex/hooks.json` | `configs/codex/setup.sh` | herdr が symlink を辿って dotfiles の実体を書き換える |
| codex CLI | `configs/codex/setup.sh` | `npm install -g` で自己更新する |
| SSH 鍵・`git config --global` | `configs/git/setup-github-ssh.sh` | マシン固有の secret と実行時 state。宣言化すべきでない |
| `chsh` / `/etc/shells` | `configs/fish/setup.sh` | sudo が必要な点は Nix でも変わらない |
| aqua 管理下の CLI | `aqua.yaml` | バージョンが外部要件で決まる（後述の棲み分け原則） |

したがって全面移行はしない。**Nix を `setup.sh` の下層（パッケージ導入 + 静的 symlink 配置）に限定導入し、`setup.sh` を「mutable な設定ファイルと外部インストーラの面倒を見る層」に縮退させる。**

## 設計案

### 案A: home-manager standalone を限定導入する（採用）

`$HOME` 配下のみを対象とする home-manager を、既存 `setup.sh` と**共存**させる形で導入する。

**1. 適用範囲は darwin の full profile のみ**

remote / linux profile は `setup.sh` のまま据え置く。Docker e2e（`tests/Dockerfile` の apt ベース）も現状維持。リモートマシンへの /nix 導入コストと、Docker イメージのビルド時間増を Spike 段階で背負わない。

**2. config は `mkOutOfStoreSymlink` で dotfiles の実体を指す**

home-manager の既定（store へコピーして read-only symlink を張る）を採らない。`configs/claude/CLAUDE.md` や `configs/claude/scripts/` の hook スクリプトは日常的に編集するため、store コピーにすると編集のたび `home-manager switch` が必要になり、現在の「dotfiles を直接編集すれば即反映」という運用が壊れる。

**このトレードオフの帰結を明示する: 本 ADR で得られるのは「symlink 定義の宣言化・冪等な適用・generation ロールバック」であって、「config 内容の store による再現性」ではない。** 後者が欲しくなった時点で改めて判断する。

**3. Nix の管理外に残すファイル**

- `~/.config/fish/fish_variables` — fish が `set -U` で実行時に書き換える。symlink 先を read-only にすると壊れる
- `~/.claude/settings.json` / `~/.codex/hooks.json` / `~/.gitconfig` — 上表の通り `setup.sh` の copies / managed-keys sync が引き続き担当
- `~/.claude/skills/` 配下のうち dotfiles 由来でないもの — Claude Code とプラグインが同じディレクトリに書き込むため、ディレクトリごとではなく dotfiles 由来の skill だけを個別に張る（現行 `configs/claude/setup.sh` の挙動を踏襲）

**4. GNU tools は Homebrew に残す**

現状 `ggrep` / `gsed` / `gtar` / `gawk` / `gfind` / `gdate` という g-prefix で BSD 版と共存させている（グローバル CLAUDE.md が BSD 前提の環境であることを明記している）。nixpkgs の `gnugrep` 等は `grep` という名前で PATH に入り BSD 版を上書きするため、共存させるには自前のラッパー生成が必要になる。ここは Homebrew の方が素直で、無理に移す利益がない。

**5. aqua との棲み分け原則**

> **バージョンが外部要件で決まるツールは aqua、最新でよいツールと OS レベルのパッケージは Nix。**

- **aqua に残す**: terraform / kubectl / istioctl / helm / helmfile / k9s / kubectx / kubens / stern / kubebuilder / knative client / kwokctl / kind。nixpkgs はパッケージのバージョンが flake の nixpkgs revision に紐づくため、個別ツールだけを特定バージョンに固定するには「そのバージョンを含む古い revision を別 input として持つ」か overlay で自作 derivation を書く必要があり、13個分は現実的でない。Renovate によるバージョン更新 PR も失われる
- **Nix が持つ**: 現在 Homebrew が入れている OS レベルのパッケージと GUI アプリ
- **動かさない**: `aqua.yaml` の「最新でよい」系（fzf / fd / ripgrep / zoxide / gh / yq / sops / age / envsubst / node / go）。困っていないものを移す理由がない

両者の責務が重ならないため、これは二重管理ではなく分業である。**Nix 導入は aqua 廃止を意味しない。**

**6. 段階導入と撤退可能性**

| Phase | 内容 | 本 ADR のスコープ |
|---|---|---|
| A | home-manager standalone 導入。静的 symlink を Nix 側にも定義し、`setup.sh` と共存させる。パッケージは neovim / jq / ghostty-bin から始める | ○ |
| B | `setup-manifest.yml` / `configs/fish/setup.sh` から移管済み symlink を削除。fish 本体を Nix へ（`chsh` 経路の切替を伴う） | × |
| C | docker / colima（VM 状態を持つため慎重に）、remote / linux profile への展開 | × |

Phase A では既存の symlink 定義を**一切削らない**。同じリンクを両者が主張する状態を作り、`home-manager switch` と `setup.sh --dry-run` の両方が OK になることを確認してから Phase B に進む。Nix 側が壊れても `setup.sh` 単独で従来通り動く状態を保つのが、この段階の設計目標である。

fish 本体を Phase A に含めないのは、Homebrew 版と Nix 版が PATH 上で混在すると `fish_variables` のフォーマットや `fish_plugins` の解決が壊れうるためで、シェル本体の差し替えは symlink 層の検証が終わってから単独で扱う。

### 案B: nix-darwin でシステム全体を宣言化する（却下）

`/etc`・system level launchd・`sudo` を握るため既存 `setup.sh` との共存が難しく、remote / linux profile にも適用できない。「Homebrew を置き換える」という目的に対して過剰であり、撤退コストも大きい。

### 案C: Nix への全面移行（却下）

上表の通り、`setup.sh` の残り 700〜800行は Nix に載らないため activation script として Nix の内側に bash のまま埋め込まれる。「Nix を読み、その中の bash を読む」二層構造になり、現在の「bash を読めば全部わかる」状態よりデバッグ体験が悪化する。coding agent は記述コストを吸収できるが、ログイン環境が壊れたときの障害コストは吸収しない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `flake.nix` | dotfiles | 新規。nixpkgs + home-manager の input と `homeConfigurations` |
| `nix/home.nix` | dotfiles | 新規。`home.packages` と `home.file`（`mkOutOfStoreSymlink`） |
| `nix/symlinks.nix` | dotfiles | 新規。symlink 定義（`setup-manifest.yml` の該当部分に対応） |
| `nix/check-parity.py` | dotfiles | 新規。`nix/symlinks.nix` と既存 setup 定義の symlink が同一パス・同一ターゲットであることを検証する（共存の判定手段であり、Phase B で manifest 側を削除する際の安全網） |
| `.gitignore` | dotfiles | `result` / `result-*`（nix build の成果物）を追加 |
| `README.md` | dotfiles | Nix レイヤの導入手順と責務分担 |
| `docs/reference.md` | dotfiles | ツールスタック表に Nix を追加、setup.sh との責務分担を記載 |

## Spike の知見（Phase A 実施時に判明したこと）

検証環境: Determinate Nix 3.21.9 (Nix 2.34.8) / nixpkgs 104240a (2026-08-03) / home-manager bf9ce9f (2026-07-31) / aarch64-darwin。

**1. eval とビルドは通る**

`nix eval` および `nix build .#homeConfigurations."sho@darwin".activationPackage` が成功し、`ghostty-bin` も含めて解決できた。生成物を検査した結果、意図通り以下が確認できた。

- `mkOutOfStoreSymlink` の指す先が dotfiles clone の実体になっている
- `fish_variables` / `settings.json` / `hooks.json` / `.gitconfig` は生成物に含まれない
- `.claude/skills/` 配下は `codex-sync` のみ

**2. `mkOutOfStoreSymlink` は多段リンクになる（要注意）**

生成されるリンクは一段ではなく、`home-manager-files` を経由する三段である。

```
~/.vimrc -> /nix/store/<hash>-home-manager-files/.vimrc
         -> /nix/store/<hash>-hm_vimrc
         -> <dotfiles>/configs/vim/vimrc
```

`setup.sh` の `ensure_symlink`（および `configs/fish/setup.sh` の `check_or_link`、`configs/claude/setup.sh` の skills 判定）は `readlink` の**一段目だけ**を文字列比較していたため、これを `WRONG TARGET` と誤判定する。dry-run では失敗として数え、**非 dry-run では `rm` して張り替えるため Nix 側の symlink を破壊する**。共存の前提が成立しない。

対処として `scripts/lib/path.sh` を追加し、`symlink_points_to`（一段目の文字列一致に加え、最終解決先の一致も許容する）で判定するよう 3 箇所を変更した。`realpath` は macOS (`/bin/realpath`) と Docker の Linux 双方に存在し、無い場合は python3 にフォールバックする。

**3. dry-run の "skipped" は衝突チェック段階の表示にすぎない（判断を誤りやすい）**

`activate` の dry-run では、対象 53 本すべてが以下のように報告される。

```
Existing file '/Users/sho/.config/nvim' is in the way of '.../home-manager-files/.config/nvim',
will be skipped since they are the same
```

これは `checkLinkTargets` フェーズ（衝突するファイルをバックアップ・退避すべきか判定する段階）の出力であり、「既存と同一だからバックアップ不要」という意味でしかない。後続の `linkGeneration` フェーズは、既存リンクを**すべて Nix 管理のリンクに置き換える**。実際に activate したところ、`setup.sh` が張っていた 53 本すべてが `home-manager-files` 経由の三段リンクに変わった。

**dry-run の出力から「symlink は変更されない」と読むのは誤りである。** Phase A の switch は無害ではなく、既存リンクの全面的な張り替えを伴う。

**4. Nix 管理外に置いたファイルは実際に無傷だった**

activate 後も `~/.claude/settings.json` / `~/.gitconfig` / `~/.config/fish/fish_variables` は通常ファイルのまま、`~/.codex/hooks.json` は dotfiles への一段 symlink のままで、いずれも Nix に奪われていない。launchd agent（`com.user.worktree-auto-cleanup`）も生存し、fish 4.6.0 の起動と関数読み込みも正常だった。

**5. Nix が張った経路の実効検証（`.vimrc` 先行移管）**

`setup-manifest.yml` の full profile から `vim` を外し、`~/.vimrc` を削除してから activate したところ、Nix が三段リンクを張り、`realpath` が dotfiles clone の実体に解決することを確認した。この状態で修正後の `symlink_points_to` は「同一」と判定し、修正前の一段比較は `WRONG TARGET` と誤判定する（知見 2 の対処が実際に必要だったことの裏付け）。管理下 53 本すべてについて最終解決先が dotfiles clone 内であることも確認済み。

**6. `fish_variables` は setup.sh 側でも symlink 管理できていなかった**

移管後に master で `setup.sh --dry-run` を実行したところ、`fish_variables` だけが `NOT A SYMLINK` で失敗した。調査の結果、実機の `~/.config/fish/fish_variables` は **2026-07-05 以降 通常ファイル**（305 bytes）で、dotfiles 側の実体は空ファイルのまま乖離していた。fish は `set -U` のたびに一時ファイルを作って rename するため、symlink が実ファイルに置き換わる。

設計案 A-3 で「`fish_variables` を Nix の管理外に置く」と判断した根拠がそのまま実証された形であり、同じ理由が `setup.sh` にも当てはまる。`configs/fish/setup.sh` の symlink 対象からも外した（Nix 導入以前から存在した不具合で、本 ADR の作業が引き金ではない）。

**7. Phase B では manifest から単純削除できない（profile 出し分けが必要）**

Nix は darwin の full profile のみを対象とするため、`setup-manifest.yml` の `components` を消すと remote / linux profile で symlink が張られなくなる。`.vimrc` の先行移管では `profiles.full` から `vim` を外し、`components.vim` は remote / linux 用に残すことで回避した。`copies` には既に `profile:` フィールドがあるが `symlinks` には無いため、Phase B で全体を移管する際は **`symlinks` にも profile 出し分けを導入するか、full profile 用の manifest を分離する**必要がある。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-084 セクション）
