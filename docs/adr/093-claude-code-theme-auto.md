# ADR-093: Claude Code の theme を auto にしてターミナルに追随させる

## ステータス
採用済み

## 関連 ADR
- 依存: ADR-041（settings.json の管理キー同期 — `SYNC_KEYS` の追加先）
- 関連: ADR-092（permissions を配布せずベースライン検査に変えた決定 — 配布キーを増やす判断の前提）
- 関連: ADR-073 / ADR-074（statusline の表示内容）

## コンテキスト

Ghostty を `theme = light:Catppuccin Latte,dark:Dracula`、herdr を `[theme] auto_switch = true` にして macOS の外観設定に追随させた。端末とマルチプレクサはライト / ダークを切り替えるようになったが、Claude Code だけが `~/.claude/settings.json` の `"theme": "dark"` で固定されたままで、ライト背景の上にダーク前提の配色を描いている。

実害として出たのが permission mode の表示（`plan mode on` / `accept edits on` / `bypass permissions`）で、色で mode を判別できなくなった。mode バッジは Claude Code 本体が描いており、自前 statusline（`configs/claude/statusline.js`）は tier / model / repo / branch / PR / ctx / 使用率しか出していないため、statusline を直しても解決しない。

Claude Code 2.1.233 のテーマ一覧には `Auto (match terminal)`（値は `auto`）がある。バイナリ内の `watchSystemTheme` は OSC 11（背景色クエリ）を端末へ送って応答から light / dark を判定し、応答の有無を `osc11Responsive` に記録する。`$TMUX` / `$STY` 配下では DCS passthrough に切り替え、端末側のテーマ変更通知も購読する。herdr 0.7.5 のバイナリにも `]11;rgb:` の応答文字列があり、ペイン内アプリの OSC 11 に答える実装を持つ。応答が得られない場合は `COLORFGBG` へのフォールバックがある。

dotfiles 側は theme を配布していない。`configs/claude/settings.json` に `theme` キーが無く、`setup.sh` の `SYNC_KEYS` も `hooks` / `statusLine` のみ。theme 未設定時の Claude Code 既定は `dark` なので、放置すると新端末でも同じ状態になる。

## 設計案

### 案A: `theme = "auto"` を dotfiles の管理キーにする（採用）

`configs/claude/settings.json` に `"theme": "auto"` を追加し、`setup.sh` の `SYNC_KEYS` に `theme` を加えて配布先へ同期する。

- **ADR-092 との整合** — ADR-092 は「端末ごとに違ってよい設定を dotfiles から上書きしない」ために permissions を配布から外した決定だが、`auto` は特定の配色を強制する値ではなく「その端末の背景に合わせる」という指示であり、端末差を潰さない。値もスカラーなので、配列を全置換して deny を消したような破壊は起きない
- **上書きの副作用** — `SYNC_KEYS` は src の値で全置換するため、ある端末で `/theme` から `dark` 等を選んでも次の setup.sh 実行で `auto` に戻る。色覚特性向け（`*-daltonized`）や ANSI 限定（`*-ansi`）を常用したい端末が出てきた時点で、その端末は `settings.local.json` 側に置くか、theme を `SYNC_KEYS` から外して再検討する
- **statusline の ANSI 色は対象外** — `statusline.js` が出す色（tier のシアン、worktree の緑、dirty の黄、ctx バーの緑 / 黄 / 赤）は端末パレット由来で、Ghostty の `minimum-contrast = 3.0` が持ち上げる。今回の変更とは独立している
- **判定は起動時のみ（実機で確認）** — 外観を切り替えても走っているセッションは追随せず、Claude Code を再起動して初めて新しい配色になる。`watchSystemTheme` は端末のテーマ変更通知も購読しているが、herdr 経由では届いていないと見られる。切り替えは 1 日 1〜2 回で、そのたびにセッションを畳む方が高くつくため制約として受け入れる（新しく開くペインは正しい側で始まる）

### 案B: 端末ごとに `light` / `dark` を手で選ぶ（却下）

`/theme` で切り替える運用。macOS の外観設定は時間帯で変わるため、切り替えのたびに手で追随する必要があり、追随漏れがそのまま今回の症状になる。

### 案C: statusline.js に permission mode を自前描画する（却下）

stdin から mode を取り出し、明示的な ANSI 色で statusline に出す案。本体が描くバッジは消せないので表示が二重になり、配色の追随という本来の問題も残る。Claude Code 側の stdin スキーマ変更に追従するコストも増える。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/settings.json` | dotfiles | `"theme": "auto"` を追加 |
| `configs/claude/setup.sh` | dotfiles | `SYNC_KEYS` に `theme` を追加 |
| `docs/reference.md` | dotfiles | ライト / ダーク追随の対象コンポーネントを記載 |

## 受け入れ条件
→ [issues.md](../issues.md)（「Claude Code の配色をターミナルに追随させる」セクション）
