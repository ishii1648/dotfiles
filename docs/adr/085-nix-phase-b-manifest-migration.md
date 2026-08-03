# ADR-085: full profile の symlink 定義を setup.sh から home-manager へ移管する（Phase B）

## ステータス

Draft

## 関連 ADR

- 依存: [ADR-084](084-nix-home-manager-package-symlink-layer.md) — Phase A で導入した home-manager レイヤを前提とし、その Phase B/C の内訳を再定義する
- 関連: [ADR-018](018-unified-setup-command.md) — `setup-manifest.yml` のスキーマを拡張する
- 関連: [ADR-012](012-fish-function-symlink-per-repo.md) [ADR-020](020-unify-local-override-into-terminal-repo.md) — 端末固有 fish 関数の扱い

## コンテキスト

ADR-084 Phase A により、静的 symlink 53 本が home-manager と `setup.sh` の**二重定義**になっている。同じリンクを両者が主張する状態は Phase A の検証手段としては正しかったが、恒久的に維持すると片方だけ変更したときに壊れる（`nix/check-parity.py` はこの二重定義がずれていないことを検査するために存在する）。

Phase B の目的は、full profile に限って `setup.sh` 側の symlink 定義を削除し、二重定義を解消することである。ADR-084 の知見 7 で、そのまま削除できない理由が 2 つ判明している。

**1. profile 出し分けができない**

Nix は darwin の full profile のみを対象とする。`setup-manifest.yml` の `components` から symlink を消すと、remote / linux profile でもリンクが張られなくなる。`copies` には既に `profile:` フィールドがあるが `symlinks` には無い。

**2. 端末固有 fish 関数が張られなくなる**

`configs/fish/setup.sh` は実ディレクトリを glob するため `.gitignore` 済みの端末固有関数（`claude.fish` / `fable.fish` / `__*`）も symlink する。flake source は git tracked のみを含むので Nix 側はこれらを張らない。symlink ループを単純に削除すると端末固有関数が失われる。

また ADR-084 の Phase 表は Phase B に「fish 本体を Nix へ」を含めていたが、これは symlink 移管とはリスクの質が異なる（シェル本体の差し替え・`chsh`・`/etc/shells` への sudo 書き込み・fisher プラグインの互換）。本 ADR で Phase C に送る。

## 設計案

### 案A: `symlinks` に `nix_managed` フラグを追加する（採用）

`setup-manifest.yml` の各 symlink エントリに `nix_managed: true` を付けられるようにし、**full profile ではスキップ、それ以外の profile では従来どおり張る**。

```yaml
  nvim:
    symlinks:
      - link: ~/.config/nvim
        target: configs/nvim
        nix_managed: true   # full では home-manager が張る（ADR-085）
```

`copies` の `profile:` と同じ「特定 profile でだけ処理する」意味論ではなく、「Nix が管理するので Nix 対象 profile では setup.sh が触らない」という意図を直接表現する。Phase C で remote / linux にも Nix を広げる際は、この判定に使う profile 集合を増やすだけで済む。

構成要素:

- `scripts/setup.sh` の symlink ループに 3 行の判定を追加する（`copies` の `profile:` 判定と同じ位置）
- `configs/fish/setup.sh` / `configs/claude/setup.sh` は独立起動されるため、`SETUP_PROFILE` 環境変数を `scripts/setup.sh` から渡し、full のときだけ dotfiles 管理分をスキップする
- `configs/fish/setup.sh` の functions ループは `git ls-files` で tracked 判定し、**tracked（＝ dotfiles 管理）は full でスキップ、untracked（＝端末固有）は常に張る**。これにより課題 2 が解消する
- `nix/check-parity.py` は「`nix_managed: true` のエントリが nix 側にも存在すること」を検査する形に変える（現在の `MIGRATED_TO_NIX` ハードコードを廃止）

### 案B: full profile 用の manifest を分離する（却下）

`setup-manifest.full.yml` を別に持つ案。共通部分が重複し、片方だけ更新する事故が起きやすい。二重定義を解消するための変更で別の二重管理を生むため本末転倒。

### 案C: `symlinks` にも `copies` と同じ `profile:` を付ける（却下）

「このプロファイルのときだけ張る」意味論では、full から外すために remote 用と linux 用の 2 エントリを書く必要があり、1 リンクあたり 3 倍に膨れる。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `scripts/setup-manifest.yml` | dotfiles | 移管対象の symlink に `nix_managed: true` を付与 |
| `scripts/setup.sh` | dotfiles | symlink ループに `nix_managed` 判定を追加、component setup に `SETUP_PROFILE` を渡す |
| `configs/fish/setup.sh` | dotfiles | `SETUP_PROFILE` を読み、full では dotfiles 管理分をスキップ。functions は `git ls-files` で tracked/untracked を分離 |
| `configs/claude/setup.sh` | dotfiles | 同上（skills の個別 symlink） |
| `nix/check-parity.py` | dotfiles | `nix_managed: true` を正とする突合に変更 |
| `docs/reference.md` / `README.md` | dotfiles | 責務分担の更新 |

## 移行後の評価

ADR-084 の受け入れ条件に置いた判定基準は「**移行後の総行数が減っている見込みが立つ。増えるなら Spike は却下**」だった。Phase A + B 完了時点で実測した結果は以下である（基準点は本作業の着手前 `7580dac`）。

| 対象 | Before | After | 差 |
|---|---:|---:|---:|
| `setup.sh` 系（`scripts/setup.sh`, `scripts/lib/*.sh`, `setup-manifest.yml`, `configs/*/setup*.sh`） | 1,612 | 1,748 | **+136** |
| Nix レイヤ（`flake.nix`, `nix/`） | 0 | 344 | **+344** |
| 合計 | 1,612 | 2,092 | **+480（+30%）** |

**総行数は減るどころか 3 割増えた。当初の判定基準に照らせば却下である。**

### なぜ減らなかったか

`setup.sh` 側の symlink コードを**一行も削除できなかった**ことに尽きる。Nix は darwin の full profile のみを対象とするため、remote / linux profile 用に同じコードが必要であり、`nix_managed: true` による分岐（+13 行）と profile 判定（+約 60 行）が**上乗せ**されただけになった。

ADR-084 のコンテキストで見積もった「Nix に載る 600〜700 行」は、**remote / linux profile を切り捨てる前提でしか成立しない**。この見積もりは誤りだった。マルチプラットフォーム対応を維持する限り、symlink 配置のコードは Nix の有無にかかわらず残り続ける。

増加分の内訳:

- `scripts/lib/path.sh`（49 行）: home-manager の多段リンクを `setup.sh` が誤判定しないための判定ロジック。**Nix を入れたことによって新たに必要になったコスト**
- `nix/check-parity.py`（178 行）: Nix 側と `setup.sh` 側の定義がずれていないことを検査するツール。**二重定義が存在する限り必要**であり、二重定義が解消されない以上なくならない
- 実質的な Nix 定義は `flake.nix` 33 + `home.nix` 34 + `symlinks.nix` 99 = 166 行

なお `configs/herdr/setup.sh` の +12 行と `configs/git/setup-github-ssh.sh` の +4 行は Nix と無関係の既存バグ修正（Docker e2e が恒常的に落ちていた問題）であり、上記の増加分から除いて考えてよい。

### 行数以外に得たもの・失ったもの

**得たもの**

- Homebrew の命令的インストール（`brew install` の羅列 + 存在チェック）が宣言に置き換わった
- generation によるロールバックが可能になった
- 存在しないパスを指す symlink 定義が `nix eval` の時点で落ちるようになった（`setup.sh` の Phase 1 検証が担っていた役割の一部）
- 副次的に、full profile では symlink 検査が走らなくなったため、**git worktree 内から `setup.sh` を実行しても symlink が worktree を指すよう張り替えられなくなった**（従来は worktree 内での実行が事故のもとだった）

**失ったもの**

- レイヤが 2 つになった。symlink が張られない原因を追うとき、`setup-manifest.yml` の `nix_managed`、`nix/symlinks.nix`、`configs/*/setup.sh` の profile 分岐の 3 箇所を見る必要がある
- `mkOutOfStoreSymlink` を採ったため、config 内容の store による再現性は得られていない（ADR-084 設計案 A-2 で意図的に選んだ trade-off）

### 判断

**総行数の観点では当初の基準を満たさない。** 行数を減らすには Phase C で remote / linux profile も Nix に載せ、`setup.sh` の symlink コードを実際に削除する必要がある。ただし Phase C は Docker e2e への Nix 導入（イメージ肥大とビルド時間増）と、リモートマシンへの `/nix` 導入コストを伴う。

継続・撤退・現状維持のいずれを選ぶかは、この実測を踏まえて判断する。撤退する場合、`home-manager` を削除して `setup.sh --profile remote` 相当の経路で全 symlink を復元できることは Docker e2e で確認済みである。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-085 セクション）
