# ADR-048: 1M context モデルの auto-compaction 閾値を 50% に設定する

## ステータス
採用済み

## コンテキスト

Claude Code は毎ターン会話履歴全体を Claude API に送信する。1M context モデル（Opus 4.6, Sonnet 4.6）ではデフォルトの auto-compaction 閾値が 80%+（~800K トークン）に設定されており、圧縮が発動するまで大量のトークンが蓄積し続ける。

これにより次の問題が発生する。

1. **推論品質の劣化**: Anthropic 公式ベンチマーク（MRCR v2, 8-needle）で 256K: 92-93% → 1M: 76-78% と 17pt 低下
2. **Raw recall の壊滅**: 制御された実験（Issue #34279）で 50% (500K) 時点で raw recall が 96% → 4% に急落
3. **レートリミットへの影響**: 毎ターン全履歴送信のため、蓄積トークン量に比例して ITPM 消費が増大

ただし、Claude Code はツール支援検索（grep/read/Agent）を使うため、raw recall の劣化は直接の問題にならない。実験では 900K でもツール支援なら 100% 精度、コーディング精度も 25/25 正解。

**問題の核心は推論品質の劣化**で、これはツールで補償できない。80%+ では「確信を持った捏造」「修正指示の無視」がユーザーから報告されている（Issue #34685, #35296）。

### エビデンス

| ソース | 種別 | 主な知見 |
|---|---|---|
| Anthropic MRCR v2 | 公式 | 256K→1M で 17pt 低下（~2pt/100K） |
| Issue #34279 実験 | 制御実験 | 50% で raw recall 壊滅、ツール支援なら 900K でも 100% |
| Issue #35296 | 分析 | 50-60% を閾値として推奨、MRCR 劣化カーブの変曲点 |
| Issue #34685 | 報告 | 40% で劣化開始の自己報告（複数ユーザー） |
| Chroma Research | 第三者 | 18 LLM 全モデルで context rot を確認 |
| LongCodeBench | 学術 | 32K→256K で 29%→3% に低下 |

### 関連 Issue

- [#35296](https://github.com/anthropics/claude-code/issues/35296): 1M Context Window Does Not Work as Marketed
- [#34685](https://github.com/anthropics/claude-code/issues/34685): Self-reported degradation starting at 40%
- [#34279](https://github.com/anthropics/claude-code/issues/34279): Restore Opus 4.6 (200k) as model picker option
- [#28975](https://github.com/anthropics/claude-code/issues/28975): Opus 4.6 (1M context) hits Rate limit on Max

## 設計案

### 案A: CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=50（採用）

環境変数 `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` を 50 に設定し、~500K トークンで auto-compaction を発動させる。

**根拠**:
- MRCR 劣化カーブの変曲点が ~50% 付近
- Raw recall は 50% で壊滅するが、ツール検索で補償可能なのでこの時点で圧縮しても情報ロスは少ない
- 500K トークンは十分な作業空間（200K モデルの 2.5 倍）
- 「損傷後の救済」ではなく「損傷の予防」アプローチ

**設定方法**: `configs/claude/settings.json` の `env` に追加し、ADR-041 の managed keys sync で全端末に伝播。

### 案B: CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=30（却下）

~300K で圧縮を発動。品質は最も安定するが、200K モデルの 1.5 倍しかなく 1M モデルの恩恵がほぼない。

### 案C: デフォルト（80%+）のまま（却下）

Anthropic のデフォルトを尊重するが、エビデンスが品質劣化を示しており、推論品質の低下はツールで補償不可能。

### 変更が必要なファイル

| ファイル | リポジトリ | 変更内容 |
|---|---|---|
| `configs/claude/settings.json` | dotfiles | `env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` に `"50"` を追加 |

## 受け入れ条件
> [issues.md](../issues.md)（ADR-048 セクション）
