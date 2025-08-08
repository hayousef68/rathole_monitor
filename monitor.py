#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Rathole Tunnel Monitor System
نظارت خودکار و ریستارت تانل‌های Rathole (بدون نیاز به کرون‌جاب)
"""

import os
import sys
import json
import time
import socket
import logging
import subprocess
import threading
from datetime import datetime, timedelta
from typing import List, Dict, Optional

# مسیرها و فایل‌ها
MONITOR_DIR = "/root/rathole-monitor"
CONFIG_FILE = f"{MONITOR_DIR}/config.json"
LOG_FILE = f"{MONITOR_DIR}/monitor.log"

# مقادیر پیش‌فرض
DEFAULT_CHECK_INTERVAL = 300           # ثانیه
DEFAULT_WEB_PORT = 8080
DEFAULT_RESTART_DELAY = 10             # ثانیه
DEFAULT_MAX_RESTART_ATTEMPTS = 3
DEFAULT_RESTART_WINDOW_SECONDS = 900   # پنجره محدودسازی ریستارت (۱۵ دقیقه)
DEFAULT_LOG_LEVEL = "INFO"
DEFAULT_RESTART_ON_INACTIVE = True     # اگر سرویس inactive/failed بود، تلاش برای فعال‌سازی

# List of error patterns that should be ignored (not critical)
IGNORED_ERRORS=(
    "Connection refused"
    "Connection reset by peer"
    "Broken pipe"
    "Connection timeout"
    "Temporary failure in name resolution"
    "No route to host"
    "Connection timed out"
    "Network is unreachable"
    "Connection closed"
    "Connection lost"
    "Failed to establish connection"
    "Client.* disconnected"
    "Handshake failed"
    "Read timeout"
    "Write timeout"
    "Stream closed"
    "Connection dropped"
    "Connection aborted"
    "SSL handshake failed"
    "TLS handshake failed"
    "Retry limit exceeded"
    "Connection reset"
    "Invalid response"
    "Protocol error"
    "Connection refused by server"
    "Connection terminated"
    "Connection interrupted"
    "Authentication failed"
    "Websocket connection failed"
    "Failed to read from socket"
    "Failed to write to socket"
    "EOF while reading"
    "Unexpected EOF"
    "Connection rejected"
    "Remote connection closed"
    "Host unreachable"
    "Connection pooling failed"
    "Keepalive failed"
    "Peer closed connection"
    "Socket closed"
    "Connection was closed"
    "Connection has been closed"
    "Connection lost to server"
    "Connection was reset"
    "Connection was terminated"
    "Connection was dropped"
    "connection failed"
    "failed to connect"
    "Connection refused by remote host"
    "Connection reset by remote host"
    "Network connection failed"
    "Connection broken"
    "Connection unstable"
    "Connection error"
    "Connection exception"
    "Connection closed by remote"
    "Connection ended"
    "Connection closed unexpectedly"
    "Connection was interrupted"
    "Connection was aborted"
    "Connection was terminated by remote"
    "Connection closed by peer"
    "Connection closed by server"
    "Connection was closed by remote"
    "Connection was reset by remote"
    "Connection was terminated unexpectedly"
    "Connection has been reset"
    "Connection was broken"
    "Connection was lost"
    "Connection was dropped by remote"
    "Connection was forcefully closed"
    "Connection closed due to timeout"
    "Connection was closed due to inactivity"
    "Connection was closed due to error"
    "Connection was closed abnormally"
    "Connection was closed gracefully"
    "Connection was ended by remote"
    "Connection was ended by client"
    "Connection was ended by server"
    "Connection was ended due to timeout"
    "Connection was ended abnormally"
    "Connection was ended gracefully"
    "Network error"
    "Network timeout"
    "Network connection lost"
    "Network connection failed"
    "Network connection closed"
    "Network connection terminated"
    "Network connection reset"
    "Network connection aborted"
    "Network connection broken"
    "Network connection unstable"
    "Network connection error"
    "Network connection exception"
    "Network connection timeout"
    "Network connection refused"
    "Network connection dropped"
    "Network connection interrupted"
    "Network connection reset by peer"
    "Network connection closed by peer"
    "Network connection closed by remote"
    "Network connection closed by server"
    "Network connection closed by client"
    "Network connection closed due to timeout"
    "Network connection closed due to inactivity"
    "Network connection closed due to error"
    "Network connection closed abnormally"
    "Network connection closed gracefully"
    "Network connection ended by remote"
    "Network connection ended by client"
    "Network connection ended by server"
    "Network connection ended due to timeout"
    "Network connection ended abnormally"
    "Network connection ended gracefully"
    "Unable to connect"
    "Failed to connect"
    "Connection attempt failed"
    "Connection attempt timed out"
    "Connection attempt rejected"
    "Connection attempt refused"
    "Connection attempt aborted"
    "Connection attempt reset"
    "Connection attempt dropped"
    "Connection attempt interrupted"
    "Connection attempt terminated"
    "Connection attempt failed due to timeout"
    "Connection attempt failed due to error"
    "Connection attempt failed due to refusal"
    "Connection attempt failed due to unreachable"
    "Connection attempt failed due to reset"
    "Connection attempt failed due to abort"
    "Connection attempt failed due to drop"
    "Connection attempt failed due to interrupt"
    "Connection attempt failed due to termination"
    "Connection attempt failed due to closure"
    "Connection attempt failed due to broken pipe"
    "Connection attempt failed due to network error"
    "Connection attempt failed due to network timeout"
    "Connection attempt failed due to network issue"
    "Connection attempt failed due to network unreachable"
    "Connection attempt failed due to network down"
    "Connection attempt failed due to network congestion"
    "Connection attempt failed due to network overload"
    "Connection attempt failed due to network instability"
    "Connection attempt failed due to network maintenance"
    "Connection attempt failed due to network configuration"
    "Connection attempt failed due to network security"
    "Connection attempt failed due to network policy"
    "Connection attempt failed due to network restriction"
    "Connection attempt failed due to network limitation"
    "Connection attempt failed due to network throttling"
    "Connection attempt failed due to network blocking"
    "Connection attempt failed 1 time"
    "Connection attempt failed 2 times"
    "Connection attempt failed 3 times"
    "Connection attempt failed 4 times"
    "Connection attempt failed 5 times"
    "Connection attempt failed 6 times"
    "Connection attempt failed 7 times"
    "Connection attempt failed 8 times"
    "Connection attempt failed 9 times"
    "Connection attempt failed 10 times"
)

# List of critical error patterns that require restart
CRITICAL_ERRORS=(
    "panic"
    "fatal"
    "segmentation fault"
    "core dumped"
    "invalid memory"
    "out of memory"
    "memory leak"
    "stack overflow"
    "buffer overflow"
    "null pointer"
    "access violation"
    "illegal instruction"
    "abort"
    "crashed"
    "failed to start"
    "process exited"
    "service stopped"
    "service failed"
    "bind failed"
    "failed to bind"
    "address already in use"
    "permission denied"
    "file not found"
    "configuration error"
    "config error"
    "invalid config"
    "failed to load config"
    "failed to parse config"
    "failed to read config"
    "failed to open"
    "failed to create"
    "failed to write"
    "failed to read"
    "failed to close"
    "failed to flush"
    "failed to seek"
    "failed to stat"
    "failed to sync"
    "failed to lock"
    "failed to unlock"
    "failed to allocate"
    "failed to free"
    "failed to initialize"
    "failed to cleanup"
    "failed to finalize"
    "failed to destroy"
    "failed to create thread"
    "failed to join thread"
    "failed to spawn thread"
    "failed to send"
    "failed to receive"
    "failed to process"
    "failed to execute"
    "failed to run"
    "failed to start process"
    "failed to stop process"
    "failed to kill process"
    "failed to restart process"
    "failed to reload"
    "failed to update"
    "failed to upgrade"
    "failed to downgrade"
    "failed to install"
    "failed to uninstall"
    "failed to configure"
    "failed to setup"
    "failed to init"
    "failed to boot"
    "failed to shutdown"
    "failed to reboot"
    "failed to mount"
    "failed to unmount"
    "failed to format"
    "failed to backup"
    "failed to restore"
    "failed to recover"
    "failed to repair"
    "failed to validate"
    "failed to verify"
    "failed to authenticate"
    "failed to authorize"
    "failed to login"
    "failed to logout"
    "failed to register"
    "failed to unregister"
    "failed to enable"
    "failed to disable"
    "failed to activate"
    "failed to deactivate"
    "failed to suspend"
    "failed to resume"
    "failed to pause"
    "failed to continue"
    "failed to stop"
    "failed to start"
    "failed to restart"
    "failed to reload"
    "failed to reset"
    "failed to clear"
    "failed to flush"
    "failed to sync"
    "failed to commit"
    "failed to rollback"
    "failed to save"
    "failed to load"
    "failed to import"
    "failed to export"
    "failed to copy"
    "failed to move"
    "failed to delete"
    "failed to remove"
    "failed to rename"
    "failed to create directory"
    "failed to create file"
    "failed to delete directory"
    "failed to delete file"
    "failed to read directory"
    "failed to read file"
    "failed to write directory"
    "failed to write file"
    "failed to access directory"
    "failed to access file"
    "failed to find directory"
    "failed to find file"
    "failed to open directory"
    "failed to open file"
    "failed to close directory"
    "failed to close file"
    "failed to lock directory"
    "failed to lock file"
    "failed to unlock directory"
    "failed to unlock file"
    "failed to chmod"
    "failed to chown"
    "failed to chgrp"
    "failed to link"
    "failed to symlink"
    "failed to unlink"
    "failed to stat"
    "failed to lstat"
    "failed to fstat"
    "failed to truncate"
    "failed to expand"
    "failed to compress"
    "failed to decompress"
    "failed to archive"
    "failed to unarchive"
    "failed to encrypt"
    "failed to decrypt"
    "failed to hash"
    "failed to checksum"
    "failed to generate"
    "failed to compute"
    "failed to calculate"
    "failed to measure"
    "failed to test"
    "failed to check"
    "failed to validate"
    "failed to verify"
    "failed to confirm"
    "failed to ensure"
    "failed to assert"
    "failed to evaluate"
    "failed to analyze"
    "failed to diagnose"
    "failed to debug"
    "failed to trace"
    "failed to profile"
    "failed to monitor"
    "failed to watch"
    "failed to observe"
    "failed to track"
    "failed to follow"
    "failed to inspect"
    "failed to examine"
    "failed to investigate"
    "failed to explore"
    "failed to discover"
    "failed to search"
    "failed to find"
    "failed to locate"
    "failed to retrieve"
    "failed to fetch"
    "failed to get"
    "failed to obtain"
    "failed to acquire"
    "failed to collect"
    "failed to gather"
    "failed to compile"
    "failed to build"
    "failed to make"
    "failed to create"
    "failed to generate"
    "failed to produce"
    "failed to construct"
    "failed to assemble"
    "failed to link"
    "failed to package"
    "failed to deploy"
    "failed to release"
    "failed to publish"
    "failed to distribute"
    "failed to install"
    "failed to uninstall"
    "failed to setup"
    "failed to configure"
    "failed to customize"
    "failed to adapt"
    "failed to adjust"
    "failed to modify"
    "failed to change"
    "failed to update"
    "failed to upgrade"
    "failed to downgrade"
    "failed to migrate"
    "failed to convert"
    "failed to transform"
    "failed to format"
    "failed to parse"
    "failed to serialize"
    "failed to deserialize"
    "failed to encode"
    "failed to decode"
    "failed to compress"
    "failed to decompress"
    "failed to zip"
    "failed to unzip"
    "failed to tar"
    "failed to untar"
    "failed to gzip"
    "failed to gunzip"
    "failed to encrypt"
    "failed to decrypt"
    "failed to sign"
    "failed to verify signature"
    "failed to hash"
    "failed to checksum"
    "failed to validate checksum"
    "failed to compare"
    "failed to match"
    "failed to filter"
    "failed to sort"
    "failed to group"
    "failed to aggregate"
    "failed to summarize"
    "failed to reduce"
    "failed to map"
    "failed to transform"
    "failed to apply"
    "failed to execute"
    "failed to run"
    "failed to call"
    "failed to invoke"
    "failed to trigger"
    "failed to fire"
    "failed to emit"
    "failed to broadcast"
    "failed to publish"
    "failed to subscribe"
    "failed to unsubscribe"
    "failed to notify"
    "failed to alert"
    "failed to warn"
    "failed to report"
    "failed to log"
    "failed to record"
    "failed to store"
    "failed to persist"
    "failed to commit"
    "failed to save"
    "failed to backup"
    "failed to restore"
    "failed to recover"
    "failed to repair"
    "failed to fix"
    "failed to resolve"
    "failed to solve"
    "failed to handle"
    "failed to process"
    "failed to manage"
    "failed to control"
    "failed to operate"
    "failed to function"
    "failed to work"
    "failed to perform"
    "failed to execute"
    "failed to complete"
    "failed to finish"
    "failed to done"
    "failed to succeed"
    "failed to fail"
    "failed to error"
    "failed to crash"
    "failed to exit"
    "failed to terminate"
    "failed to quit"
    "failed to stop"
    "failed to end"
    "failed to close"
    "failed to shutdown"
    "failed to restart"
    "failed to reboot"
    "failed to reset"
    "failed to clear"
    "failed to flush"
    "failed to sync"
    "failed to wait"
    "failed to sleep"
    "failed to pause"
    "failed to resume"
    "failed to continue"
    "failed to yield"
    "failed to return"
    "failed to respond"
    "failed to reply"
    "failed to answer"
    "failed to acknowledge"
    "failed to confirm"
    "failed to accept"
    "failed to reject"
    "failed to deny"
    "failed to allow"
    "failed to permit"
    "failed to grant"
    "failed to revoke"
    "failed to authorize"
    "failed to authenticate"
    "failed to login"
    "failed to logout"
    "failed to register"
    "failed to unregister"
    "failed to subscribe"
    "failed to unsubscribe"
    "failed to connect"
    "failed to disconnect"
    "failed to bind"
    "failed to unbind"
    "failed to attach"
    "failed to detach"
    "failed to associate"
    "failed to disassociate"
    "failed to link"
    "failed to unlink"
    "failed to couple"
    "failed to decouple"
    "failed to join"
    "failed to leave"
    "failed to enter"
    "failed to exit"
    "failed to open"
    "failed to close"
    "failed to lock"
    "failed to unlock"
    "failed to acquire"
    "failed to release"
    "failed to allocate"
    "failed to free"
    "failed to reserve"
    "failed to unreserve"
    "failed to claim"
    "failed to unclaim"
    "failed to take"
    "failed to give"
    "failed to get"
    "failed to set"
    "failed to put"
    "failed to push"
    "failed to pop"
    "failed to peek"
    "failed to insert"
    "failed to remove"
    "failed to delete"
    "failed to add"
    "failed to append"
    "failed to prepend"
    "failed to concat"
    "failed to merge"
    "failed to split"
    "failed to slice"
    "failed to cut"
    "failed to copy"
    "failed to move"
    "failed to swap"
    "failed to replace"
    "failed to substitute"
    "failed to change"
    "failed to modify"
    "failed to update"
    "failed to upgrade"
    "failed to downgrade"
    "failed to migrate"
    "failed to convert"
    "failed to transform"
    "failed to format"
    "failed to parse"
    "failed to serialize"
    "failed to deserialize"
    "config validation failed"
    "invalid configuration"
    "configuration syntax error"
    "missing configuration"
    "configuration file not found"
    "configuration parse error"
    "configuration load error"
    "configuration read error"
    "configuration write error"
    "configuration save error"
    "configuration backup error"
    "configuration restore error"
    "configuration validation error"
    "configuration check error"
    "configuration test error"
    "configuration apply error"
    "configuration update error"
    "configuration upgrade error"
    "configuration downgrade error"
    "configuration migration error"
    "configuration conversion error"
    "configuration transformation error"
    "configuration format error"
    "configuration parse error"
    "configuration serialization error"
    "configuration deserialization error"
    "configuration encoding error"
    "configuration decoding error"
    "configuration compression error"
    "configuration decompression error"
    "configuration encryption error"
    "configuration decryption error"
    "configuration signing error"
    "configuration verification error"
    "configuration hash error"
    "configuration checksum error"
    "configuration validation error"
    "configuration comparison error"
    "configuration match error"
    "configuration filter error"
    "configuration sort error"
    "configuration group error"
    "configuration aggregate error"
    "configuration summarize error"
    "configuration reduce error"
    "configuration map error"
    "configuration transform error"
    "configuration apply error"
    "configuration execute error"
    "configuration run error"
    "configuration call error"
    "configuration invoke error"
    "configuration trigger error"
    "configuration fire error"
    "configuration emit error"
    "configuration broadcast error"
    "configuration publish error"
    "configuration subscribe error"
    "configuration unsubscribe error"
    "configuration notify error"
    "configuration alert error"
    "configuration warn error"
    "configuration report error"
    "configuration log error"
    "configuration record error"
    "configuration store error"
    "configuration persist error"
    "configuration commit error"
    "configuration save error"
    "configuration backup error"
    "configuration restore error"
    "configuration recover error"
    "configuration repair error"
    "configuration fix error"
    "configuration resolve error"
    "configuration solve error"
    "configuration handle error"
    "configuration process error"
    "configuration manage error"
    "configuration control error"
    "configuration operate error"
    "configuration function error"
    "configuration work error"
    "configuration perform error"
    "configuration execute error"
    "configuration complete error"
    "configuration finish error"
    "configuration done error"
    "configuration success error"
    "configuration fail error"
    "configuration error error"
    "configuration crash error"
    "configuration exit error"
    "configuration terminate error"
    "configuration quit error"
    "configuration stop error"
    "configuration end error"
    "configuration close error"
    "configuration shutdown error"
    "configuration restart error"
    "configuration reboot error"
    "configuration reset error"
    "configuration clear error"
    "configuration flush error"
    "configuration sync error"
    "configuration wait error"
    "configuration sleep error"
    "configuration pause error"
    "configuration resume error"
    "configuration continue error"
    "configuration yield error"
    "configuration return error"
    "configuration respond error"
    "configuration reply error"
    "configuration answer error"
    "configuration acknowledge error"
    "configuration confirm error"
    "configuration accept error"
    "configuration reject error"
    "configuration deny error"
    "configuration allow error"
    "configuration permit error"
    "configuration grant error"
    "configuration revoke error"
    "configuration authorize error"
    "configuration authenticate error"
    "configuration login error"
    "configuration logout error"
    "configuration register error"
    "configuration unregister error"
    "configuration subscribe error"
    "configuration unsubscribe error"
    "configuration connect error"
    "configuration disconnect error"
    "configuration bind error"
    "configuration unbind error"
    "configuration attach error"
    "configuration detach error"
    "configuration associate error"
    "configuration disassociate error"
    "configuration link error"
    "configuration unlink error"
    "configuration couple error"
    "configuration decouple error"
    "configuration join error"
    "configuration leave error"
    "configuration enter error"
    "configuration exit error"
    "configuration open error"
    "configuration close error"
    "configuration lock error"
    "configuration unlock error"
    "configuration acquire error"
    "configuration release error"
    "configuration allocate error"
    "configuration free error"
    "configuration reserve error"
    "configuration unreserve error"
    "configuration claim error"
    "configuration unclaim error"
    "configuration take error"
    "configuration give error"
    "configuration get error"
    "configuration set error"
    "configuration put error"
    "configuration push error"
    "configuration pop error"
    "configuration peek error"
    "configuration insert error"
    "configuration remove error"
    "configuration delete error"
    "configuration add error"
    "configuration append error"
    "configuration prepend error"
    "configuration concat error"
    "configuration merge error"
    "configuration split error"
    "configuration slice error"
    "configuration cut error"
    "configuration copy error"
    "configuration move error"
    "configuration swap error"
    "configuration replace error"
    "configuration substitute error"
    "configuration change error"
    "configuration modify error"
    "configuration update error"
    "PermissionError"
    "FileNotFoundError"
    "IOError"
    "OSError"
    "SystemError"
    "RuntimeError"
    "MemoryError"
    "OverflowError"
    "ZeroDivisionError"
    "ValueError"
    "TypeError"
    "AttributeError"
    "NameError"
    "SyntaxError"
    "ImportError"
    "ModuleNotFoundError"
    "KeyError"
    "IndexError"
    "NotImplementedError"
    "AssertionError"
    "StopIteration"
    "GeneratorExit"
    "KeyboardInterrupt"
    "SystemExit"
    "Exception"
    "Error"
    "Failed"
    "Panic"
    "Fatal"
    "Critical"
    "Emergency"
    "Alert"
    "Severe"
    "Major"
    "High"
    "Urgent"
    "Important"
    "Serious"
    "Bad"
    "Fail"
    "Err"
    "Err:"
    "ERROR"
    "FATAL"
    "CRITICAL"
    "PANIC"
    "EMERGENCY"
    "ALERT"
    "SEVERE"
    "MAJOR"
    "HIGH"
    "URGENT"
    "IMPORTANT"
    "SERIOUS"
    "BAD"
    "FAIL"
    "FAILED"
    "FAILURE"
    "CRASH"
    "CRASHED"
    "ABORT"
    "ABORTED"
    "STOP"
    "STOPPED"
    "KILL"
    "KILLED"
    "TERMINATE"
    "TERMINATED"
    "EXIT"
    "EXITED"
    "QUIT"
    "QUITTED"
    "CLOSE"
    "CLOSED"
    "SHUTDOWN"
    "SHUTDOW"
    "RESTART"
    "RESTARTED"
    "REBOOT"
    "REBOOTED"
    "RESET"
    "RESETED"
    "CLEAR"
    "CLEARED"
    "FLUSH"
    "FLUSHED"
    "SYNC"
    "SYNCED"
)


def run_cmd(cmd: List[str]) -> subprocess.CompletedProcess:
    """اجرای امن دستورات سیستم با لاگ‌گیری ساده."""
    return subprocess.run(cmd, capture_output=True, text=True)


def now_iso() -> str:
    return datetime.now().isoformat(timespec="seconds")


class RatholeMonitor:
    def __init__(self):
        self.running = False
        self._restart_history: Dict[str, List[datetime]] = {}  # تاریخچه ریستارت‌ها برای هر سرویس
        self._next_allowed_restart: Dict[str, datetime] = {}   # زمان مجاز بعدی برای ریستارت (بک‌آف)
        self._lock = threading.Lock()
        self.setup_directories()
        self.setup_logging()
        self.config = self.load_config()
        self.logger.info("Rathole Monitor initialized")

    # ----- Setup -----
    def setup_directories(self):
        os.makedirs(MONITOR_DIR, exist_ok=True)
        os.chmod(MONITOR_DIR, 0o755)

    def setup_logging(self):
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        level = getattr(logging, DEFAULT_LOG_LEVEL.upper(), logging.INFO)
        logging.basicConfig(
            level=level,
            format="%(asctime)s - %(levelname)s - %(message)s",
            handlers=[logging.FileHandler(LOG_FILE, encoding="utf-8"), logging.StreamHandler()],
        )
        self.logger = logging.getLogger("rathole-monitor")

    # ----- Config -----
    def load_config(self) -> Dict:
        defaults = {
            "tunnels": [],
            "check_interval": DEFAULT_CHECK_INTERVAL,
            "web_port": DEFAULT_WEB_PORT,
            "auto_restart": True,
            "max_restart_attempts": DEFAULT_MAX_RESTART_ATTEMPTS,
            "restart_delay": DEFAULT_RESTART_DELAY,
            "restart_window_seconds": DEFAULT_RESTART_WINDOW_SECONDS,
            "log_level": DEFAULT_LOG_LEVEL,
            "restart_on_inactive": DEFAULT_RESTART_ON_INACTIVE,
            "journal_since_seconds": DEFAULT_CHECK_INTERVAL,
        }
        cfg = defaults.copy()
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                    file_cfg = json.load(f)
                    if isinstance(file_cfg, dict):
                        cfg.update(file_cfg)
            except Exception as e:
                # قبل از logger آماده است
                print(f"[WARN] خطا در بارگذاری تنظیمات: {e}", file=sys.stderr)

        # تنظیم سطح لاگ در صورت تغییر در config
        try:
            self.logger.setLevel(getattr(logging, cfg.get("log_level", DEFAULT_LOG_LEVEL).upper(), logging.INFO))
        except Exception:
            pass

        return cfg

    def save_config(self):
        try:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                json.dump(self.config, f, ensure_ascii=False, indent=2)
        except Exception as e:
            self.logger.error(f"خطا در ذخیره تنظیمات: {e}")

    # ----- Discovery -----
    def discover_tunnels(self) -> List[Dict]:
        """کشف سرویس‌هایی که نامشان شامل rathole است (حتی اگر inactive باشند)."""
        tunnels: List[Dict] = []
        try:
            # --all تا سرویس‌های inactive هم دیده شوند
            result = run_cmd(["systemctl", "list-units", "--type=service", "--all", "--no-legend", "--plain"])
            for line in result.stdout.splitlines():
                if not line.strip():
                    continue
                # نمونه سطر: rathole-iran-8080.service loaded active running ...
                parts = line.split()
                unit = parts[0] if parts else ""
                if "rathole" in unit and unit.endswith(".service"):
                    service_name = unit[:-8]  # حذف .service
                    info = self.extract_tunnel_info(service_name)
                    if info:
                        tunnels.append(info)
        except Exception as e:
            self.logger.error(f"خطا در شناسایی تانل‌ها: {e}")
        return tunnels

    def extract_tunnel_info(self, service_name: str) -> Optional[Dict]:
        """دریافت وضعیت سرویس از systemd."""
        try:
            result = run_cmd(["systemctl", "show", service_name, "--property=ActiveState,SubState,ExecStart,FragmentPath"])
            info: Dict[str, str] = {}
            for line in result.stdout.splitlines():
                if "=" in line:
                    k, v = line.split("=", 1)
                    info[k.strip()] = v.strip()

            active_state = info.get("ActiveState", "unknown")
            sub_state = info.get("SubState", "unknown")
            return {
                "name": service_name,
                "type": "iran" if "iran" in service_name.lower() else "kharej",
                "status": active_state,
                "sub_status": sub_state,
                "last_restart": None,
                "restart_count": 0,
                "config_path": self.find_config_path(service_name, info.get("ExecStart", ""), info.get("FragmentPath", "")),
            }
        except Exception as e:
            self.logger.error(f"خطا در استخراج اطلاعات {service_name}: {e}")
            return None

    def find_config_path(self, service_name: str, exec_start: str = "", fragment_path: str = "") -> Optional[str]:
        """تلاش برای یافتن مسیر کانفیگ (ابتدا از ExecStart/FragmentPath سپس مسیرهای رایج)."""
        # تلاش برای استخراج مسیر از ExecStart (اگر شامل .toml بود)
        try:
            for token in exec_start.split():
                if token.endswith(".toml") and os.path.exists(token):
                    return token
        except Exception:
            pass

        common_paths = [
            f"/etc/rathole/{service_name}.toml",
            f"/root/rathole/{service_name}.toml",
            f"/opt/rathole/{service_name}.toml",
        ]
        for p in common_paths:
            if os.path.exists(p):
                return p

        # گاهی فایل سرویس کنار فایل کانفیگ است
        if fragment_path:
            base = os.path.dirname(fragment_path)
            for guess in (f"{base}/{service_name}.toml", f"{base}/rathole.toml"):
                if os.path.exists(guess):
                    return guess
        return None

    # ----- Health checks -----
    def is_active(self, service_name: str) -> bool:
        res = run_cmd(["systemctl", "is-active", service_name])
        return res.stdout.strip() == "active"

    def ensure_active_if_needed(self, tunnel: Dict) -> bool:
        """اگر inactive/failed بود، تلاش برای فعال‌سازی مجدد."""
        if not self.config.get("restart_on_inactive", True):
            return False

        service = tunnel["name"]
        res = run_cmd(["systemctl", "is-active", service])
        state = res.stdout.strip()
        if state in ("inactive", "failed", "deactivating"):
            self.logger.warning(f"سرویس {service} در وضعیت {state} است؛ تلاش برای فعال‌سازی...")
            # ریست وضعیت failed
            run_cmd(["systemctl", "reset-failed", service])
            # ابتدا start، اگر لازم شد restart
            start = run_cmd(["systemctl", "start", service])
            time.sleep(1)
            if not self.is_active(service):
                self.logger.info(f"start کافی نبود؛ restart سرویس {service}")
                run_cmd(["systemctl", "restart", service])

            ok = self.is_active(service)
            if ok:
                tunnel["status"] = "active"
                tunnel["sub_status"] = "running"
                self.logger.info(f"سرویس {service} با موفقیت active شد")
            else:
                self.logger.error(f"سرویس {service} هنوز active نیست")
            return ok
        return False

    def _read_recent_journal(self, service_name: str) -> str:
        since_sec = int(self.config.get("journal_since_seconds", self.config.get("check_interval", DEFAULT_CHECK_INTERVAL)))
        since_arg = f"{since_sec} seconds ago"
        r = run_cmd(["journalctl", "-u", service_name, "--since", since_arg, "--no-pager", "-q"])
        return r.stdout.lower()

    def has_critical_error(self, service_name: str) -> bool:
        """تحلیل لاگ‌های اخیر: الگوهای نادیده + الگوهای بحرانی. (الگوها را خودتان بعداً پر کنید)"""
        try:
            log_text = self._read_recent_journal(service_name)

            # اگر الگوهای نادیده وجود دارد، حذف‌شان کنیم که اثر نگذارند
            for ign in IGNORED_ERROR_PATTERNS:
                if not ign:
                    continue
                log_text = log_text.replace(ign.lower(), "")

            # بررسی الگوهای بحرانی
            for crit in CRITICAL_ERROR_PATTERNS:
                if crit and crit.lower() in log_text:
                    return True

            # اگر لیست بحرانی خالی است، هیچ ارزیابی بحرانی انجام نمی‌دهیم (مطابق خواست شما)
            return False
        except Exception as e:
            self.logger.error(f"خطا در بررسی لاگ {service_name}: {e}")
            return False

    def check_tunnel_health(self, tunnel: Dict) -> bool:
        """سلامت سرویس: active بودن و عدم وجود خطای بحرانی (طبق الگوهای تعریف‌شده توسط شما)."""
        name = tunnel["name"]

        if not self.is_active(name):
            self.logger.warning(f"سرویس {name} active نیست")
            tunnel["status"] = "inactive"
            return False

        # اگر سرویس active است، وضعیت را بروزرسانی می‌کنیم
        tunnel["status"] = "active"

        # تحلیل لاگ‌ها (فعلاً الگوها خالی‌اند مگر خودتان اضافه کنید)
        if self.has_critical_error(name):
            self.logger.warning(f"الگوی خطای بحرانی در لاگ سرویس {name} یافت شد")
            return False

        return True

    # ----- Restart logic -----
    def _can_restart(self, service_name: str) -> bool:
        """بررسی سقف تلاش‌ها در پنجره مشخص و بک‌آف زمانی."""
        max_attempts = int(self.config.get("max_restart_attempts", DEFAULT_MAX_RESTART_ATTEMPTS))
        window_sec = int(self.config.get("restart_window_seconds", DEFAULT_RESTART_WINDOW_SECONDS))

        # بک‌آف
        na = self._next_allowed_restart.get(service_name)
        if na and datetime.now() < na:
            return False

        # پاکسازی تاریخچه قدیمی
        hist = self._restart_history.setdefault(service_name, [])
        cutoff = datetime.now() - timedelta(seconds=window_sec)
        hist[:] = [t for t in hist if t >= cutoff]

        return len(hist) < max_attempts

    def _register_restart(self, service_name: str, success: bool):
        """ثبت ریستارت و افزایش بک‌آف در صورت شکست."""
        hist = self._restart_history.setdefault(service_name, [])
        hist.append(datetime.now())
        if not success:
            # بک‌آف نمایی ساده: 30s, 60s, 120s ...
            prev = self._next_allowed_restart.get(service_name, datetime.now())
            delay = 30 if prev < datetime.now() else int((prev - datetime.now()).total_seconds()) * 2 or 30
            self._next_allowed_restart[service_name] = datetime.now() + timedelta(seconds=min(delay, 600))
        else:
            # موفق بود: بک‌آف را پاک کن
            self._next_allowed_restart.pop(service_name, None)

    def restart_tunnel(self, tunnel: Dict) -> bool:
        name = tunnel["name"]

        if not self._can_restart(name):
            self.logger.error(f"ریستارت {name} به علت عبور از محدودیت یا بک‌آف زمان‌بندی، فعلاً مجاز نیست")
            return False

        self.logger.info(f"ریستارت تانل {name}...")
        delay = int(self.config.get("restart_delay", DEFAULT_RESTART_DELAY))
        ok = False
        try:
            run_cmd(["systemctl", "stop", name])
            time.sleep(delay)
            run_cmd(["systemctl", "start", name])
            ok = self.is_active(name)
            if ok:
                tunnel["status"] = "active"
                tunnel["sub_status"] = "running"
                tunnel["last_restart"] = now_iso()
                tunnel["restart_count"] = tunnel.get("restart_count", 0) + 1
                self.logger.info(f"تانل {name} با موفقیت ریستارت شد")
            else:
                self.logger.error(f"پس از ریستارت، {name} هنوز active نیست")
        except Exception as e:
            self.logger.error(f"خطا در ریستارت {name}: {e}")
            ok = False

        self._register_restart(name, ok)
        return ok

    # ----- Loop -----
    def monitor_once(self):
        # بروزرسانی لیست سرویس‌ها
        tunnels = self.discover_tunnels()
        self.config["tunnels"] = tunnels

        auto_restart = self.config.get("auto_restart", True)

        for tunnel in tunnels:
            name = tunnel["name"]

            # اگر inactive/failed → تلاش برای active کردن
            self.ensure_active_if_needed(tunnel)

            # بررسی سلامت
            healthy = self.check_tunnel_health(tunnel)

            # در صورت ناسالم بودن، اگر مجاز بود ریستارت
            if not healthy and auto_restart:
                self.restart_tunnel(tunnel)

        # ذخیره وضعیت
        self.save_config()

    def monitor_loop(self):
        self.logger.info("شروع مانیتورینگ تانل‌ها...")
        while self.running:
            try:
                with self._lock:
                    self.monitor_once()
                time.sleep(int(self.config.get("check_interval", DEFAULT_CHECK_INTERVAL)))
            except KeyboardInterrupt:
                break
            except Exception as e:
                self.logger.error(f"خطا در حلقه مانیتورینگ: {e}")
                time.sleep(60)
        self.logger.info("مانیتورینگ متوقف شد")

    def start_monitoring(self):
        if not self.running:
            self.running = True
            t = threading.Thread(target=self.monitor_loop, daemon=True)
            t.start()

    def stop_monitoring(self):
        self.running = False

    # ----- UI helpers -----
    def get_uptime(self) -> str:
        try:
            with open(f"{MONITOR_DIR}/start_time", "r", encoding="utf-8") as f:
                st = datetime.fromisoformat(f.read().strip())
            return str((datetime.now() - st)).split(".")[0]
        except Exception:
            return "نامشخص"

    def get_status(self) -> Dict:
        return {
            "running": self.running,
            "tunnels": self.config.get("tunnels", []),
            "config": self.config,
            "uptime": self.get_uptime(),
        }


# ----- Simple CLI menu -----
def show_status(m: RatholeMonitor):
    st = m.get_status()
    print(f"\n📊 وضعیت سیستم:")
    print(f"وضعیت مانیتورینگ: {'فعال' if st['running'] else 'غیرفعال'}")
    print(f"مدت زمان اجرا: {st['uptime']}")
    print(f"تعداد تانل‌ها: {len(st['tunnels'])}")
    print("\n🔗 لیست تانل‌ها:")
    for t in st["tunnels"]:
        print(f"  - {t['name']} ({t.get('type','?')})")
        print(f"    وضعیت: {t.get('status','?')} | زیر-وضعیت: {t.get('sub_status','?')}")
        print(f"    تعداد ریستارت: {t.get('restart_count', 0)}")
        if t.get("last_restart"):
            print(f"    آخرین ریستارت: {t['last_restart']}")


def manual_restart(m: RatholeMonitor):
    ts = m.config.get("tunnels", [])
    if not ts:
        print("هیچ تانلی یافت نشد")
        return
    print("\nانتخاب تانل برای ریستارت:")
    for i, t in enumerate(ts, 1):
        print(f"{i}. {t['name']}")
    choice = input("شماره تانل: ").strip()
    try:
        idx = int(choice) - 1
        if 0 <= idx < len(ts):
            ok = m.restart_tunnel(ts[idx])
            print("تانل با موفقیت ریستارت شد" if ok else "خطا در ریستارت تانل")
        else:
            print("شماره نامعتبر")
    except ValueError:
        print("شماره نامعتبر")


def show_logs():
    try:
        subprocess.run(["tail", "-n", "50", LOG_FILE], check=False)
    except Exception:
        print("خطا در نمایش لاگ‌ها")


def create_service():
    service_content = f"""[Unit]
Description=Rathole Tunnel Monitor
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory={MONITOR_DIR}
ExecStart=/usr/bin/python3 {MONITOR_DIR}/monitor.py --daemon
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"""
    with open("/etc/systemd/system/rathole-monitor.service", "w", encoding="utf-8") as f:
        f.write(service_content)
    subprocess.run(["systemctl", "daemon-reload"])
    subprocess.run(["systemctl", "enable", "rathole-monitor"])


def install_requirements():
    print("نصب پیش‌نیازها...")
    subprocess.run(["apt", "update"])
    for pkg in ["python3", "python3-pip", "systemd"]:
        subprocess.run(["apt", "install", "-y", pkg])
    print("پیش‌نیازها نصب شدند")


def start_web_panel(m: RatholeMonitor):
    print(f"وب پنل در حال شروع روی پورت {m.config.get('web_port', DEFAULT_WEB_PORT)}...")
    print("برای اجرای وب پنل، از فایل web_server.py استفاده کنید")


def config_menu(m: RatholeMonitor):
    while True:
        print("\n⚙️ تنظیمات:")
        print(f"1. فاصله چک (فعلی: {m.config.get('check_interval', DEFAULT_CHECK_INTERVAL)} ثانیه)")
        print(f"2. ریستارت خودکار (فعلی: {'فعال' if m.config.get('auto_restart', True) else 'غیرفعال'})")
        print(f"3. حداکثر تلاش ریستارت (فعلی: {m.config.get('max_restart_attempts', DEFAULT_MAX_RESTART_ATTEMPTS)})")
        print(f"4. پنجره محدودسازی ریستارت (ثانیه) (فعلی: {m.config.get('restart_window_seconds', DEFAULT_RESTART_WINDOW_SECONDS)})")
        print(f"5. تاخیر قبل از start بعد از stop (ثانیه) (فعلی: {m.config.get('restart_delay', DEFAULT_RESTART_DELAY)})")
        print(f"6. بررسی مجدد لاگ از چند ثانیه قبل (فعلی: {m.config.get('journal_since_seconds', m.config.get('check_interval', DEFAULT_CHECK_INTERVAL))})")
        print(f"7. فعال‌سازی خودکار در صورت inactive (فعلی: {'فعال' if m.config.get('restart_on_inactive', True) else 'غیرفعال'})")
        print("8. بازگشت")

        choice = input("انتخاب: ").strip()
        try:
            if choice == "1":
                m.config["check_interval"] = int(input("فاصله جدید (ثانیه): ").strip())
            elif choice == "2":
                m.config["auto_restart"] = not m.config.get("auto_restart", True)
            elif choice == "3":
                m.config["max_restart_attempts"] = int(input("حداکثر تعداد تلاش: ").strip())
            elif choice == "4":
                m.config["restart_window_seconds"] = int(input("پنجره محدودسازی (ثانیه): ").strip())
            elif choice == "5":
                m.config["restart_delay"] = int(input("تاخیر (ثانیه): ").strip())
            elif choice == "6":
                m.config["journal_since_seconds"] = int(input("ثانیه: ").strip())
            elif choice == "7":
                m.config["restart_on_inactive"] = not m.config.get("restart_on_inactive", True)
            elif choice == "8":
                break
            else:
                print("انتخاب نامعتبر")
                continue
            m.save_config()
            print("تنظیمات ذخیره شد")
        except ValueError:
            print("مقدار نامعتبر")

def install_service():
    try:
        create_service()
        print("سرویس با موفقیت نصب شد")
        print("برای شروع: systemctl start rathole-monitor")
    except Exception as e:
        print(f"خطا در نصب سرویس: {e}")

def show_menu():
    monitor = RatholeMonitor()
    while True:
        print("\n" + "="*50)
        print("🔧 مانیتور تانل‌های Rathole")
        print("="*50)
        print("1. نمایش وضعیت تانل‌ها")
        print("2. شروع مانیتورینگ")
        print("3. توقف مانیتورینگ")
        print("4. ریستارت دستی تانل")
        print("5. تنظیمات")
        print("6. مشاهده لاگ‌ها")
        print("7. نصب سرویس")
        print("8. شروع وب پنل")
        print("0. خروج")
        print("-"*50)

        choice = input("انتخاب کنید: ").strip()
        if choice == "1":
            show_status(monitor)
        elif choice == "2":
            monitor.start_monitoring()
            print("مانیتورینگ شروع شد")
        elif choice == "3":
            monitor.stop_monitoring()
            print("مانیتورینگ متوقف شد")
        elif choice == "4":
            manual_restart(monitor)
        elif choice == "5":
            config_menu(monitor)
        elif choice == "6":
            show_logs()
        elif choice == "7":
            install_service()
        elif choice == "8":
            start_web_panel(monitor)
        elif choice == "0":
            break
        else:
            print("انتخاب نامعتبر!")

# ----- Entry point -----
def main():
    # نیاز به اجرا با root
    if os.geteuid() != 0:
        print("این اسکریپت باید با مجوز root اجرا شود")
        sys.exit(1)

    os.makedirs(MONITOR_DIR, exist_ok=True)
    with open(f"{MONITOR_DIR}/start_time", "w", encoding="utf-8") as f:
        f.write(now_iso())

    if len(sys.argv) > 1 and sys.argv[1] == "--daemon":
        monitor = RatholeMonitor()
        monitor.start_monitoring()
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            monitor.stop_monitoring()
    elif len(sys.argv) > 1 and sys.argv[1] == "--install":
        install_requirements()
        create_service()
        print("نصب کامل شد!")
    else:
        show_menu()


if __name__ == "__main__":
    main()
