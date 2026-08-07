#!/usr/bin/env python3
"""herdr agent の blocked（permission / 入力待ち）遷移を macOS 通知で知らせる watcher（ADR-090）。

`herdr agent list` をポーリングし、agent_status が blocked に遷移したペインについて
terminal-notifier でクリックアクション付き通知を出す。クリックすると
`herdr agent focus <pane_id>` + Ghostty の前面化で発生元ペインへジャンプする。

launchd（com.user.herdr-agent-notify.plist）で常駐する前提。ログは stdout に出し、
plist 側で ~/.local/state/herdr/agent-notify.log へリダイレクトする。
"""

import json
import os
import shutil
import subprocess
import sys
import time

POLL_SEC = 2
# herdr サーバ停止中・terminal-notifier 未導入時の再試行間隔
ERROR_POLL_SEC = 30
# blocked が連続 N 回観測されたときだけ通知する。画面ルール検知のフラつきと、
# 注視中に即応答したケースの空振り通知を除外する（遅延は最大 POLL_SEC * N 秒）
CONFIRM_POLLS = 2

HOME = os.path.expanduser("~")
# テスト時に fake バイナリへ差し替えられるよう env で上書き可能にする
HERDR = os.environ.get("HERDR_BIN") or os.path.join(HOME, ".local", "bin", "herdr")
GHOSTTY_BUNDLE_ID = "com.mitchellh.ghostty"

AGENT_LABEL = {"claude": "Claude", "codex": "Codex"}


def log(msg):
    print(f"[{time.strftime('%Y-%m-%dT%H:%M:%S')}] {msg}", flush=True)


def find_notifier():
    # launchd 環境では PATH が細いことがあるため nix profile を明示的に補う
    path = shutil.which("terminal-notifier")
    if path:
        return path
    candidate = os.path.join(HOME, ".nix-profile", "bin", "terminal-notifier")
    return candidate if os.access(candidate, os.X_OK) else None


def list_agents():
    out = subprocess.run(
        [HERDR, "agent", "list"],
        capture_output=True, text=True, timeout=10, check=True,
    ).stdout
    return json.loads(out)["result"]["agents"]


def frontmost_is_ghostty():
    """frontmost アプリが Ghostty か（lsappinfo は TCC 権限不要）"""
    try:
        asn = subprocess.run(
            ["/usr/bin/lsappinfo", "front"],
            capture_output=True, text=True, timeout=5, check=True,
        ).stdout.strip()
        info = subprocess.run(
            ["/usr/bin/lsappinfo", "info", "-only", "bundleid", asn],
            capture_output=True, text=True, timeout=5, check=True,
        ).stdout
        return GHOSTTY_BUNDLE_ID in info
    except Exception:
        # 判定に失敗したら「注視していない」扱いで通知を出す（取りこぼしより過剰通知を選ぶ）
        return False


def notify(notifier, agent):
    pane_id = agent["pane_id"]
    label = AGENT_LABEL.get(agent.get("agent", ""), agent.get("agent", "agent"))
    repo = os.path.basename(agent.get("cwd", "") or "") or "?"
    title = agent.get("terminal_title_stripped", "") or ""
    on_click = f"{HERDR} agent focus '{pane_id}'; /usr/bin/open -b {GHOSTTY_BUNDLE_ID}"
    subprocess.run(
        [
            notifier,
            "-title", f"{label} 承認待ち",
            "-subtitle", repo,
            "-message", title or pane_id,
            "-group", f"herdr-agent-notify-{pane_id}",
            "-execute", on_click,
        ],
        capture_output=True, timeout=10,
    )
    log(f"notified: {label} pane={pane_id} repo={repo} title={title!r}")


def main():
    log("watcher started")
    # pane_id -> {"blocked_polls": int, "notified": bool}
    states = {}
    notifier_missing_logged = False
    server_down_logged = False

    while True:
        notifier = find_notifier()
        if notifier is None:
            if not notifier_missing_logged:
                log("terminal-notifier not found (nix home-manager で導入されるまで待機)")
                notifier_missing_logged = True
            time.sleep(ERROR_POLL_SEC)
            continue
        notifier_missing_logged = False

        try:
            agents = list_agents()
        except Exception as e:
            if not server_down_logged:
                log(f"herdr agent list failed (server down?): {e}")
                server_down_logged = True
            states.clear()
            time.sleep(ERROR_POLL_SEC)
            continue
        if server_down_logged:
            log("herdr server reachable again")
            server_down_logged = False

        seen = set()
        for agent in agents:
            pane_id = agent.get("pane_id")
            if not pane_id:
                continue
            seen.add(pane_id)
            state = states.setdefault(pane_id, {"blocked_polls": 0, "notified": False})
            if agent.get("agent_status") == "blocked":
                state["blocked_polls"] += 1
                if state["blocked_polls"] >= CONFIRM_POLLS and not state["notified"]:
                    # 遷移として消費する。注視中スキップの場合も再通知はしない
                    # （blocked のまま放置 → 後で気づきたいケースはサイドバーで拾う）
                    state["notified"] = True
                    if agent.get("focused") and frontmost_is_ghostty():
                        log(f"suppressed (watching): pane={pane_id}")
                    else:
                        notify(notifier, agent)
            else:
                state["blocked_polls"] = 0
                state["notified"] = False
        # 消えたペインの状態を掃除する
        for pane_id in list(states):
            if pane_id not in seen:
                del states[pane_id]

        time.sleep(POLL_SEC)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
