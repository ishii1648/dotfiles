# ADR-001: Cmd キーを tmux で使えない

## ステータス

採用済み

## コンテキスト

macOS の Cmd キーは OS レベルで処理され、ターミナルエミュレータ内の tmux には到達しない。これは tmux ではなく OS とターミナルのアーキテクチャ上の制約。

## 設計案

代替案なし。OS の制約上、tmux が Cmd キーを直接受け取ることはできないため、ターミナル側（Ghostty）で変換して tmux に渡す方式のみ検討。

## 決定

Ghostty の `keybind` 設定で `Cmd+X` を `tmux prefix + コマンドキー` のシーケンスとして送信する。現在の prefix `Ctrl+Space` は hex で `\x00`。

```ghostty
# Cmd+数字 で tmux ウィンドウ切替
keybind = super+one=text:\x001
keybind = super+two=text:\x002
keybind = super+three=text:\x003

# Cmd+T で tmux 新規ウィンドウ (prefix + c)
keybind = super+t=text:\x00c

# Cmd+W で tmux ペイン閉じる (prefix + x)
keybind = super+w=text:\x00x

# Cmd+S で tmux セッション切替 (prefix + s)
keybind = super+s=text:\x00s
```

## 受け入れ条件

（issues.md 導入前の ADR。以下は実装後の結果）

- Ghostty 側の設定のみで完結し、tmux の全機能を維持できる

## 参考

- [Ghostty Discussion #3309](https://github.com/ghostty-org/ghostty/discussions/3309)
- [Ghostty Discussion #3447](https://github.com/ghostty-org/ghostty/discussions/3447)
