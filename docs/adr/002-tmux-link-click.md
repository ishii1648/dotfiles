# ADR-002: tmux 内でリンクをクリックできない

## ステータス

採用済み

## コンテキスト

`set -g mouse on` により tmux が全マウスイベントをインターセプトするため、Ghostty がクリックを受け取れない。OSC 8 ハイパーリンクの「表示」は対応済みだが、「クリック」が tmux に奪われる。

## 決定

tmux-fzf-url プラグインを採用。`Cmd + u`（または `prefix + u`）で画面上の URL を fzf 一覧表示し、選択して開く。

```tmux
set -g @plugin 'wfxr/tmux-fzf-url'
# #NNN パターンから GitHub PR URL を生成するカスタムフィルター
set -g @fzf-url-extra-filter '~/.local/bin/tmux-fzf-url-pr-filter'
```

```ghostty
keybind = super+u=text:\x00u
```

カスタムフィルター（`tmux-fzf-url-pr-filter`）により、`#123` のような PR 番号もペインの git remote 情報と組み合わせて GitHub PR URL に変換される。OSC 8 の制約を回避できるため、tmux 環境では最も確実な方法。

## 却下した選択肢

### Shift + Cmd + クリック（テキスト URL のみ）

Shift キーを追加で押すことで tmux のマウスキャプチャをバイパスし、Ghostty にイベントを渡す。

- `Shift + Cmd + ホバー` → URL にアンダーライン表示
- `Shift + Cmd + クリック` → ブラウザで開く

> **制約**: Ghostty のテキストパターン検出による URL 認識のみ機能する。OSC 8 ハイパーリンク（リンクテキストと URL が異なるもの、例: `#123` → GitHub PR URL）は tmux 内では機能しない。tmux は OSC 8 を内部的に保持するが、画面再描画時に Ghostty へ正しく再送信できないため（tmux 3.6a + Ghostty で確認）。

「Shift なしの Cmd+クリック」は [Ghostty Discussion #8748](https://github.com/ghostty-org/ghostty/discussions/8748) で要望されているが未対応。

## 参考

- [Ghostty Discussion #9735](https://github.com/ghostty-org/ghostty/discussions/9735)
- [wfxr/tmux-fzf-url](https://github.com/wfxr/tmux-fzf-url)
