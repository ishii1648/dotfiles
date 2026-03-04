# ADR-037: 作業量で正規化した Claude 自律度指標の導入

## ステータス

Superseded by [ADR-041](041-claude-human-intervention-metrics-expansion.md)

## コンテキスト

ADR-036 で permission UI 表示回数のログ収集と可視化ダッシュボードを実装した。しかし、permission UI の絶対数を PR ごとに比較しても「多い/少ない」の判断ができないことが判明した。

理由：作業量が多いタスク（コード変更範囲が大きい、調査が多岐に及ぶ）では、permission UI が自然に増える。絶対数が大きい PR が「自律度が低い」とは言えず、単に作業量が多かっただけの可能性がある。

議論の中で検討した正規化候補：

- **ツール呼び出し数（案A）**: `permission_ui / tool_calls` は「割り込まれた比率」を測れるが、分母も作業量に比例するため、「同量の作業に対して何回割り込まれたか」という本来の問いには不充分
- **git diff 行数・ファイル数**: 作業量の代理にはなるが、リファクタ（行数が多くても単純）等で外れる
- **セッション時間**: AFK 時間が混入する

**本質的な指標の方向性**：「Claude が連続して自律的に動けたストレッチの長さ」を測る。具体的には、permission UI と permission UI の間に何回 tool_use が発生したかの中央値・平均値（= 1回割り込まれるまでに自律処理できたアクション数）。これは絶対数ではなくリズムを測る指標であり、作業量の大小に依存しない。

## 設計案

### 案A: permission UI 間の tool_use 数の分布（採用候補）

transcript JSONL を読み込み、`type: "tool_use"` と permission_prompt 発火タイミングを対応付ける。

- permission UI 発火をセパレータとして、区間ごとの tool_use 数を集計
- 中央値・平均値・最大値をダッシュボードに表示
- PR 間・時系列での比較が可能

**取得可能なデータ**:
- transcript JSONL: `~/.claude/projects/<proj>/<session_id>.jsonl`（session-index.jsonl から参照可能）
- permission.log: タイムスタンプ付き session_id

**課題**:
- transcript ファイルが大きい場合（数十 MB）の読み込み速度
- permission_prompt 発火タイミングと transcript の tool_use イベントの時刻対応付け方法の検証が必要

### 案B: tool_use 種別ごとの permission UI 発生率

どのツール（Bash / Edit / Write 等）が permission UI を引き起こしているかの内訳を集計する。

- 改善アクションが具体的になる（「Bash の permission を減らす」等）
- ADR-013/014 の取り組みと連携可能

### 案C: 時系列トレンドのみ表示

正規化を諦め、同一リポジトリ・同一作業パターンの PR 群を時系列で並べてトレンドを見る。絶対数ではなく「最近増えているか減っているか」で判断する。

## 受け入れ条件

→ [issues.md](../issues.md)（ADR-037 セクション）

## 関連 ADR

- [ADR-036](036-claude-permission-ui-count-via-hook.md): permission UI ログ収集・可視化の基盤（本 ADR の前提）
- [ADR-011](011-claude-session-index.md): session-index.jsonl の構造（transcript パスの参照元）
- [ADR-013](013-claude-permission-ask-auto-block.md): permission UI 削減の取り組み（本指標の改善対象）
