# ADR-004: terminal 上のテキストをコピーできない

## ステータス

採用済み

## コンテキスト

`set -g mouse on` により tmux がマウスのドラッグ選択をインターセプトするため、通常のマウス選択→ `Cmd+C` でシステムクリップボードにコピーできない。選択操作自体が tmux の copy-mode として処理される。

## 決定

マウスドラッグによるコピーを廃止し、tmux copy-mode にキーボード操作で統一した。`Cmd+i` でコピーモードに入り、vim と同じ感覚でテキストを選択・コピーする。ペイン境界を尊重するため分割時も正確に選択できる。

```ghostty
# コピーモード (prefix + i)
keybind = super+i=text:\x00i
```

```tmux
# コピーモードに入る（prefix + i）
bind i copy-mode

# vi モードで選択・コピー
setw -g mode-keys vi
bind -T copy-mode-vi v send -X begin-selection       # 文字選択
bind -T copy-mode-vi y send -X copy-pipe-and-cancel "pbcopy"  # ヤンク
bind -T copy-mode-vi Y send -X select-line \; send -X copy-pipe-and-cancel "pbcopy"  # 行ヤンク
```

操作手順: `Cmd+i` で copy-mode 開始 → `v`/`V` で選択開始（または `Y` で現在行を即コピー）→ vim モーション（`hjkl`, `w`, `b`, `/` 検索等）で範囲選択 → `y` でクリップボードにコピー

## 却下した選択肢

### マウスドラッグ（Shift なし）

`mouse on` の状態でドラッグすると、tmux が copy-mode に入りペイン内のテキストのみを選択する。`MouseDragEnd1Pane` バインドでドラッグ終了時に自動で `pbcopy` 経由でクリップボードにコピーされる。ペイン境界を尊重する。

### Shift + ドラッグ

Shift を押しながらドラッグすることで tmux のマウスキャプチャをバイパスし、Ghostty のネイティブ選択 → `Cmd+C` でコピー。ただしペイン分割時に左右両方のペインのテキストを選択してしまう制約がある。

## 参考

- [tmux Wiki: Clipboard](https://github.com/tmux/tmux/wiki/Clipboard)
- [Ghostty OSC 52 support](https://ghostty.org/docs/vt/osc52)
