# ADR-068: auto mode 下での hook 無効化と destructive 防御の permissions.deny 移行

## ステータス
部分廃止（ADR-091 で一部変更）

- **ADR-091 で上書き** — approve 系 2 hook は mode 別 skip ではなく削除した。permission 判定を肩代わりする構造そのものが問題で、mode で無効化しても `default` / `acceptEdits` を使う端末では発火し続けるため
- **引き続き有効** — `redirect-to-tools.py` の `auto` / `bypassPermissions` / `dontAsk` skip、`rm -rf` の `permissions.deny` 移行、global CLAUDE.md からの「自律性の原則」削除

## 関連 ADR
- 依存: ADR-013（permission ask auto-block）— 本 ADR は ADR-013 の hook 戦略の上に立ち、auto mode 運用への移行を反映
- 依存: ADR-014（redirect rules auto expansion）— redirect rule の skip 機構を追加
- 依存: ADR-017（approve-safe-commands hook）— 当該 hook に mode 判定を追加
- 依存: ADR-037（approve-claude-subdir file ops）— approve-safe-file-ops.py に mode 判定を追加
- 関連: ADR-038（approve-claude-subdir read）
- 関連: ADR-042（hook scalability）— hook 責務整理の方向性と整合的

## コンテキスト

Claude Code の頻繁な permission prompt を緩和するため、以下の hook と CLAUDE.md 規約を段階的に導入してきた:

- `redirect-to-tools.py`: 複雑な Bash（ループ・パイプ・インラインスクリプト）を禁止し、`find`/`grep`/`cat`/`sed`/`awk` 等を native tool（Glob/Grep/Read/Edit）に redirect。`&&`/`$()` もブロック
- `approve-safe-commands.py`: read-only な git/gh api コマンドを auto-approve
- `approve-safe-file-ops.py`: `.claude/{subdir}/` 配下の Read/Write/Edit を auto-approve
- global CLAUDE.md (`configs/claude/CLAUDE.md`): 「自律性の原則」（複雑な Bash 禁止）と「禁止コマンド」（`rm -rf` 禁止）を明文化

これらは default mode 運用を前提とした「permission 削減装置」であった。`/tmp/` → `.outputs/claude/` 誘導も「プロジェクト外パスへの書き込みが default mode で permission 対象になる」のを避けるための機能であり、出自は permission 削減で揃っている（project hygiene の副次効果はあるが主目的ではない）。

しかし `permissions.defaultMode: "auto"` 運用に切り替えてから次の問題が顕在化した:

1. **approve-\* 系は冗長**: auto mode では permission prompt がそもそも出ないため、approve hook は実質 no-op（hook 起動・stdin 読み取り・JSON 解析のオーバーヘッドだけ残る）
2. **redirect-to-tools.py が pure friction**: `cat`→Read 強制で複数 round-trip が発生、`&&` 禁止で連続コマンドが分割実行に強制される。auto mode 下で permission を削減する効果はないため純粋な開発体験悪化
3. **CLAUDE.md の「複雑な Bash 禁止」も同様**: permission 削減目的だったため auto mode では存在意義を失う
4. **`rm -rf` 禁止だけは destructive 防御として価値が残る**: ただし CLAUDE.md（指示遵守頼み・モデルの解釈次第）ではなく、`permissions.deny`（hook 層での deterministic ブロック）に置く方が確実

PreToolUse hook の input には公式に `permission_mode` フィールド（`default` / `auto` / `acceptEdits` / `bypassPermissions` / `dontAsk` / `plan`）が含まれるため、各 hook が現在の mode を見て条件付き skip する設計が可能。

## 設計案

### 案A: /tmp/ 誘導だけ残して他 rule を mode で skip（却下）

`redirect-to-tools.py` の `/tmp/` → `.outputs/claude/` 誘導を project hygiene 目的とみなし、それ以外の rule のみ `permission_mode` で skip する。

却下理由: 当初は `/tmp/` 誘導を hygiene 目的と整理していたが、出自は「default mode で `/tmp/` がプロジェクト外パスとして permission 対象になる挙動」への対策であり、permission 削減で揃っていた。auto mode では permission がそもそも出ないため `/tmp/` チェックも friction にしかならず、hook 全体を skip する案B が筋。

### 案B: hook 全体を mode で一括 skip + permissions.deny 移行（採用）

**1. `redirect-to-tools.py`**
- `permission_mode` が `auto` / `bypassPermissions` / `dontAsk` の場合、`/tmp/` チェックを含む全 rule を skip（main 冒頭で即 `exit 0`）
- default mode では従来どおり全 rule（`/tmp/` 誘導 + `$()` 禁止 + `&&` 禁止 + native tool redirect）が機能する

**2. `approve-safe-commands.py`**
- 同 mode で即 `exit 0`（auto mode では既に approved されるため冗長）

**3. `approve-safe-file-ops.py`**
- 同 mode + `acceptEdits` で即 `exit 0`
- Bash hook（commands）と異なり `acceptEdits` を skip 対象に含める（acceptEdits では Bash は default 動作だが file ops は許可されるため）

**4. global CLAUDE.md**
- 「自律性の原則」「禁止コマンド」セクションを削除

**5. `permissions.deny`**
- `Bash(rm -rf *)`, `Bash(rm -fr *)`, `Bash(rm -r -f *)`, `Bash(rm -f -r *)` を追加
- `configs/claude/settings.json`（dotfiles 側）と `~/.claude/settings.json`（配布先）の両方に反映

利点:
- auto mode で hook の friction が完全に消える
- default mode に切り戻した場合は従来挙動に戻る（mode 切替に追従）
- destructive 防御は hook 層でより確実に機能（CLAUDE.md の指示頼みより堅固）

欠点:
- mode に応じた早期 return が hook ごとに増える（trivial な if 1個だが）
- `permissions.deny` の glob パターンは網羅性に限界（`rm --recursive --force *` など別記法には未対応）

### 案C: rule ごとに `auto_skip: true/false` メタを持たせる（却下）

各 rule に skip 条件メタデータを付与し、hook がそれを評価する仕組みを構築する。

却下理由: 過剰設計。今回 rule の出自は permission 削減で揃っており、mode 単位で hook 全体を skip すれば十分。rule 別の制御が必要になった時点で再検討する。

### 案D: mode 検出を `~/.claude/settings.json` 読み込みで実装（却下）

`permissions.defaultMode` を hook 起動時に読んで判定する。

却下理由: 公式の `permission_mode` フィールドが hook input に含まれるため、独自実装は不要。設定ファイル読み込みは動的な mode 切替（runtime での auto on/off）に追従できないデメリットもある。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/scripts/redirect-to-tools.py` | dotfiles | `permission_mode` 系で hook 全体を skip（`/tmp/` チェック含む） |
| `configs/claude/scripts/approve-safe-commands.py` | dotfiles | `permission_mode` 系で即 exit |
| `configs/claude/scripts/approve-safe-file-ops.py` | dotfiles | `permission_mode` 系 + `acceptEdits` で即 exit |
| `configs/claude/CLAUDE.md` | dotfiles | 「自律性の原則」「禁止コマンド」セクション削除 |
| `configs/claude/settings.json` | dotfiles | `permissions.deny` に rm 系パターン追加 |
| `~/.claude/settings.json` | （配布先・symlink 対象外） | 同 deny ルールを手動同期 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-068 セクション）
