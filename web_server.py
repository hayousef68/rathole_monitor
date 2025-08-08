#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# وب‌سرور ساده با API برای وضعیت/ریستارت تانل‌ها

import os
import json
import time
import subprocess
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

MONITOR_DIR = "/root/rathole-monitor"
CONFIG_FILE = os.path.join(MONITOR_DIR, "config.json")
START_TIME_FILE = os.path.join(MONITOR_DIR, "start_time")

def run_cmd(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)

def is_active(service_name: str) -> bool:
    r = run_cmd(["systemctl", "is-active", service_name])
    return r.stdout.strip() == "active"

def list_rathole_units():
    r = run_cmd(["systemctl", "list-units", "--type=service", "--all", "--no-legend", "--plain"])
    units = []
    for line in r.stdout.splitlines():
        parts = line.split()
        if not parts:
            continue
        unit = parts[0]
        if unit.endswith(".service") and "rathole" in unit:
            units.append(unit[:-8])
    return sorted(set(units))

def load_config():
    try:
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def save_config(cfg):
    try:
        with open(CONFIG_FILE, "w", encoding="utf-8") as f:
            json.dump(cfg, f, ensure_ascii=False, indent=2)
        return True
    except Exception:
        return False

def uptime_str():
    try:
        with open(START_TIME_FILE, "r", encoding="utf-8") as f:
            st = f.read().strip()
        start = None
        try:
            # Python 3.11+ isoformat tolerant
            from datetime import datetime
            start = datetime.fromisoformat(st)
            delta = datetime.now() - start
            return str(delta).split(".")[0]
        except Exception:
            return "نامشخص"
    except Exception:
        return "نامشخص"

def filter_service_name(name: str) -> bool:
    # امنیت ساده: فقط سرویس‌هایی که شامل rathole هستند و دارای کاراکترهای مجاز.
    import re
    return ("rathole" in name.lower()) and bool(re.fullmatch(r"[A-Za-z0-9_.@:-]+", name))

class Handler(BaseHTTPRequestHandler):
    server_version = "RatholeMonitorWeb/1.2"

    def _json(self, code=200, payload=None):
        data = json.dumps(payload or {}, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _text(self, code=200, text=""):
        data = text.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/":
            # سرو HTML
            try:
                with open(os.path.join(MONITOR_DIR, "web_panel.html"), "r", encoding="utf-8") as f:
                    html = f.read().encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(html)))
                self.end_headers()
                self.wfile.write(html)
            except Exception as e:
                self._text(500, f"خطا در سرو HTML: {e}")
            return

        if path == "/api/status":
            cfg = load_config()
            tunnels = cfg.get("tunnels", [])
            # اگر مانیتور هنوز tunnels را نریخته بود، از systemd کشف کن
            if not tunnels:
                for name in list_rathole_units():
                    tunnels.append({
                        "name": name,
                        "type": "iran" if "iran" in name.lower() else "kharej",
                        "status": "unknown",
                        "restart_count": 0
                    })
            # رفرش وضعیت active از systemd
            for t in tunnels:
                try:
                    t["status"] = "active" if is_active(t["name"]) else "inactive"
                except Exception:
                    t["status"] = t.get("status", "unknown")

            # وضعیت سرویس مانیتور
            monitoring_active = is_active("rathole-monitor")

            # خواندن پورت وب از config
            web_port = cfg.get("web_port", 8080)

            self._json(200, {
                "ok": True,
                "monitoring_active": monitoring_active,
                "uptime": uptime_str(),
                "web_port": web_port,
                "tunnels": tunnels,
                "config": {
                    "check_interval": cfg.get("check_interval"),
                    "auto_restart": cfg.get("auto_restart"),
                    "max_restart_attempts": cfg.get("max_restart_attempts"),
                    "restart_delay": cfg.get("restart_delay"),
                    "restart_window_seconds": cfg.get("restart_window_seconds"),
                    "restart_on_inactive": cfg.get("restart_on_inactive"),
                    "journal_since_seconds": cfg.get("journal_since_seconds"),
                    "log_level": cfg.get("log_level"),
                }
            })
            return

        if path == "/api/logs":
            qs = parse_qs(parsed.query)
            name = (qs.get("name") or [""])[0]
            n = int((qs.get("n") or ["50"])[0])
            if not filter_service_name(name):
                self._json(400, {"ok": False, "error": "نام سرویس نامعتبر"})
                return
            try:
                r = run_cmd(["journalctl", "-u", name, "-n", str(n), "--no-pager"])
                self._json(200, {"ok": True, "logs": r.stdout})
            except Exception as e:
                self._json(500, {"ok": False, "error": str(e)})
            return

        self._text(404, "Not found")

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path

        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length) if length > 0 else b"{}"
        try:
            body = json.loads(raw.decode("utf-8") or "{}")
        except Exception:
            body = {}

        if path == "/api/restart":
            name = body.get("name", "")
            if not filter_service_name(name):
                self._json(400, {"ok": False, "error": "نام سرویس نامعتبر"})
                return
            try:
                # reset-failed برای امنیت بیشتر
                run_cmd(["systemctl", "reset-failed", name])
                run_cmd(["systemctl", "restart", name])
                time.sleep(1)
                self._json(200, {"ok": True, "active": is_active(name)})
            except Exception as e:
                self._json(500, {"ok": False, "error": str(e)})
            return

        if path == "/api/monitor/start":
            run_cmd(["systemctl", "start", "rathole-monitor"])
            time.sleep(1)
            self._json(200, {"ok": True, "active": is_active("rathole-monitor")})
            return

        if path == "/api/monitor/stop":
            run_cmd(["systemctl", "stop", "rathole-monitor"])
            time.sleep(1)
            self._json(200, {"ok": True, "active": is_active("rathole-monitor")})
            return

        if path == "/api/config/update":
            # فقط اجازه تغییر web_port (بقیه را ترجیحاً از خود مانیتور UI/فایل)
            new_port = body.get("web_port")
            if isinstance(new_port, int) and 1 <= new_port <= 65535:
                cfg = load_config()
                cfg["web_port"] = new_port
                ok = save_config(cfg)
                self._json(200, {"ok": ok, "web_port": cfg.get("web_port")})
            else:
                self._json(400, {"ok": False, "error": "web_port نامعتبر"})
            return

        self._text(404, "Not found")


def main():
    os.chdir(MONITOR_DIR)
    cfg = load_config()
    port = int(cfg.get("web_port", 8080))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"🌐 Web server running on http://0.0.0.0:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()
