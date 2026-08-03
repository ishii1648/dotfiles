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

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-085 セクション）
