# ADR-080: Cmd+G の herdr goto 配線を外して将来の割り当て用に空ける

## ステータス

Draft

## 関連 ADR

- 依存: [ADR-076](076-herdr-migration-from-tmux.md)（herdr 移行時に Cmd+G を `goto`（session navigator）へ配線した決定 — 本 ADR はその配線を外す）
- 経緯: [ADR-079](079-agent-picker-popup.md)（Cmd+A のエージェントピッカーを追加し、Cmd+G の出番が減った）

## コンテキスト

ADR-076 で ghostty の `super+g` を `text:\x00g`（= `prefix+g`）に配線し、herdr の `goto`（navigate mode / session navigator）を Cmd+G から開けるようにしていた。

その後 ADR-079 で Cmd+A のエージェントピッカーを追加した結果、日常のナビゲーションは次の 2 つでほぼ賄える。

| 用途 | キー |
|---|---|
| workspace を選ぶ | Cmd+S（`workspace_picker`） |
| エージェントを選ぶ | Cmd+A（`[[keys.command]]` の popup ピッカー） |

Cmd+G（workspace とペインのツリーを辿る navigate mode）は上記と役割が重なり、押しやすい Cmd 段を占有し続ける価値が薄い。**将来別のアクションに割り当てたい**ため空けておく（ユーザー要望）。

## 決定

- `configs/ghostty/config` の `super+g` を `ignore` にする
- herdr 側の `goto = "prefix+g"` は**残す**（物理 Ctrl+Space → g で従来どおり開ける。失うのは Cmd ショートカット経由の到達性だけ）

## 設計上の判断

- **行を削除するのではなく `ignore` を明示する** — ghostty には組み込みの `super+g=navigate_search:next`（検索の次候補）がある（`ghostty +list-keybinds --default` で実測）。行を消すだけだとこの既定が復活し、herdr セッション上で意図しない検索操作が発火する。
- **`unbind` ではなく `ignore`** — `unbind` はバインドを外してキーを子プロセス（herdr、ひいてはエージェント）へ通すため、herdr 側やエージェント側で解釈される余地が残る。`ignore` は ghostty が握り潰して何も起きないので「無効化」の意図に正確に一致する。
- **将来の再割り当て時はこの行を書き換えるだけで済む** — `keybind = super+g=text:\x00<小文字>` の形に戻せば herdr のアクションへ再配線できる（herdr はリテラル大文字を shift 付きとして解釈しないため、`prefix+<小文字>` に限る制約は ADR-077 のまま）。

## 変更が必要なファイル

| ファイル | 変更内容 |
|---|---|
| `configs/ghostty/config` | `super+g` を `text:\x00g` → `ignore` に変更 |

## 受け入れ条件
→ [issues.md](../issues.md)（ADR-080 セクション）
