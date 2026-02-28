# ADR-015: Claude Code の settings.json を共通・端末固有に分離して管理する

## ステータス

採用済み

## コンテキスト

`~/.claude/settings.json` には hooks・permissions・model 等の**共通設定**と、`env.ANTHROPIC_BASE_URL`・`enabledPlugins` 等の**端末固有設定**が混在している。

現状このファイルは git 管理されておらず、新端末でのセットアップ時に手動で再現する必要がある。hooks は `~/.claude/scripts/` を参照しており、これらのスクリプトは dotfiles で管理されているが、hooks 設定自体（どのイベントにどのスクリプトを紐付けるか）は settings.json に書かれているため、スクリプトだけ配置しても hooks は機能しない。

### settings.json の設定分類

| 設定キー | 分類 | 理由 |
|---------|------|------|
| `hooks` | 共通 | スクリプトはすべて dotfiles 管理 |
| `permissions.allow` / `.deny` | 共通 | ツール使用ポリシーは端末によらず同一 |
| `model`, `language`, `effortLevel` 等 | 共通 | 個人の作業スタイルに依存、端末間で統一したい |
| `env.ANTHROPIC_BASE_URL` | 端末固有 | 会社ネットワーク固有のエンドポイント |
| `enabledPlugins` | 端末固有 | 会社固有のプラグインマーケットプレース依存 |

### 現状の問題

- 新端末で hooks を再現するには settings.json の内容を手動でコピーする必要がある
- dotfiles を clone しても Claude Code が期待通りに動作しない
- settings.json を直接 symlink すると端末固有設定（ANTHROPIC_BASE_URL 等）が混入する

## 設計案

`tmux.local.conf` / `ghostty/local.conf` と同じ「base + local マージ」パターンを採用する。

- `dotfiles/configs/claude/settings.json` — 共通設定（hooks, permissions, model 等）
- `<端末固有リポジトリ>/configs/claude/settings.local.json` — 端末固有設定（env, enabledPlugins 等）
- `dotfiles/configs/claude/setup.sh` — `jq` で2ファイルをディープマージして `~/.claude/settings.json` を生成

```
dotfiles/configs/claude/settings.json        (共通)
      +
<sandbox>/configs/claude/settings.local.json  (端末固有)
      ↓  jq でディープマージ（local が共通を上書き）
~/.claude/settings.json
```

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---------|----------|---------|
| `configs/claude/settings.json` | dotfiles | 新規作成（共通設定を抽出） |
| `configs/claude/settings.local.json.example` | dotfiles | 新規作成（端末固有設定のテンプレート） |
| `configs/claude/setup.sh` | dotfiles | 新規作成（マージスクリプト） |
| `configs/claude/settings.local.json` | 端末固有リポジトリ | 新規作成（端末固有設定） |
| `setup.sh` | 端末固有リポジトリ | 更新（claude setup を追加） |

### setup.sh の動作

差分の方向に応じて挙動を変える。

| 状態 | 動作 |
|------|------|
| 差分なし | no-op |
| generated が current を包含（current が behind） | 自動上書き。dotfiles/sandbox 側が進んでいるだけのため安全 |
| current に generated にないキー・値がある（ローカル編集） | 差分を警告して `exit 1` で停止。上書きしない |

停止時の出力例：

```
[WARN] ~/.claude/settings.json has local changes not in dotfiles/sandbox:
--- generated
+++ current
@@ ... @@
+  "someLocalKey": "value",
 ...
Reflect the above changes in dotfiles or sandbox, then re-run setup.sh.
```

### 運用ルール

- settings.json の変更は必ず dotfiles か端末固有リポジトリを編集し、setup.sh を再実行する
- `~/.claude/settings.json` を直接編集した場合は、その内容を dotfiles/sandbox に反映してから setup.sh を実行する

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-015 セクション）
