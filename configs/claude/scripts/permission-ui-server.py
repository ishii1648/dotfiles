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


def load_transcript_stats(transcript_path):
    """transcript JSONL を一回のパスで全指標を収集する。

    Returns:
      {
        "tool_use_total": int,     # tool_use アイテムの合計数（perm_rate 分母）
        "mid_session_msgs": int,   # 初回プロンプト以降の人間が打ったメッセージ数
        "ask_user_question": int,  # AskUserQuestion tool_use 回数
      }
    """
    tool_use_total = 0
    mid_session_msgs = 0
    ask_user_question = 0
    first_user_seen = False

    if not transcript_path or not os.path.exists(transcript_path):
        return {
            "tool_use_total": tool_use_total,
            "mid_session_msgs": mid_session_msgs,
            "ask_user_question": ask_user_question,
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
                    for item in content:
                        if not isinstance(item, dict):
                            continue
                        if item.get("type") == "tool_use":
                            tool_use_total += 1
                            if item.get("name") == "ask-user-question":
                                ask_user_question += 1

            except (json.JSONDecodeError, ValueError, KeyError):
                pass

    return {
        "tool_use_total": tool_use_total,
        "mid_session_msgs": mid_session_msgs,
        "ask_user_question": ask_user_question,
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

    pr_stats = {}
    for pr_url in pr_perm_counts:
        tool_use_total = pr_tool_use_total.get(pr_url, 0)
        perm_count = pr_perm_counts[pr_url]
        pr_stats[pr_url] = {
            "perm_count": perm_count,
            "tool_use_total": tool_use_total,
            "perm_rate": round(perm_count / tool_use_total * 100, 1) if tool_use_total else None,
            "mid_session_msgs": pr_mid_session.get(pr_url, 0),
            "ask_user_question": pr_ask_user.get(pr_url, 0),
            "session_count": pr_session_count.get(pr_url, 0),
        }
    return pr_stats, unmatched, total


# ── 描画 ───────────────────────────────────────────────────────────────────────

def shorten_pr_url(url):
    m = re.match(r"https://github\.com/([^/]+)/([^/]+)/pull/(\d+)", url)
    return f"{m.group(1)}/{m.group(2)}#{m.group(3)}" if m else url


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

  <h2>PR 別統計</h2>
  <div class="card">
    {pr_table}
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
