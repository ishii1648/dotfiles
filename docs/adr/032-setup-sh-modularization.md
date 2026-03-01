# ADR-032: setup.sh のモジュール分割

## ステータス
採用済み

## 関連 ADR
- 依存: ADR-018（統合 setup.sh のアーキテクチャを前提）
- 関連: ADR-031（interactive/non-interactive モード — 分割後も動作を維持する必要がある）

## コンテキスト

`scripts/setup.sh` が 574 行に膨れ上がっており、以下の問題が顕在化している:

- **可読性の低下**: オプション解析・依存インストール・マニフェスト解析・ユーティリティ関数・フェーズ 1/2・サマリー出力が 1 ファイルに密集している
- **テスト困難**: ユーティリティ関数（`ensure_symlink`, `process_copy`, `validate_gitconfig` 等）を個別にテストする手段がない
- **拡張コスト**: ADR-031 の interactive/non-interactive モード追加など、新機能の追加が既存コードとの衝突リスクを高める

Python 移行やコンパイル言語への切り替えは将来検討とし、本 ADR では **Bash のまま `scripts/lib/` に関数群を分割する** ことのみをスコープとする。

## 設計案

### 案A: `scripts/lib/` にユーティリティ関数を分割（採用）

`scripts/setup.sh` をオーケストレータとして残し、関数群を `scripts/lib/*.sh` に切り出す。

**分割単位:**

| ファイル | 責務 | 主な関数・変数 |
|---|---|---|
| `scripts/lib/colors.sh` | カラー定義・カウンター変数 | `RED`, `GREEN`, `YELLOW`, `CYAN`, `NC`, `ok_count`, `fix_count`, `fail_count`, `warn_count`, `total_count` |
| `scripts/lib/symlink.sh` | シンボリックリンク管理 | `expand_path`, `create_symlink`, `ensure_symlink` |
| `scripts/lib/copy.sh` | ファイルコピー処理 | `process_copy` |
| `scripts/lib/validate.sh` | 設定ファイルバリデーション | `validate_gitconfig`, `validate_json`, `process_validate` |
| `scripts/lib/manifest.sh` | マニフェスト読み込み・プロファイル検証 | YAML→JSON 変換、プロファイル検証ロジック |
| `scripts/lib/deps-macos.sh` | macOS 依存パッケージインストール | PyYAML チェック、Homebrew パッケージ、Colima 起動 |

**読み込み方式:**

```bash
# scripts/setup.sh 冒頭
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for lib in "$SCRIPT_DIR"/lib/*.sh; do
    source "$lib"
done
```

**setup.sh のメイン部分（約 100 行に圧縮）:**
- オプション解析
- lib の source
- Phase 0: `install_deps` 呼び出し
- Phase 1: マニフェスト検証ループ
- Phase 2: コンポーネント処理ループ
- サマリー出力

### 案B: Phase 単位で分割（却下）

`scripts/setup-phase0.sh`, `scripts/setup-phase1.sh` のように Phase 単位で分割する方式。

**却下理由**: Phase をまたいで共有する変数（カウンター、MANIFEST_JSON、DRY_RUN 等）の受け渡しが煩雑になる。`source` ではなくサブプロセスで呼ぶと状態共有できず、`source` で呼ぶなら関数単位の分割と変わらない。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `scripts/setup.sh` | dotfiles | オーケストレータに簡素化（lib を source） |
| `scripts/lib/colors.sh` | dotfiles | 新規作成（カラー定義・カウンター） |
| `scripts/lib/symlink.sh` | dotfiles | 新規作成（symlink 関数群） |
| `scripts/lib/copy.sh` | dotfiles | 新規作成（copy 関数） |
| `scripts/lib/validate.sh` | dotfiles | 新規作成（validate 関数群） |
| `scripts/lib/manifest.sh` | dotfiles | 新規作成（マニフェスト解析） |
| `scripts/lib/deps-macos.sh` | dotfiles | 新規作成（macOS 依存パッケージ） |
| `tests/Dockerfile` | dotfiles | 変更なし（`bash scripts/setup.sh` の呼び出しは同じ） |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-032 セクション）
