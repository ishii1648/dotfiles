# pane-state-mechanism

## 概要

`/tmp/claude-pane-state/` ディレクトリに置かれるファイル群で、tmux pane ごとの Claude Code セッション状態を管理する仕組み。

## ファイルパス規則

```
/tmp/claude-pane-state/pane_<PANE_NUM>
```

`PANE_NUM` は tmux の `#{pane_id}` から `%` プレフィックスを除いた数値。

```bash
# pane_id が %3 の場合
PANE_ID=$(tmux display-message -p '#{pane_id}')   # => %3
PANE_NUM=$(echo $PANE_ID | tr -d '%')             # => 3
STATE_FILE="/tmp/claude-pane-state/pane_${PANE_NUM}"
```

## stateファイルの値

| 値 | 意味 |
|----|------|
| `idle` | Claude Code が待機中。プロンプト送信可能 |
| `running` | Claude Code がタスクを処理中 |
| `ask` | Claude Code がユーザーへの質問待ち（AskUserQuestion 等） |
| `permission` | Claude Code がツール実行の権限確認待ち |
| ファイルなし | Claude Code が起動していない、またはstateが不明。`idle` と同様に扱う |

## 書き込みタイミング

stateファイルは Claude Code の Stop フックおよび PostToolUse フックから書き込まれる。

- **SessionStart / idle 遷移時**: `idle` を書き込む
- **タスク実行開始時**: `running` を書き込む
- **AskUserQuestion 発動時**: `ask` を書き込む
- **permission 確認時**: `permission` を書き込む
- **セッション終了時**: ファイルを削除する（またはそのまま残る場合もある）

## 注意事項

- stateファイルは `/tmp` 以下にあるため、OS 再起動で消去される
- 書き込み元のプロセスがクラッシュした場合、古い state が残ることがある
- そのため `pane_idle`（tmux のアイドル時間）との二重チェックを推奨する
