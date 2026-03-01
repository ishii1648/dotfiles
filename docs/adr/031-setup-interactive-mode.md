# ADR-031: setup.sh に interactive / non-interactive モードを追加する

## ステータス

Draft

## 関連 ADR

- 依存: ADR-018（統合 setup コマンドの設計を前提）
- 関連: ADR-019（Docker e2e テストは non-interactive が前提）

## コンテキスト

`scripts/setup.sh` は ADR-018 で統合エントリポイントとして導入され、ADR-019 で Docker コンテナ内での e2e テストにも使われている。現状の setup.sh は大部分が non-interactive に動作するが、以下の箇所で環境によってはユーザー入力を求められるケースがある：

- `brew install` — パッケージインストール時の確認プロンプト（Homebrew の設定に依存）
- `colima start` — コンテナランタイム起動時の対話
- `pip3 install pyyaml` — パッケージインストール時の確認
- `ssh-add` — パスフレーズ付き鍵の登録時にパスフレーズ入力を求められる（`setup-github-ssh.sh` Step 5 付近）
- `ssh -T git@github.com` — 接続テスト時に known_hosts 確認（`setup-github-ssh.sh` Step 6）
- 委譲先の `setup.sh`（fish, claude 等）— 将来的に対話が発生する可能性

テスタブルかつ CI で安定実行するには、これらの対話を明示的に制御する仕組みが必要。現在は `--dry-run` と `--profile` オプションのみで、実行モードの制御手段がない。

## 設計案

### 案A: `--interactive` / `--non-interactive` フラグの追加（採用）

setup.sh に `--interactive` / `--non-interactive` オプションを追加し、モードに応じて動作を分岐する。

```bash
bash scripts/setup.sh                        # デフォルト: auto（TTY 判定）
bash scripts/setup.sh --interactive           # 確認プロンプトあり
bash scripts/setup.sh --non-interactive       # 確認なし・自動続行
```

#### モード判定

| モード | 動作 | 用途 |
|---|---|---|
| `auto`（デフォルト） | TTY 接続時は interactive、非 TTY 時は non-interactive | 通常利用 |
| `--interactive` | 破壊的操作・パッケージインストール前に確認プロンプトを表示 | 初回セットアップ |
| `--non-interactive` | 確認なしで自動続行。`DEBIAN_FRONTEND=noninteractive` 相当の環境変数も設定 | CI / Docker e2e |

#### 制御対象

- `brew install`: non-interactive 時に `HOMEBREW_NO_AUTO_UPDATE=1` を設定し、`--quiet` を付与
- `pip3 install`: non-interactive 時にそのまま続行（元々プロンプトなし）
- `colima start`: non-interactive 時に自動起動。interactive 時は確認プロンプト表示
- `ssh-add`: non-interactive 時はスキップ（パスフレーズ入力不可）。TIP メッセージで手動実行を案内
- `ssh -T git@github.com`: non-interactive 時は `StrictHostKeyChecking=accept-new` を付与、またはスキップ
- 委譲先 setup.sh: `SETUP_INTERACTIVE` 環境変数で伝播

#### 実装方針

- `INTERACTIVE` 変数（`auto` / `true` / `false`）をオプション解析で設定
- `auto` の場合は `[ -t 0 ]`（stdin が TTY か）で判定
- `confirm()` ヘルパー関数を追加し、interactive 時のみプロンプト表示。non-interactive 時は自動 yes
- `--dry-run` との組み合わせ: `--dry-run` は常に non-interactive として扱う（変更しないため確認不要）

### 案B: `--yes` フラグのみ追加（却下）

`--yes` / `-y` フラグで全プロンプトをスキップする方式。シンプルだが、TTY 判定による自動切り替えができず、CI で毎回 `--yes` を指定する必要がある。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `scripts/setup.sh` | dotfiles | `--interactive` / `--non-interactive` オプション追加、`confirm()` 関数追加、TTY 自動判定ロジック |
| `tests/Dockerfile` | dotfiles | `--non-interactive` フラグを付与（明示化） |
| `.github/workflows/e2e.yml` | dotfiles | `--non-interactive` フラグを付与（明示化） |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-031 セクション）
