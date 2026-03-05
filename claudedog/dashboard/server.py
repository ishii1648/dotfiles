#!/usr/bin/env python3
"""Permission UI 表示回数の可視化 Web サーバ

port 18765 で起動、GET / で PR 別統計 HTML を返す。
外部ライブラリ不使用（純粋 HTML）。
"""

import json
import re
import os
from collections import defaultdict
from datetime import datetime, date, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

PERMISSION_LOG = os.path.expanduser("~/.claude/logs/permission.log")
SESSION_INDEX = os.path.expanduser("~/.claude/session-index.jsonl")
PORT = 18765
JST = timezone(timedelta(hours=9))

# PR を挟まないリポジトリは計測から除外する
EXCLUDED_REPOS = {"ishii1648/dotfiles"}


def is_excluded_session(session):
    """EXCLUDED_REPOS に含まれるリポジトリのセッションかどうかを判定する。

    - pr_url がある場合: pr_url のみで照合（他リポジトリの PR を誤除外しない）
    - pr_url がない場合: transcript パスで照合（PR を挟まない repos の除外用）
      transcript パスは "owner/repo" の "/" を "-" に置換した文字列を含む。
    """
    pr_url = session.get("pr_url", "")
    transcript = session.get("transcript", "")
    has_valid_pr = bool(pr_url) and pr_url != "https://github.com/org/repo/pull/123"
    for repo in EXCLUDED_REPOS:
        if has_valid_pr:
            if repo in pr_url:
                return True
        else:
            if repo.replace("/", "-") in transcript:
                return True
    return False


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
                    "is_subagent": bool(entry.get("parent_session_id", "")),
                    "is_ghost": not has_user_message(transcript or prev.get("transcript", "")),
                }
            except json.JSONDecodeError:
                pass
    return sessions


_ts_re = re.compile(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z)")
_sid_re = re.compile(r"session=(\S+)")
_tool_re = re.compile(r"tool=(\S+)")


def load_permission_entries_by_session():
    """permission.log → {session_id: [{"ts": datetime, "tool": str}, ...]} を返す。"""
    result = defaultdict(list)
    if not os.path.exists(PERMISSION_LOG):
        return result
    with open(PERMISSION_LOG) as f:
        for line in f:
            tm = _ts_re.match(line)
            sm = _sid_re.search(line)
            if tm and sm:
                try:
                    tool_m = _tool_re.search(line)
                    tool = tool_m.group(1) if tool_m else "unknown"
                    result[sm.group(1)].append({
                        "ts": parse_ts(tm.group(1)),
                        "tool": tool,
                    })
                except ValueError:
                    pass
    for sid in result:
        result[sid].sort(key=lambda e: e["ts"])
    return result


def load_permission_timestamps_by_session():
    """permission.log → {session_id: [sorted datetime]} を返す。"""
    entries = load_permission_entries_by_session()
    return {sid: [e["ts"] for e in es] for sid, es in entries.items()}


def is_human_text_message(entry):
    """type:user エントリが人間が打ったテキストかを判定（コマンド出力・tool_result のみは除外）。"""
    if entry.get("type") != "user":
        return False
    content = entry.get("message", {}).get("content", "")
    if "<local-command-" in str(content):
        return False
    if isinstance(content, list):
        types = [c.get("type") for c in content if isinstance(c, dict)]
        if types and all(t == "tool_result" for t in types):
            return False
    return True


def has_user_message(transcript_path):
    """transcript に type: "user" エントリが存在するか確認する。
    file-history-snapshot のみのゴーストセッションは False を返す。"""
    if not transcript_path or not os.path.exists(transcript_path):
        return False
    with open(transcript_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                if json.loads(line).get("type") == "user":
                    return True
            except json.JSONDecodeError:
                pass
    return False


def load_transcript_stats(transcript_path):
    """transcript JSONL を一回のパスで全指標を収集する。

    Returns:
      {
        "tool_use_total": int,          # tool_use アイテムの合計数（perm_rate 分母）
        "mid_session_msgs": int,        # 初回プロンプト以降の人間が打ったメッセージ数
        "ask_user_question": int,       # AskUserQuestion tool_use 回数
        "tool_use_times": [datetime],   # tool_use が発生した assistant メッセージのタイムスタンプ
      }
    """
    tool_use_total = 0
    mid_session_msgs = 0
    ask_user_question = 0
    tool_use_times = []
    first_user_seen = False

    if not transcript_path or not os.path.exists(transcript_path):
        return {
            "tool_use_total": tool_use_total,
            "mid_session_msgs": mid_session_msgs,
            "ask_user_question": ask_user_question,
            "tool_use_times": tool_use_times,
        }

    with open(transcript_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                entry_type = entry.get("type")

                if entry_type == "user":
                    if not first_user_seen:
                        first_user_seen = True
                    else:
                        if is_human_text_message(entry):
                            mid_session_msgs += 1

                elif entry_type == "assistant":
                    content = entry.get("message", {}).get("content", [])
                    if not isinstance(content, list):
                        content = []
                    has_tool_use = False
                    for item in content:
                        if not isinstance(item, dict):
                            continue
                        if item.get("type") == "tool_use":
                            tool_use_total += 1
                            if item.get("name") == "ask-user-question":
                                ask_user_question += 1
                            has_tool_use = True
                    if has_tool_use:
                        ts_str = entry.get("timestamp", "")
                        if ts_str:
                            try:
                                tool_use_times.append(parse_ts(ts_str))
                            except ValueError:
                                pass

            except (json.JSONDecodeError, ValueError, KeyError):
                pass

    return {
        "tool_use_total": tool_use_total,
        "mid_session_msgs": mid_session_msgs,
        "ask_user_question": ask_user_question,
        "tool_use_times": sorted(tool_use_times),
    }


# ── 集計 ───────────────────────────────────────────────────────────────────────

DUMMY_PR_URL = "https://github.com/org/repo/pull/123"


def aggregate(from_dt=None, to_dt=None):
    """PR ごとの permission UI 回数を集計する。"""
    sessions = load_sessions()
    perm_by_session = load_permission_timestamps_by_session()

    # transcript キャッシュ（重複ロードを防ぐ）
    transcript_cache = {}

    # Pass 1: 全セッションを走査して新指標を蓄積
    pr_session_count = defaultdict(int)
    pr_tool_use_total = defaultdict(int)
    pr_mid_session = defaultdict(int)
    pr_ask_user = defaultdict(int)

    for sid, session in sessions.items():
        if is_excluded_session(session):
            continue
        if session.get("is_subagent"):
            continue
        if session.get("is_ghost"):
            continue
        pr_url = session.get("pr_url", "")
        if not pr_url or pr_url == DUMMY_PR_URL:
            continue
        pr_session_count[pr_url] += 1
        t = session.get("transcript", "")
        if t:
            stats = transcript_cache.setdefault(t, load_transcript_stats(t))
            pr_tool_use_total[pr_url] += stats["tool_use_total"]
            pr_mid_session[pr_url] += stats["mid_session_msgs"]
            pr_ask_user[pr_url] += stats["ask_user_question"]

    # Pass 2: permission イベント集計
    unmatched = 0
    pr_perm_counts = defaultdict(int)

    for sid, perm_times in perm_by_session.items():
        if from_dt is not None or to_dt is not None:
            perm_times = [
                pt for pt in perm_times
                if (from_dt is None or pt >= from_dt) and (to_dt is None or pt <= to_dt)
            ]
        if not perm_times:
            continue

        session = sessions.get(sid, {})
        if is_excluded_session(session):
            continue
        pr_url = session.get("pr_url", "")
        if not pr_url or pr_url == DUMMY_PR_URL:
            unmatched += len(perm_times)
            continue
        pr_perm_counts[pr_url] += len(perm_times)

    total = sum(pr_perm_counts.values()) + unmatched

    all_pr_urls = set(pr_session_count) | set(pr_perm_counts)
    pr_stats = {}
    for pr_url in all_pr_urls:
        tool_use_total = pr_tool_use_total.get(pr_url, 0)
        perm_count = pr_perm_counts.get(pr_url, 0)
        pr_stats[pr_url] = {
            "perm_count": perm_count,
            "tool_use_total": tool_use_total,
            "perm_rate": round(perm_count / tool_use_total * 100, 1) if tool_use_total else None,
            "mid_session_msgs": pr_mid_session.get(pr_url, 0),
            "ask_user_question": pr_ask_user.get(pr_url, 0),
            "session_count": pr_session_count.get(pr_url, 0),
        }
    return pr_stats, unmatched, total


def _aggregate_time_series(from_dt, to_dt, key_fn):
    """日別・週別で perm_count と tool_use_total を集計する共通実装。"""
    sessions = load_sessions()
    perm_by_session = load_permission_timestamps_by_session()
    transcript_cache = {}

    key_perm = defaultdict(int)
    key_tool_use = defaultdict(int)

    # tool_use をキー別に集計
    for sid, session in sessions.items():
        if is_excluded_session(session):
            continue
        t = session.get("transcript", "")
        if t:
            stats = transcript_cache.setdefault(t, load_transcript_stats(t))
            for ts in stats["tool_use_times"]:
                if from_dt <= ts <= to_dt:
                    key_tool_use[key_fn(ts)] += 1

    # perm をキー別に集計
    for sid, perm_times in perm_by_session.items():
        session = sessions.get(sid, {})
        if is_excluded_session(session):
            continue
        for pt in perm_times:
            if from_dt <= pt <= to_dt:
                key_perm[key_fn(pt)] += 1

    all_keys = sorted(set(key_perm) | set(key_tool_use))
    result = {}
    for k in all_keys:
        pc = key_perm[k]
        tu = key_tool_use[k]
        result[k] = {
            "perm_count": pc,
            "tool_use_total": tu,
            "perm_rate": round(pc / tu * 100, 1) if tu else None,
        }
    return result


def aggregate_by_date(from_dt, to_dt):
    return _aggregate_time_series(
        from_dt, to_dt,
        lambda ts: ts.astimezone(JST).date().isoformat()
    )


def aggregate_by_week(from_dt, to_dt):
    return _aggregate_time_series(
        from_dt, to_dt,
        lambda ts: ts.astimezone(JST).strftime("%G-W%V")
    )


def aggregate_by_tool(from_dt=None, to_dt=None):
    """tool_name ごとの permission UI 発生件数を返す。"""
    sessions = load_sessions()
    entries_by_session = load_permission_entries_by_session()
    tool_counts = defaultdict(int)
    for sid, entries in entries_by_session.items():
        session = sessions.get(sid, {})
        if is_excluded_session(session):
            continue
        for entry in entries:
            ts = entry["ts"]
            if from_dt is not None and ts < from_dt:
                continue
            if to_dt is not None and ts > to_dt:
                continue
            tool_counts[entry["tool"]] += 1
    return dict(tool_counts)


# ── 描画 ───────────────────────────────────────────────────────────────────────

def shorten_pr_url(url):
    m = re.match(r"https://github\.com/([^/]+)/([^/]+)/pull/(\d+)", url)
    return f"{m.group(1)}/{m.group(2)}#{m.group(3)}" if m else url


def generate_bar_chart(items, format_fn, color="#3b82f6"):
    """PR 別棒グラフ（純粋 SVG）。

    Args:
        items: [(label, value), ...] - value が None のバーはスキップ
        format_fn: value → 表示文字列
        color: バーの色
    """
    items = [(l, v) for l, v in items if v is not None]
    if not items:
        return "<p>データがありません</p>"

    bar_w, bar_gap = 36, 6
    pad_left, pad_right, pad_top, pad_bottom = 52, 10, 24, 76
    chart_h = 150
    n = len(items)
    chart_w = n * (bar_w + bar_gap) - bar_gap
    total_w = pad_left + chart_w + pad_right
    total_h = pad_top + chart_h + pad_bottom

    max_v = max(v for _, v in items)
    v_range = max_v if max_v != 0 else 1.0

    def bx(i):
        return pad_left + i * (bar_w + bar_gap)

    def bh(v):
        return max((v / v_range) * chart_h, 2)

    parts = []
    parts.append(
        f'<line x1="{pad_left}" y1="{pad_top}" x2="{pad_left}" y2="{pad_top + chart_h}" '
        f'stroke="#2d3748" stroke-width="1"/>'
        f'<line x1="{pad_left}" y1="{pad_top + chart_h}" '
        f'x2="{total_w - pad_right}" y2="{pad_top + chart_h}" stroke="#2d3748" stroke-width="1"/>'
    )
    parts.append(
        f'<text x="{pad_left - 6}" y="{pad_top + chart_h}" text-anchor="end" '
        f'font-size="11" fill="#64748b">0</text>'
    )
    parts.append(
        f'<text x="{pad_left - 6}" y="{pad_top + 8}" text-anchor="end" '
        f'font-size="11" fill="#64748b">{format_fn(max_v)}</text>'
    )

    for i, (label, v) in enumerate(items):
        h = bh(v)
        x = bx(i)
        y = pad_top + chart_h - h
        cx = x + bar_w / 2
        parts.append(
            f'<rect x="{x}" y="{y:.1f}" width="{bar_w}" height="{h:.1f}" '
            f'fill="{color}" rx="2" opacity="0.85">'
            f'<title>{label}: {format_fn(v)}</title></rect>'
        )
        parts.append(
            f'<text x="{cx:.1f}" y="{y - 4:.1f}" text-anchor="middle" '
            f'font-size="10" fill="#94a3b8">{format_fn(v)}</text>'
        )
        parts.append(
            f'<text x="{cx:.1f}" y="{pad_top + chart_h + 14}" text-anchor="end" font-size="11" '
            f'fill="#94a3b8" transform="rotate(-40 {cx:.1f} {pad_top + chart_h + 14})">'
            f'{label}</text>'
        )

    inner = "\n  ".join(parts)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{total_w}" height="{total_h}" '
        f'style="font-family: monospace; display:block;">\n  {inner}\n</svg>'
    )


def generate_perm_rate_line_chart(stats, short_label_fn):
    """perm_rate の折れ線グラフ（純粋 SVG）。

    Args:
        stats: {key: {"perm_rate": float|None, ...}, ...} - キー昇順
        short_label_fn: key → X軸表示文字列
    """
    items = [(k, v["perm_rate"]) for k, v in stats.items() if v["perm_rate"] is not None]
    if not items:
        return "<p>データがありません</p>"

    pad_left, pad_right, pad_top, pad_bottom = 65, 60, 20, 60
    chart_w, chart_h = 600, 200
    total_w = pad_left + chart_w + pad_right
    total_h = pad_top + chart_h + pad_bottom

    n = len(items)
    max_v = max(v for _, v in items)
    min_v = min(v for _, v in items)
    v_range = max_v - min_v if max_v != min_v else 1.0

    def px(i):
        return pad_left + (i / max(n - 1, 1)) * chart_w

    def py(v):
        return pad_top + chart_h - ((v - min_v) / v_range) * chart_h

    parts = []
    # 軸
    parts.append(
        f'<line x1="{pad_left}" y1="{pad_top}" x2="{pad_left}" y2="{pad_top + chart_h}" '
        f'stroke="#2d3748" stroke-width="1"/>'
        f'<line x1="{pad_left}" y1="{pad_top + chart_h}" '
        f'x2="{pad_left + chart_w}" y2="{pad_top + chart_h}" stroke="#2d3748" stroke-width="1"/>'
    )
    # Y軸ラベル
    parts.append(
        f'<text x="{pad_left - 8}" y="{pad_top + chart_h}" text-anchor="end" '
        f'font-size="11" fill="#64748b">{min_v:.1f}%</text>'
    )
    parts.append(
        f'<text x="{pad_left - 8}" y="{pad_top + 8}" text-anchor="end" '
        f'font-size="11" fill="#64748b">{max_v:.1f}%</text>'
    )
    # polyline
    points = " ".join(f"{px(i):.1f},{py(v):.1f}" for i, (_, v) in enumerate(items))
    parts.append(
        f'<polyline points="{points}" fill="none" stroke="#ef4444" stroke-width="2"/>'
    )
    # データ点
    for i, (key, v) in enumerate(items):
        x = px(i)
        y = py(v)
        label = short_label_fn(key)
        parts.append(
            f'<circle cx="{x:.1f}" cy="{y:.1f}" r="4" fill="#ef4444">'
            f'<title>{key}: {v:.1f}%</title></circle>'
        )
        # X軸ラベル（斜め）
        parts.append(
            f'<text x="{x:.1f}" y="{pad_top + chart_h + 14}" text-anchor="end" font-size="11" '
            f'fill="#94a3b8" transform="rotate(-40 {x:.1f} {pad_top + chart_h + 14})">'
            f'{label}</text>'
        )

    inner = "\n  ".join(parts)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{total_w}" height="{total_h}" '
        f'style="font-family: monospace; display:block;">\n  {inner}\n</svg>'
    )


def generate_tool_table(tool_counts):
    """ツール別 permission UI 件数テーブルを生成（件数降順）。"""
    if not tool_counts:
        return "<p>データがありません</p>"

    sorted_tools = sorted(tool_counts.items(), key=lambda x: x[1], reverse=True)
    total = sum(v for _, v in sorted_tools)

    rows = []
    for tool, count in sorted_tools:
        pct = round(count / total * 100, 1) if total else 0
        rows.append(
            f'<tr>'
            f'<td>{tool}</td>'
            f'<td style="text-align:right">{count}</td>'
            f'<td style="text-align:right">{pct}%</td>'
            f'</tr>'
        )

    rows_html = "\n".join(rows)
    return f"""
<table style="width:auto">
  <thead>
    <tr>
      <th>ツール</th>
      <th style="width:100px">件数</th>
      <th style="width:100px">割合</th>
    </tr>
  </thead>
  <tbody>
{rows_html}
  </tbody>
</table>"""


def generate_pr_table(pr_stats):
    """PR 別統計テーブルを生成（perm UI 発生率 昇順）。"""
    if not pr_stats:
        return "<p>データがありません</p>"

    items = sorted(
        pr_stats.items(),
        key=lambda x: x[1]["perm_rate"] if x[1]["perm_rate"] is not None else float("inf"),
    )

    rows = []
    for url, stat in items:
        label = shorten_pr_url(url)
        perm_rate = f"{stat['perm_rate']:.1f}%" if stat.get("perm_rate") is not None else "—"
        rows.append(
            f'<tr>'
            f'<td><a href="{url}" target="_blank">{label}</a></td>'
            f'<td style="text-align:right">{stat["perm_count"]}</td>'
            f'<td style="text-align:right">{stat.get("session_count", 0)}</td>'
            f'<td style="text-align:right">{stat.get("mid_session_msgs", 0)}</td>'
            f'<td style="text-align:right">{perm_rate}</td>'
            f'<td style="text-align:right">{stat.get("ask_user_question", 0)}</td>'
            f'</tr>'
        )

    rows_html = "\n".join(rows)
    return f"""
<table style="width:auto">
  <thead>
    <tr>
      <th>PR</th>
      <th style="width:110px">permission UI 回数</th>
      <th style="width:90px">セッション数</th>
      <th style="width:130px">mid-session msgs</th>
      <th style="width:120px">perm UI 発生率</th>
      <th style="width:130px">AskUserQuestion</th>
    </tr>
  </thead>
  <tbody>
{rows_html}
  </tbody>
</table>
<p class="note">perm UI 発生率 = permission UI 回数 / tool_use 総数（%）。低いほど自律的。mid-session msgs = 初回プロンプト以降にユーザーが送信したテキストメッセージ数。</p>
"""


def generate_html(from_dt=None, to_dt=None):
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
    pr_table = generate_pr_table(pr_stats)

    tool_counts = {k: v for k, v in aggregate_by_tool(from_dt, to_dt).items() if k != "unknown"}
    sorted_tools = sorted(tool_counts.items(), key=lambda x: x[1], reverse=True)
    chart_by_tool = generate_bar_chart(
        sorted_tools,
        lambda v: str(int(v)), color="#06b6d4",
    )
    table_by_tool = generate_tool_table(tool_counts)

    day_stats = aggregate_by_date(from_dt, to_dt)
    week_stats = aggregate_by_week(from_dt, to_dt)
    day_chart = generate_perm_rate_line_chart(day_stats, lambda k: k[5:7] + "/" + k[8:10])
    week_chart = generate_perm_rate_line_chart(week_stats, lambda k: k)

    # perm_rate 昇順で PR を固定順序に並べてチャート生成
    sorted_prs = sorted(
        pr_stats.items(),
        key=lambda x: x[1]["perm_rate"] if x[1]["perm_rate"] is not None else float("inf"),
    )
    labels = [(url, shorten_pr_url(url)) for url, _ in sorted_prs]

    chart_perm_rate = generate_bar_chart(
        [(lbl, s["perm_rate"]) for (url, lbl), (_, s) in zip(labels, sorted_prs)],
        lambda v: f"{v:.1f}%", color="#ef4444",
    )
    chart_perm_count = generate_bar_chart(
        [(lbl, s["perm_count"]) for (url, lbl), (_, s) in zip(labels, sorted_prs)],
        lambda v: str(int(v)), color="#f97316",
    )
    chart_sessions = generate_bar_chart(
        [(lbl, s.get("session_count", 0)) for (url, lbl), (_, s) in zip(labels, sorted_prs)],
        lambda v: str(int(v)), color="#8b5cf6",
    )
    chart_mid = generate_bar_chart(
        [(lbl, s.get("mid_session_msgs", 0)) for (url, lbl), (_, s) in zip(labels, sorted_prs)],
        lambda v: str(int(v)), color="#eab308",
    )
    chart_ask = generate_bar_chart(
        [(lbl, s.get("ask_user_question", 0)) for (url, lbl), (_, s) in zip(labels, sorted_prs)],
        lambda v: str(int(v)), color="#22c55e",
    )

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
    .definition {{ border-left: 3px solid #3b82f6; line-height: 1.8; }}
    .definition strong {{ font-size: 1rem; color: #93c5fd; }}
    .definition-sub {{ color: #94a3b8; font-size: 12px; }}
    .chart-grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }}
    .chart-card {{ background: #1e2330; padding: 16px 20px; border-radius: 8px; overflow-x: auto; }}
    .chart-title {{ font-size: 0.85rem; color: #94a3b8; margin: 0 0 12px 0; }}
    .tab-btn {{ background: #252d3d; color: #94a3b8; border: 1px solid #2d3748; padding: 4px 12px; border-radius: 4px; cursor: pointer; font-family: monospace; }}
    .tab-btn.active {{ background: #3b82f6; color: #fff; border-color: #3b82f6; }}
  </style>
</head>
<body>
  <h1>Claude 自律度ダッシュボード</h1>

  {date_form}

  <div class="card summary">
    <strong>総 permission UI 回数:</strong> {total}<br>
    <strong>PR 件数:</strong> {pr_count}<br>
    <strong>未マッチ（PR URL なし）:</strong> {unmatched}
  </div>

  <div class="card definition">
    <strong>mid-session msgs</strong><br>
    セッション内で初回プロンプト以外にユーザーが送信したメッセージ数。コマンド出力・tool_result は除外。<br>
    <span class="definition-sub">Claude の動作を見て方向転換を要求した回数の代理指標。</span><br><br>
    <strong>perm UI 発生率</strong><br>
    permission UI 回数 ÷ tool_use 総数（%）。<br>
    <span class="definition-sub">作業量に依存しない正規化済み指標。低いほど permission を求めすぎていない。</span><br><br>
    <strong>AskUserQuestion</strong><br>
    Claude がユーザーに問い合わせた回数。<br>
    <span class="definition-sub">仕様の曖昧さや判断をユーザーに委ねた頻度の代理指標。</span><br><br>
    <strong>セッション数</strong><br>
    同一 PR に対して起動した Claude セッションの数。<br>
    <span class="definition-sub">一度で完了せず Claude を起動し直した回数。工数感覚と直結する。</span>
  </div>

  <h2>perm UI 発生率 時系列トレンド</h2>
  <div class="card">
    <div style="display:flex; gap:8px; margin-bottom:12px">
      <button class="tab-btn active" id="btn-day" onclick="showTrend('day')">日別</button>
      <button class="tab-btn" id="btn-week" onclick="showTrend('week')">週別</button>
    </div>
    <div id="trend-day">{day_chart}</div>
    <div id="trend-week" style="display:none">{week_chart}</div>
  </div>

  <h2>メトリクス別グラフ（PR 別、perm UI 発生率 昇順）</h2>
  <div class="chart-grid">
    <div class="chart-card">
      <p class="chart-title">perm UI 発生率（%）— 低いほど自律的</p>
      {chart_perm_rate}
    </div>
    <div class="chart-card">
      <p class="chart-title">permission UI 回数</p>
      {chart_perm_count}
    </div>
    <div class="chart-card">
      <p class="chart-title">セッション数</p>
      {chart_sessions}
    </div>
    <div class="chart-card">
      <p class="chart-title">mid-session msgs</p>
      {chart_mid}
    </div>
    <div class="chart-card" style="grid-column: 1 / -1">
      <p class="chart-title">AskUserQuestion</p>
      {chart_ask}
    </div>
  </div>

  <h2>ツール別 permission UI 内訳</h2>
  <div class="card" style="overflow-x: auto">
    {chart_by_tool}
    {table_by_tool}
  </div>

  <h2>PR 別統計（一覧）</h2>
  <div class="card">
    {pr_table}
  </div>
  <script>
    function showTrend(mode) {{
      document.getElementById('trend-day').style.display = mode === 'day' ? '' : 'none';
      document.getElementById('trend-week').style.display = mode === 'week' ? '' : 'none';
      document.getElementById('btn-day').className = 'tab-btn' + (mode === 'day' ? ' active' : '');
      document.getElementById('btn-week').className = 'tab-btn' + (mode === 'week' ? ' active' : '');
    }}
  </script>
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
