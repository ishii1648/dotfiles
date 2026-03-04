# ADR-041: claude-stats の人の介入指標を拡張する

## ステータス

採用済み

## コンテキスト

ADR-036・ADR-037 で Permission UI 回数とその間の自律ストレッチ長（tool_use 数）を計測できるようになった。しかし、Permission UI はあくまで「Claude が許可を求めた」タイミングだけを捉えており、人の介入全般を表していない。

実際には次のような介入がありうる。

- **ユーザーが自発的に指示を追加する**（mid-session メッセージ）：Claude の動作を見て方向転換を要求する。Permission UI では捉えられない。
- **Claude が自ら問い合わせる**（AskUserQuestion）：仕様が曖昧なとき Claude がユーザーに質問する。Permission UI と異なり Claude 起点。
- **同一 PR に対して複数セッションを起動する**（セッション数/PR）：一度では完了せず Claude を起動し直す回数。工数感覚と直結する。

また Permission UI 回数の絶対数は tool_use 総数に依存するため、「permission を求めすぎているか」という問いには Permission UI 発生率（perm_count / tool_use_total）で代替するほうが適切と判断した。

**計測スコープの制約**：PR に紐づいた作業のみを対象とする。PR なしセッションはデータの意味が曖昧（探索・実験・雑談等）なため除外する。

## 設計案

### 指標の定義と取得方法

| 指標 | 定義 | データソース |
|------|------|------------|
| **B-1: mid-session メッセージ数** | セッション内で初回プロンプト以外にユーザーが送信したメッセージ数。コマンド出力（`<local-command-*>` タグ含む）は除外する | transcript の `type:"user"` エントリ（2件目以降、コマンド出力除外） |
| **A-1代替: Permission UI 発生率** | perm_count / tool_use_total（PR 単位）。permission を求めすぎているかを正規化して評価 | permission.log + transcript の tool_use 数 |
| **C-1: AskUserQuestion 回数** | Claude がユーザーに問い合わせた回数。仕様曖昧さの代理指標 | transcript の `tool_use.name == "ask-user-question"` |
| **D-1: セッション数/PR** | 同一 PR に対して起動したセッション数。完了まで何度 Claude を起動し直したかを示す | session-index.jsonl の `pr_urls` でグループ化 |

### 実装方針

すべての指標は `permission-ui-server.py` の transcript 解析部分を拡張することで実装可能。

**B-1 の除外ロジック**:
```python
def is_human_text_message(entry):
    if entry.get("type") != "user":
        return False
    content = entry.get("message", {}).get("content", "")
    # コマンド出力・tool_result は除外
    if "<local-command-" in str(content):
        return False
    if isinstance(content, list):
        # tool_result のみで構成されるメッセージを除外
        types = [c.get("type") for c in content if isinstance(c, dict)]
        if all(t == "tool_result" for t in types):
            return False
    return True
```

**C-1 の取得ロジック**:
```python
def count_ask_user_question(entries):
    count = 0
    for entry in entries:
        if entry.get("type") == "assistant":
            for item in (entry.get("message", {}).get("content") or []):
                if isinstance(item, dict) and item.get("type") == "tool_use":
                    if item.get("name") == "ask-user-question":
                        count += 1
    return count
```

**D-1 の集計**:
- session-index.jsonl から `pr_urls` でグループ化
- 各 PR URL に対して `session_id` の unique count = セッション数

### ダッシュボードへの統合

既存の PR 別統計テーブルに次の列を追加する。

| 現在の列 | 追加列 |
|---------|--------|
| PR URL | - |
| permission UI 回数 | ← 維持 |
| avg stretch | ← 維持 |
| median stretch | ← 維持 |
| - | **mid-session メッセージ数（合計）** |
| - | **Permission UI 発生率（%）** |
| - | **AskUserQuestion 回数** |
| - | **セッション数** |

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-041 セクション）

## 関連 ADR

- [ADR-036](036-claude-permission-ui-count-via-hook.md): Permission UI ログ収集・可視化の基盤（本 ADR の前提）
- [ADR-037](037-claude-autonomy-rate-per-work-unit.md): 自律ストレッチ長の導入（本 ADR と同一ダッシュボードに統合）
- [ADR-011](011-claude-session-index.md): session-index.jsonl の構造（transcript パスおよびセッション数集計の参照元）
