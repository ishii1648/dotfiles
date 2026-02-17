---
name: confluence-emoji-mapping
description: >-
  Reference-only data table mapping Confluence emoji shortNames to Unicode
  characters. This skill should be used only when explicitly referenced by
  another skill (e.g., confluence-to-md, create-adr) that needs to convert
  Confluence emoji tags. This skill should NOT be triggered by direct user
  requests about emoji or Confluence content.
---

# Confluence Emoji Mapping

Confluence の `<custom data-type="emoji">` タグに含まれる shortName を Unicode 文字またはテキスト表現に変換するためのマッピングテーブル。

## 変換ルール

Confluence が Markdown 出力時に生成する以下の形式のタグを対象とする:

```
<custom data-type="emoji" data-id="id-N">:shortName:</custom>
```

このタグ全体を、マッピングテーブルに基づく Unicode 文字またはテキスト表現で置換する。

## 標準絵文字マッピング

| shortName | Unicode |
|-----------|---------|
| `:blue_book:` | 📘 |
| `:star2:` | 🌟 |
| `:rainbow:` | 🌈 |
| `:robot:` | 🤖 |
| `:book:` | 📖 |
| `:white_check_mark:` | ✅ |
| `:warning:` | ⚠️ |
| `:bulb:` | 💡 |
| `:memo:` | 📝 |
| `:link:` | 🔗 |
| `:hammer_and_wrench:` | 🛠️ |
| `:rocket:` | 🚀 |
| `:eyes:` | 👀 |
| `:thinking:` | 🤔 |
| `:thumbsup:` | 👍 |
| `:thumbsdown:` | 👎 |
| `:fire:` | 🔥 |
| `:tada:` | 🎉 |
| `:x:` | ❌ |
| `:heavy_check_mark:` | ✔️ |
| `:question:` | ❓ |
| `:exclamation:` | ❗ |
| `:clock:` | 🕐 |
| `:calendar:` | 📅 |
| `:chart_with_upwards_trend:` | 📈 |
| `:lock:` | 🔒 |
| `:unlock:` | 🔓 |
| `:gear:` | ⚙️ |
| `:pencil:` | ✏️ |
| `:pushpin:` | 📌 |
| `:red_circle:` | 🔴 |
| `:large_blue_circle:` | 🔵 |
| `:green_circle:` | 🟢 |
| `:yellow_circle:` | 🟡 |

## Atlassian 独自絵文字マッピング

Unicode 対応がないため、テキスト表現に変換する。

| shortName | 変換結果 |
|-----------|---------|
| `:plus:` | (pros) |
| `:minus:` | (cons) |
| `:note:` | (note) |

## マッピング外の shortName

上記マッピングに存在しない shortName は `:shortName:` の形式でそのまま残す。
