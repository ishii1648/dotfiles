#!/usr/bin/env python3
"""Permission UI 表示回数の可視化 Web サーバ

port 18765 で起動、GET / で SVG 棒グラフ HTML を返す。
外部ライブラリ不使用（純粋 SVG）。
"""

import json
import re
import os
from collections import defaultdict
from http.server import BaseHTTPRequestHandler, HTTPServer

PERMISSION_LOG = os.path.expanduser("~/.claude/logs/permission.log")
SESSION_INDEX = os.path.expanduser("~/.claude/session-index.jsonl")
PORT = 18765


def load_session_index():
    """session_id -> pr_url のマップを構築（pr_url が空でない最新エントリを採用）"""
    mapping = {}
    if not os.path.exists(SESSION_INDEX):
        return mapping
    with open(SESSION_INDEX) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                session_id = entry.get("session_id", "")
                # フィールドは pr_urls (配列) または pr_url (文字列) の両方に対応
                pr_urls = entry.get("pr_urls", [])
                if isinstance(pr_urls, str):
                    pr_urls = [pr_urls] if pr_urls else []
                pr_url = entry.get("pr_url", "")
                if pr_url and pr_url not in pr_urls:
                    pr_urls.append(pr_url)
                if session_id and pr_urls:
                    # 最後の（最新の）PR URL を採用
                    mapping[session_id] = pr_urls[-1]
            except json.JSONDecodeError:
                pass
    return mapping


def load_permission_log():
    """session_id -> count のマップを構築"""
    counts = defaultdict(int)
    if not os.path.exists(PERMISSION_LOG):
        return counts
    session_re = re.compile(r"session=(\S+)")
    with open(PERMISSION_LOG) as f:
        for line in f:
            m = session_re.search(line)
            if m:
                counts[m.group(1)] += 1
    return counts


def shorten_pr_url(url):
    """https://github.com/owner/repo/pull/N -> owner/repo#N"""
    m = re.match(r"https://github\.com/([^/]+)/([^/]+)/pull/(\d+)", url)
    if m:
        return f"{m.group(1)}/{m.group(2)}#{m.group(3)}"
    return url


def aggregate():
    """PR URL ごとの permission UI 表示回数を集計。{full_url: count} を返す"""
    session_to_pr = load_session_index()
    session_to_count = load_permission_log()
    pr_counts = defaultdict(int)
    unmatched = 0
    for session_id, count in session_to_count.items():
        pr_url = session_to_pr.get(session_id, "")
        if pr_url:
            pr_counts[pr_url] += count
        else:
            unmatched += count
    return pr_counts, unmatched, sum(session_to_count.values())


def generate_svg_bar_chart(pr_counts):
    """純粋な SVG 棒グラフを生成。pr_counts は {full_url: count}"""
    if not pr_counts:
        return "<p>PR URL が紐付いたデータがありません</p>"

    items = sorted(pr_counts.items(), key=lambda x: x[1], reverse=True)

    max_val = max(v for _, v in items)
    bar_height = 30
    bar_gap = 10
    label_width = 240
    chart_width = 400
    padding = 20

    total_height = (bar_height + bar_gap) * len(items) + padding * 2
    total_width = label_width + chart_width + padding * 2

    bars = []
    for i, (url, count) in enumerate(items):
        label = shorten_pr_url(url)
        y = padding + i * (bar_height + bar_gap)
        bar_w = max(2, int((count / max_val) * chart_width))
        ty = y + bar_height // 2 + 5
        bars.append(
            f'<a href="{url}" target="_blank">'
            f'<text x="{label_width - 8}" y="{ty}" '
            f'text-anchor="end" font-size="12" fill="#2563eb" '
            f'text-decoration="underline">{label}</text>'
            f'</a>'
            f'<rect x="{label_width}" y="{y}" width="{bar_w}" height="{bar_height}" '
            f'fill="#4f8ef7" rx="3"/>'
            f'<text x="{label_width + bar_w + 6}" y="{ty}" '
            f'font-size="12" fill="#333">{count}</text>'
        )

    bars_svg = "\n  ".join(bars)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'width="{total_width}" height="{total_height}" '
        f'style="font-family: monospace;">\n  {bars_svg}\n</svg>'
    )


def generate_html():
    pr_counts, unmatched, total = aggregate()
    pr_count = len(pr_counts)
    svg = generate_svg_bar_chart(pr_counts)
    return f"""<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="10">
  <title>Permission UI 回数ダッシュボード</title>
  <style>
    body {{ font-family: monospace; padding: 20px; background: #f5f5f5; color: #333; }}
    h1 {{ margin-top: 0; }}
    .summary {{ background: white; padding: 15px 20px; border-radius: 8px; margin-bottom: 20px; line-height: 1.8; }}
    .chart {{ background: white; padding: 20px; border-radius: 8px; overflow-x: auto; }}
  </style>
</head>
<body>
  <h1>Permission UI 表示回数ダッシュボード</h1>
  <div class="summary">
    <strong>総 permission UI 回数:</strong> {total}<br>
    <strong>PR 件数:</strong> {pr_count}<br>
    <strong>未マッチ（PR URL なし）:</strong> {unmatched}<br>
    <small>10 秒ごとに自動更新</small>
  </div>
  <div class="chart">
    {svg}
  </div>
</body>
</html>"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            html = generate_html().encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html)))
            self.end_headers()
            self.wfile.write(html)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, fmt, *args):
        pass  # アクセスログ抑制


if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Listening on http://localhost:{PORT}", flush=True)
    server.serve_forever()
