#!/usr/bin/env python3
"""Permission UI 表示回数の可視化 Web サーバ

port 18765 で起動、GET / で SVG 棒グラフ + 自律ストレッチ統計 HTML を返す。
外部ライブラリ不使用（純粋 SVG / HTML）。

自律ストレッチ長（avg_stretch）:
  permission UI と permission UI の間に Claude が自律的に実行した tool_use の数。
  値が大きいほど「割り込まれるまでに多くの作業を自律的にこなせた」ことを示す。
"""

import json
import re
import os
import statistics
from collections import defaultdict
from datetime import datetime, date, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

PERMISSION_LOG = os.path.expanduser("~/.claude/logs/permission.log")
SESSION_INDEX = os.path.expanduser("~/.claude/session-index.jsonl")
PORT = 18765


# ── データ読み込み ──────────────────────────────────────────────────────────────

def parse_ts(ts_str):
    return datetime.fromisoformat(ts_str.replace("Z", "+00:00"))


def load_sessions():
    """session-index.jsonl → {session_id: {pr_url, transcript}} を返す。
    同一 session_id の複数エントリは後勝ち（最新のpr_urlを採用）。"""
    sessions = {}
    if not os.path.exists(SESSION_INDEX):
        return sessions
    with open(SESSION_INDEX) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                sid = entry.get("session_id", "")
                if not sid:
                    continue
                pr_urls = entry.get("pr_urls", [])
                if isinstance(pr_urls, str):
                    pr_urls = [pr_urls] if pr_urls else []
                pr_url_single = entry.get("pr_url", "")
                if pr_url_single and pr_url_single not in pr_urls:
                    pr_urls.append(pr_url_single)
                transcript = entry.get("transcript", "")
                prev = sessions.get(sid, {})
                sessions[sid] = {
                    "pr_url": pr_urls[-1] if pr_urls else prev.get("pr_url", ""),
                    "transcript": transcript or prev.get("transcript", ""),
                }
            except json.JSONDecodeError:
                pass
    return sessions


def load_permission_timestamps_by_session():
    """permission.log → {session_id: [sorted datetime]} を返す。"""
    result = defaultdict(list)
    if not os.path.exists(PERMISSION_LOG):
        return result
    ts_re = re.compile(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)")
    sid_re = re.compile(r"session=(\S+)")
    with open(PERMISSION_LOG) as f:
        for line in f:
            tm = ts_re.match(line)
            sm = sid_re.search(line)
            if tm and sm:
                try:
                    result[sm.group(1)].append(parse_ts(tm.group(1)))
                except ValueError:
                    pass
    for sid in result:
        result[sid].sort()
    return result


def load_transcript_tool_uses(transcript_path):
    """transcript JSONL → tool_use が含まれる assistant メッセージの timestamp リスト（昇順）。"""
    timestamps = []
    if not transcript_path or not os.path.exists(transcript_path):
        return timestamps
    with open(transcript_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                if entry.get("type") != "assistant":
                    continue
                content = entry.get("message", {}).get("content", [])
                if any(c.get("type") == "tool_use" for c in content):
                    ts_str = entry.get("timestamp", "")
                    if ts_str:
                        timestamps.append(parse_ts(ts_str))
            except (json.JSONDecodeError, ValueError, KeyError):
                pass
    return sorted(timestamps)


# ── 集計 ───────────────────────────────────────────────────────────────────────

def compute_stretches(tool_use_times, perm_times):
    """permission UI 間の tool_use 数（ストレッチ長）リストを返す。

    perm_times には「この permission UI が表示された」タイムスタンプが並ぶ。
    各 permission UI は直前の tool_use 群の末尾に位置するため、
    前回 permission UI（または開始）から今回 permission UI までの tool_use 数をカウントする。
    """
    stretches = []
    prev = None
    for perm_ts in perm_times:
        if prev is None:
            count = sum(1 for t in tool_use_times if t <= perm_ts)
        else:
            count = sum(1 for t in tool_use_times if prev < t <= perm_ts)
        stretches.append(max(count, 1))  # 最低 1（permission 自体のツール呼び出し分）
        prev = perm_ts
    return stretches


def aggregate(from_dt=None, to_dt=None):
    """PR ごとの permission UI 回数 + 自律ストレッチ統計を集計する。

    Args:
        from_dt: フィルタ開始日時（UTC aware datetime）。None の場合フィルタなし。
        to_dt: フィルタ終了日時（UTC aware datetime）。None の場合フィルタなし。

    Returns:
        pr_stats: {pr_url: {perm_count, avg_stretch, median_stretch, stretches}}
        unmatched: PR URL に紐付かなかった permission UI 回数
        total: permission UI 総回数
    """
    sessions = load_sessions()
    perm_by_session = load_permission_timestamps_by_session()

    total_raw = sum(len(v) for v in perm_by_session.values())
    unmatched = 0
    pr_perm_counts = defaultdict(int)
    pr_stretches = defaultdict(list)

    for sid, perm_times in perm_by_session.items():
        # 日付フィルタ
        if from_dt is not None or to_dt is not None:
            filtered = []
            for pt in perm_times:
                if from_dt is not None and pt < from_dt:
                    continue
                if to_dt is not None and pt > to_dt:
                    continue
                filtered.append(pt)
            perm_times = filtered
        if not perm_times:
            continue

        session = sessions.get(sid, {})
        pr_url = session.get("pr_url", "")
        if not pr_url or pr_url == "https://github.com/org/repo/pull/123":
            unmatched += len(perm_times)
            continue
        pr_perm_counts[pr_url] += len(perm_times)
        transcript = session.get("transcript", "")
        if transcript:
            tool_times = load_transcript_tool_uses(transcript)
            pr_stretches[pr_url].extend(compute_stretches(tool_times, perm_times))

    total = sum(len(v) for v in perm_by_session.values())
    if from_dt is not None or to_dt is not None:
        total = sum(pr_perm_counts.values()) + unmatched

    pr_stats = {}
    for pr_url in pr_perm_counts:
        stretches = pr_stretches.get(pr_url, [])
        pr_stats[pr_url] = {
            "perm_count": pr_perm_counts[pr_url],
            "stretches": stretches,
            "avg": round(statistics.mean(stretches), 1) if stretches else None,
            "median": statistics.median(stretches) if stretches else None,
        }
    return pr_stats, unmatched, total


def aggregate_by_date(from_dt, to_dt):
    """日付でフィルタし、日別ストレッチ統計を昇順で返す。

    Returns:
        {date_str: {perm_count, avg, stretches}}  昇順ソート済み dict
    """
    sessions = load_sessions()
    perm_by_session = load_permission_timestamps_by_session()

    date_perm_counts = defaultdict(int)
    date_stretches = defaultdict(list)

    for sid, perm_times in perm_by_session.items():
        # 日付範囲フィルタ
        filtered = [
            pt for pt in perm_times
            if from_dt <= pt <= to_dt
        ]
        if not filtered:
            continue

        session = sessions.get(sid, {})
        transcript = session.get("transcript", "")
        tool_times = load_transcript_tool_uses(transcript) if transcript else []
        stretches = compute_stretches(tool_times, filtered)

        for i, perm_ts in enumerate(filtered):
            d = perm_ts.date().isoformat()
            date_perm_counts[d] += 1
            if i < len(stretches):
                date_stretches[d].append(stretches[i])

    result = {}
    for d in sorted(date_perm_counts.keys()):
        s = date_stretches.get(d, [])
        result[d] = {
            "perm_count": date_perm_counts[d],
            "stretches": s,
            "avg": round(statistics.mean(s), 1) if s else None,
        }
    return result


# ── 描画 ───────────────────────────────────────────────────────────────────────

def shorten_pr_url(url):
    m = re.match(r"https://github\.com/([^/]+)/([^/]+)/pull/(\d+)", url)
    return f"{m.group(1)}/{m.group(2)}#{m.group(3)}" if m else url


def generate_svg_bar_chart(pr_stats):
    """permission UI 回数の棒グラフ（降順）を生成。"""
    if not pr_stats:
        return "<p>PR URL が紐付いたデータがありません</p>"

    items = sorted(pr_stats.items(), key=lambda x: x[1]["perm_count"], reverse=True)
    max_val = max(s["perm_count"] for _, s in items)

    bar_height, bar_gap = 30, 10
    label_width, chart_width, count_width, padding = 240, 360, 40, 20
    total_height = (bar_height + bar_gap) * len(items) + padding * 2
    total_width = label_width + chart_width + count_width + padding * 2

    # count は bar エリア右端に固定して縦に揃える
    count_x = label_width + chart_width + 8

    bars = []
    for i, (url, stat) in enumerate(items):
        label = shorten_pr_url(url)
        count = stat["perm_count"]
        y = padding + i * (bar_height + bar_gap)
        bar_w = max(2, int((count / max_val) * chart_width))
        ty = y + bar_height // 2 + 5
        bars.append(
            f'<a href="{url}" target="_blank">'
            f'<text x="{label_width - 8}" y="{ty}" text-anchor="end" '
            f'font-size="12" fill="#60a5fa" text-decoration="underline">{label}</text>'
            f'</a>'
            f'<rect x="{label_width}" y="{y}" width="{bar_w}" height="{bar_height}" '
            f'fill="#3b82f6" rx="3"/>'
            f'<text x="{count_x}" y="{ty}" font-size="12" fill="#e2e8f0">{count}</text>'
        )

    bars_svg = "\n  ".join(bars)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{total_width}" height="{total_height}" '
        f'style="font-family: monospace;">\n  {bars_svg}\n</svg>'
    )


def generate_autonomy_table(pr_stats):
    """自律ストレッチ統計テーブルを生成（avg_stretch 降順）。"""
    if not pr_stats:
        return "<p>データがありません</p>"

    items = sorted(
        ((url, s) for url, s in pr_stats.items() if s["avg"] is not None),
        key=lambda x: x[1]["avg"],
        reverse=True,
    )
    if not items:
        return "<p>ストレッチデータがありません（transcript が取得できていない可能性があります）</p>"

    rows = []
    for url, stat in items:
        label = shorten_pr_url(url)
        avg = f"{stat['avg']:.1f}" if stat["avg"] is not None else "—"
        med = stat["median"] if stat["median"] is not None else "—"
        rows.append(
            f'<tr>'
            f'<td><a href="{url}" target="_blank">{label}</a></td>'
            f'<td style="text-align:right">{stat["perm_count"]}</td>'
            f'<td style="text-align:right">{avg}</td>'
            f'<td style="text-align:right">{med}</td>'
            f'</tr>'
        )

    rows_html = "\n".join(rows)
    return f"""
<table style="width:auto">
  <thead>
    <tr>
      <th>PR</th>
      <th style="width:110px">permission UI 回数</th>
      <th style="width:110px">avg ストレッチ長</th>
      <th style="width:110px">median ストレッチ長</th>
    </tr>
  </thead>
  <tbody>
{rows_html}
  </tbody>
</table>
<p class="note">ストレッチ長 = permission UI と permission UI の間に Claude が自律実行した tool_use 数。大きいほど自律的。</p>
"""


def generate_trend_line_chart(date_stats):
    """日別 avg ストレッチ長の折れ線グラフ（純粋 SVG）。"""
    # avg データが存在する日のみ対象
    items = [(d, s) for d, s in date_stats.items() if s["avg"] is not None]

    if len(items) <= 1:
        return "<p>データが不足しています（2 日以上のデータが必要です）</p>"

    pad_left, pad_right, pad_top, pad_bottom = 50, 20, 20, 50
    chart_w, chart_h = 600, 200
    total_w = pad_left + chart_w + pad_right
    total_h = pad_top + chart_h + pad_bottom

    avgs = [s["avg"] for _, s in items]
    max_avg = max(avgs)
    min_avg = min(avgs)
    avg_range = max_avg - min_avg if max_avg != min_avg else 1.0

    n = len(items)
    x_step = chart_w / (n - 1)

    def cx(i):
        return pad_left + i * x_step

    def cy(v):
        return pad_top + chart_h - ((v - min_avg) / avg_range) * chart_h

    # 折れ線の点列
    points = " ".join(f"{cx(i):.1f},{cy(s['avg']):.1f}" for i, (_, s) in enumerate(items))

    # X 軸ラベル（最大 10 本まで等間隔）
    label_step = max(1, n // 10)
    x_labels = []
    for i, (d, _) in enumerate(items):
        if i % label_step == 0 or i == n - 1:
            lx = cx(i)
            ly = pad_top + chart_h + 16
            short = d[5:]  # MM-DD
            x_labels.append(
                f'<text x="{lx:.1f}" y="{ly}" text-anchor="middle" '
                f'font-size="10" fill="#94a3b8">{short}</text>'
            )

    # Y 軸ラベル（min, max）
    y_labels = [
        f'<text x="{pad_left - 6}" y="{pad_top + chart_h:.1f}" text-anchor="end" '
        f'font-size="10" fill="#94a3b8">{min_avg:.1f}</text>',
        f'<text x="{pad_left - 6}" y="{pad_top:.1f}" text-anchor="end" '
        f'font-size="10" fill="#94a3b8">{max_avg:.1f}</text>',
    ]

    # データ点（circle + tooltip）
    circles = []
    for i, (d, s) in enumerate(items):
        px, py = cx(i), cy(s["avg"])
        title = f"{d}: avg={s['avg']:.1f}, perm={s['perm_count']}"
        circles.append(
            f'<circle cx="{px:.1f}" cy="{py:.1f}" r="4" fill="#3b82f6" stroke="#60a5fa" stroke-width="1">'
            f'<title>{title}</title>'
            f'</circle>'
        )

    # 軸線
    axes = (
        f'<line x1="{pad_left}" y1="{pad_top}" x2="{pad_left}" y2="{pad_top + chart_h}" '
        f'stroke="#2d3748" stroke-width="1"/>'
        f'<line x1="{pad_left}" y1="{pad_top + chart_h}" x2="{pad_left + chart_w}" y2="{pad_top + chart_h}" '
        f'stroke="#2d3748" stroke-width="1"/>'
    )

    inner = "\n  ".join(
        [axes]
        + x_labels
        + y_labels
        + [
            f'<polyline points="{points}" fill="none" stroke="#3b82f6" stroke-width="2"/>',
        ]
        + circles
    )

    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{total_w}" height="{total_h}" '
        f'style="font-family: monospace;">\n  {inner}\n</svg>'
    )


def generate_trend_table(date_stats):
    """日別テーブル（昇順）: 日付 / perm 回数 / avg ストレッチ長。"""
    if not date_stats:
        return "<p>データがありません</p>"

    rows = []
    for d, s in date_stats.items():
        avg = f"{s['avg']:.1f}" if s["avg"] is not None else "—"
        rows.append(
            f'<tr>'
            f'<td>{d}</td>'
            f'<td style="text-align:right">{s["perm_count"]}</td>'
            f'<td style="text-align:right">{avg}</td>'
            f'</tr>'
        )

    rows_html = "\n".join(rows)
    return f"""
<table style="width:auto">
  <thead>
    <tr>
      <th>日付</th>
      <th style="width:110px">permission UI 回数</th>
      <th style="width:110px">avg ストレッチ長</th>
    </tr>
  </thead>
  <tbody>
{rows_html}
  </tbody>
</table>
"""


def generate_html(from_dt=None, to_dt=None):
    # デフォルト期間: 今日から 30 日前〜今日
    today = date.today()
    if to_dt is None:
        to_dt = datetime(today.year, today.month, today.day, 23, 59, 59, tzinfo=timezone.utc)
    if from_dt is None:
        d30 = today - timedelta(days=30)
        from_dt = datetime(d30.year, d30.month, d30.day, 0, 0, 0, tzinfo=timezone.utc)

    from_val = from_dt.date().isoformat()
    to_val = to_dt.date().isoformat()

    pr_stats, unmatched, total = aggregate(from_dt, to_dt)
    pr_count = len(pr_stats)
    svg = generate_svg_bar_chart(pr_stats)
    table = generate_autonomy_table(pr_stats)

    date_stats = aggregate_by_date(from_dt, to_dt)
    trend_chart = generate_trend_line_chart(date_stats)
    trend_table = generate_trend_table(date_stats)

    date_form = f"""<form method="get" style="display:flex; gap:8px; align-items:center; margin-bottom:16px">
  <input type="date" name="from" value="{from_val}" style="background:#252d3d; color:#e2e8f0; border:1px solid #2d3748; padding:4px 8px; border-radius:4px">
  <span>〜</span>
  <input type="date" name="to" value="{to_val}" style="background:#252d3d; color:#e2e8f0; border:1px solid #2d3748; padding:4px 8px; border-radius:4px">
  <button type="submit" style="background:#3b82f6; color:#fff; border:none; padding:4px 12px; border-radius:4px; cursor:pointer">適用</button>
</form>"""

    return f"""<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="10">
  <title>Claude 自律度ダッシュボード</title>
  <style>
    body {{ font-family: monospace; padding: 20px; background: #0f1117; color: #e2e8f0; }}
    h1, h2 {{ margin-top: 0; }}
    h2 {{ margin-top: 24px; font-size: 1rem; color: #94a3b8; }}
    .card {{ background: #1e2330; padding: 20px; border-radius: 8px; margin-bottom: 20px; overflow-x: auto; }}
    .summary {{ line-height: 1.8; }}
    table {{ border-collapse: collapse; width: 100%; font-size: 13px; }}
    th, td {{ padding: 6px 12px; border-bottom: 1px solid #2d3748; }}
    th {{ background: #252d3d; text-align: left; color: #94a3b8; }}
    tr:hover td {{ background: #2a3347; }}
    a {{ color: #60a5fa; }}
    .note {{ font-size: 11px; color: #64748b; margin-top: 8px; }}
  </style>
</head>
<body>
  <h1>Claude 自律度ダッシュボード</h1>

  {date_form}

  <div class="card summary">
    <strong>総 permission UI 回数:</strong> {total}<br>
    <strong>PR 件数:</strong> {pr_count}<br>
    <strong>未マッチ（PR URL なし）:</strong> {unmatched}<br>
    <small>10 秒ごとに自動更新</small>
  </div>

  <h2>時系列トレンド（日別 avg ストレッチ長）</h2>
  <div class="card">
    {trend_chart}
  </div>

  <h2>日別統計</h2>
  <div class="card">
    {trend_table}
  </div>

  <h2>Permission UI 回数（PR 別）</h2>
  <div class="card">
    {svg}
  </div>

  <h2>自律ストレッチ統計（PR 別）</h2>
  <div class="card">
    {table}
  </div>
</body>
</html>"""


# ── サーバ ─────────────────────────────────────────────────────────────────────

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            params = parse_qs(parsed.query)
            from_dt = None
            to_dt = None
            try:
                if "from" in params:
                    d = date.fromisoformat(params["from"][0])
                    from_dt = datetime(d.year, d.month, d.day, 0, 0, 0, tzinfo=timezone.utc)
                if "to" in params:
                    d = date.fromisoformat(params["to"][0])
                    to_dt = datetime(d.year, d.month, d.day, 23, 59, 59, tzinfo=timezone.utc)
            except (ValueError, IndexError):
                pass

            html = generate_html(from_dt, to_dt).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html)))
            self.end_headers()
            self.wfile.write(html)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", PORT), Handler)
    print(f"Listening on http://localhost:{PORT}", flush=True)
    server.serve_forever()
