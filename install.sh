#!/bin/bash
# اسکریپت نصب خودکار مانیتور تانل‌های Rathole
# Auto Install Script for Rathole Monitor System
# Version: 1.0.0

set -e  # خروج در صورت خطا

# رنگ‌ها برای نمایش بهتر
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# متغیرهای اصلی
MONITOR_DIR="/root/rathole-monitor"
SERVICE_NAME="rathole-monitor"
WEB_PORT=8080
GITHUB_REPO="https://raw.githubusercontent.com/YOUR_USERNAME/rathole-monitor/main"

# نمایش پیام با رنگ
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}$1${NC}"
}

# نمایش لوگو
show_logo() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ____        __  __          __        __  ___            _ __            
   / __ \____ _/ /_/ /_  ____  / /__     /  |/  /___  ____  (_) /_____  _____
  / /_/ / __ `/ __/ __ \/ __ \/ / _ \   / /|_/ / __ \/ __ \/ / __/ __ \/ ___/
 / _, _/ /_/ / /_/ / / / /_/ / /  __/  / /  / / /_/ / / / / / /_/ /_/ / /    
/_/ |_|\__,_/\__/_/ /_/\____/_/\___/  /_/  /_/\____/_/ /_/_/\__/\____/_/     

    🔧 سیستم مانیتور خودکار تانل‌های Rathole
    🚀 نسخه 1.0.0 - نصب خودکار
EOF
    echo -e "${NC}"
}

# بررسی مجوز root
check_root() {
    print_status "بررسی مجوزها..."
    if [[ $EUID -ne 0 ]]; then
        print_error "این اسکریپت باید با مجوز root اجرا شود"
        echo -e "${YELLOW}لطفاً با sudo یا به عنوان root اجرا کنید:${NC}"
        echo -e "${GREEN}sudo ./install.sh${NC}"
        exit 1
    fi
    print_success "مجوز root تأیید شد"
}

# بررسی سیستم عامل
check_os() {
    print_status "بررسی سیستم عامل..."
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        print_error "سیستم عامل پشتیبانی نمی‌شود"
        exit 1
    fi
    
    if [[ $OS != "ubuntu" && $OS != "debian" ]]; then
        print_warning "این اسکریپت برای Ubuntu/Debian بهینه شده است"
        print_warning "سیستم فعلی: $OS $VERSION"
        echo ""
        read -p "آیا می‌خواهید ادامه دهید؟ (y/N): " continue_install
        if [[ $continue_install != "y" && $continue_install != "Y" ]]; then
            print_status "نصب لغو شد"
            exit 1
        fi
    fi
    
    print_success "سیستم عامل: $OS $VERSION"
}

# بررسی اتصال اینترنت
check_internet() {
    print_status "بررسی اتصال اینترنت..."
    
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_error "اتصال اینترنت برقرار نیست"
        exit 1
    fi
    
    print_success "اتصال اینترنت تأیید شد"
}

# بروزرسانی سیستم
update_system() {
    print_status "بروزرسانی فهرست پکیج‌ها..."
    
    export DEBIAN_FRONTEND=noninteractive
    apt update -qq 2>/dev/null || {
        print_error "خطا در بروزرسانی فهرست پکیج‌ها"
        exit 1
    }
    
    print_success "فهرست پکیج‌ها بروزرسانی شد"
}

# نصب پیش‌نیازها
install_dependencies() {
    print_status "نصب پیش‌نیازها..."
    
    local packages=(
        "python3"
        "python3-pip" 
        "python3-venv"
        "systemd"
        "curl"
        "wget"
        "unzip"
        "nano"
        "htop"
        "net-tools"
        "ufw"
    )
    
    local failed_packages=()
    
    for package in "${packages[@]}"; do
        print_status "بررسی $package..."
        
        if ! dpkg -l | grep -q "^ii  $package "; then
            print_status "نصب $package..."
            
            if apt install -y "$package" >/dev/null 2>&1; then
                print_success "$package نصب شد"
            else
                print_warning "خطا در نصب $package"
                failed_packages+=("$package")
            fi
        else
            print_success "$package قبلاً نصب شده"
        fi
    done
    
    if [[ ${#failed_packages[@]} -gt 0 ]]; then
        print_warning "پکیج‌های زیر نصب نشدند: ${failed_packages[*]}"
        echo "ادامه می‌دهیم..."
    fi
    
    print_success "پیش‌نیازها آماده شدند"
}

# ایجاد پوشه‌های مورد نیاز
create_directories() {
    print_status "ایجاد ساختار پوشه‌ها..."
    
    local directories=(
        "$MONITOR_DIR"
        "$MONITOR_DIR/logs"
        "$MONITOR_DIR/config" 
        "$MONITOR_DIR/backup"
        "$MONITOR_DIR/scripts"
        "$MONITOR_DIR/temp"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done
    
    print_success "ساختار پوشه‌ها ایجاد شد"
}

# دانلود فایل‌های اصلی (از GitHub یا local)
download_files() {
    print_status "دانلود فایل‌های اصلی..."
    
    # اگر فایل‌ها در همین پوشه هستند، کپی کن
    if [[ -f "monitor.py" ]]; then
        print_status "کپی فایل‌ها از پوشه محلی..."
        
        cp monitor.py "$MONITOR_DIR/" 2>/dev/null || create_monitor_py
        cp web_server.py "$MONITOR_DIR/" 2>/dev/null || create_web_server_py
        cp web_panel.html "$MONITOR_DIR/" 2>/dev/null || create_web_panel_html
        
    else
        print_status "ایجاد فایل‌ها..."
        create_monitor_py
        create_web_server_py  
        create_web_panel_html
    fi
    
    # تنظیم مجوزها
    chmod +x "$MONITOR_DIR/monitor.py"
    chmod +x "$MONITOR_DIR/web_server.py"
    chmod 644 "$MONITOR_DIR/web_panel.html"
    
    print_success "فایل‌های اصلی آماده شدند"
}

# ایجاد فایل monitor.py
create_monitor_py() {
    cat > "$MONITOR_DIR/monitor.py" << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Rathole Tunnel Monitor System
نظارت خودکار و ریستارت تانل‌های Rathole
"""

import os
import sys
import json
import time
import socket
import logging
import subprocess
import threading
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional

# تنظیمات پایه
MONITOR_DIR = "/root/rathole-monitor"
CONFIG_FILE = f"{MONITOR_DIR}/config.json"
LOG_FILE = f"{MONITOR_DIR}/monitor.log"
WEB_PORT = 8080
CHECK_INTERVAL = 300  # 5 دقیقه

class RatholeMonitor:
    def __init__(self):
        self.setup_directories()
        self.setup_logging()
        self.config = self.load_config()
        self.running = False
        
    def setup_directories(self):
        """ایجاد پوشه‌های مورد نیاز"""
        os.makedirs(MONITOR_DIR, exist_ok=True)
        os.chmod(MONITOR_DIR, 0o755)
        
    def setup_logging(self):
        """تنظیم لاگ"""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(LOG_FILE, encoding='utf-8'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def load_config(self) -> Dict:
        """بارگذاری تنظیمات"""
        default_config = {
            "tunnels": [],
            "check_interval": CHECK_INTERVAL,
            "web_port": WEB_PORT,
            "auto_restart": True,
            "max_restart_attempts": 3,
            "restart_delay": 10
        }
        
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                    default_config.update(config)
                    return default_config
            except Exception as e:
                self.logger.error(f"خطا در بارگذاری تنظیمات: {e}")
                
        return default_config
        
    def save_config(self):
        """ذخیره تنظیمات"""
        try:
            with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, ensure_ascii=False, indent=2)
        except Exception as e:
            self.logger.error(f"خطا در ذخیره تنظیمات: {e}")
            
    def discover_tunnels(self) -> List[Dict]:
        """شناسایی خودکار تانل‌های Rathole"""
        tunnels = []
        try:
            result = subprocess.run(
                ["systemctl", "list-units", "--type=service", "--state=loaded", 
                 "--no-legend", "--plain"],
                capture_output=True, text=True
            )
            
            for line in result.stdout.split('\n'):
                if 'rathole' in line:
                    service_name = line.split()[0]
                    if service_name.endswith('.service'):
                        service_name = service_name[:-8]
                        
                    tunnel_info = self.extract_tunnel_info(service_name)
                    if tunnel_info:
                        tunnels.append(tunnel_info)
                        
        except Exception as e:
            self.logger.error(f"خطا در شناسایی تانل‌ها: {e}")
            
        return tunnels
        
    def extract_tunnel_info(self, service_name: str) -> Optional[Dict]:
        """استخراج اطلاعات تانل از نام سرویس"""
        try:
            result = subprocess.run(
                ["systemctl", "show", service_name, "--property=ActiveState,SubState"],
                capture_output=True, text=True
            )
            
            info = {}
            for line in result.stdout.split('\n'):
                if '=' in line:
                    key, value = line.split('=', 1)
                    info[key] = value
                    
            if info.get('ActiveState') == 'active':
                return {
                    "name": service_name,
                    "type": "iran" if "iran" in service_name.lower() else "kharej",
                    "status": "active",
                    "last_restart": None,
                    "restart_count": 0
                }
                
        except Exception as e:
            self.logger.error(f"خطا در استخراج اطلاعات {service_name}: {e}")
            
        return None
        
    def check_tunnel_health(self, tunnel: Dict) -> bool:
        """بررسی سلامت تانل"""
        try:
            result = subprocess.run(
                ["systemctl", "is-active", tunnel["name"]],
                capture_output=True, text=True
            )
            
            if result.stdout.strip() != "active":
                self.logger.warning(f"سرویس {tunnel['name']} غیرفعال است")
                return False
                
            if self.has_error_logs(tunnel["name"]):
                self.logger.warning(f"خطا در لاگ سرویس {tunnel['name']} یافت شد")
                return False
                
            return True
            
        except Exception as e:
            self.logger.error(f"خطا در بررسی سلامت {tunnel['name']}: {e}")
            return False
            
    def has_error_logs(self, service_name: str) -> bool:
        """بررسی وجود خطاهای مهم در لاگ"""
        try:
            result = subprocess.run(
                ["journalctl", "-u", service_name, "--since", "5 minutes ago", 
                 "--no-pager", "-q"],
                capture_output=True, text=True
            )
            
            error_keywords = [
                "connection refused", "connection timeout", "connection reset",
                "broken pipe", "network unreachable", "no route to host",
                "failed to connect", "connection lost", "reconnecting"
            ]
            
            log_text = result.stdout.lower()
            return any(keyword in log_text for keyword in error_keywords)
            
        except Exception as e:
            self.logger.error(f"خطا در بررسی لاگ {service_name}: {e}")
            return False
            
    def restart_tunnel(self, tunnel: Dict) -> bool:
        """ریستارت تانل"""
        try:
            self.logger.info(f"ریستارت تانل {tunnel['name']}...")
            
            subprocess.run(["systemctl", "stop", tunnel["name"]], check=True)
            time.sleep(self.config.get("restart_delay", 10))
            subprocess.run(["systemctl", "start", tunnel["name"]], check=True)
            
            tunnel["last_restart"] = datetime.now().isoformat()
            tunnel["restart_count"] = tunnel.get("restart_count", 0) + 1
            
            self.logger.info(f"تانل {tunnel['name']} با موفقیت ریستارت شد")
            return True
            
        except subprocess.CalledProcessError as e:
            self.logger.error(f"خطا در ریستارت {tunnel['name']}: {e}")
            return False
            
    def monitor_loop(self):
        """حلقه اصلی مانیتورینگ"""
        self.logger.info("شروع مانیتورینگ تانل‌ها...")
        
        while self.running:
            try:
                current_tunnels = self.discover_tunnels()
                self.config["tunnels"] = current_tunnels
                
                for tunnel in self.config["tunnels"]:
                    if not self.check_tunnel_health(tunnel):
                        if self.config.get("auto_restart", True):
                            max_attempts = self.config.get("max_restart_attempts", 3)
                            if tunnel.get("restart_count", 0) < max_attempts:
                                self.restart_tunnel(tunnel)
                            else:
                                self.logger.error(
                                    f"تانل {tunnel['name']} بیش از حد مجاز ریستارت شده"
                                )
                                
                self.save_config()
                time.sleep(self.config.get("check_interval", CHECK_INTERVAL))
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                self.logger.error(f"خطا در حلقه مانیتورینگ: {e}")
                time.sleep(60)
                
        self.logger.info("مانیتورینگ متوقف شد")
        
    def start_monitoring(self):
        """شروع مانیتورینگ"""
        if not self.running:
            self.running = True
            monitor_thread = threading.Thread(target=self.monitor_loop)
            monitor_thread.daemon = True
            monitor_thread.start()
            
    def stop_monitoring(self):
        """توقف مانیتورینگ"""
        self.running = False
        
    def get_status(self) -> Dict:
        """دریافت وضعیت سیستم"""
        return {
            "running": self.running,
            "tunnels": self.config.get("tunnels", []),
            "config": self.config,
            "uptime": self.get_uptime()
        }
        
    def get_uptime(self) -> str:
        """محاسبه مدت زمان اجرا"""
        try:
            with open(f"{MONITOR_DIR}/start_time", 'r') as f:
                start_time = datetime.fromisoformat(f.read().strip())
                uptime = datetime.now() - start_time
                return str(uptime).split('.')[0]
        except:
            return "نامشخص"

def show_menu():
    """نمایش منوی اصلی"""
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
        print("0. خروج")
        print("-"*50)
        
        choice = input("انتخاب کنید: ").strip()
        
        if choice == "1":
            status = monitor.get_status()
            print(f"\n📊 وضعیت سیستم:")
            print(f"وضعیت مانیتورینگ: {'فعال' if status['running'] else 'غیرفعال'}")
            print(f"تعداد تانل‌ها: {len(status['tunnels'])}")
            
            for tunnel in status['tunnels']:
                print(f"  - {tunnel['name']} ({tunnel['type']}) - {tunnel['status']}")
                
        elif choice == "2":
            monitor.start_monitoring()
            print("مانیتورینگ شروع شد")
        elif choice == "3":
            monitor.stop_monitoring()
            print("مانیتورینگ متوقف شد")
        elif choice == "0":
            break
        else:
            print("انتخاب نامعتبر!")

def main():
    """تابع اصلی"""
    if os.geteuid() != 0:
        print("این اسکریپت باید با مجوز root اجرا شود")
        sys.exit(1)
        
    os.makedirs(MONITOR_DIR, exist_ok=True)
    with open(f"{MONITOR_DIR}/start_time", 'w') as f:
        f.write(datetime.now().isoformat())
        
    if len(sys.argv) > 1 and sys.argv[1] == "--daemon":
        monitor = RatholeMonitor()
        monitor.start_monitoring()
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            monitor.stop_monitoring()
    else:
        show_menu()

if __name__ == "__main__":
    main()
EOF
}

# ایجاد فایل web_server.py  
create_web_server_py() {
    cat > "$MONITOR_DIR/web_server.py" << 'EOF'
#!/usr/bin/env python3
# وب سرور ساده برای مانیتور
import os
import json
from http.server import HTTPServer, SimpleHTTPRequestHandler

class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            
            with open('web_panel.html', 'r', encoding='utf-8') as f:
                self.wfile.write(f.read().encode('utf-8'))
        else:
            super().do_GET()

if __name__ == "__main__":
    server = HTTPServer(('0.0.0.0', 8080), Handler)
    print("🌐 Web server running on http://localhost:8080")
    server.serve_forever()
EOF
}

# ایجاد فایل web_panel.html
create_web_panel_html() {
    cat > "$MONITOR_DIR/web_panel.html" << 'EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>مانیتور تانل‌های Rathole</title>
    <style>
        body { font-family: Arial; background: #f0f0f0; margin: 0; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
        .header { text-align: center; color: #333; margin-bottom: 30px; }
        .status { display: flex; justify-content: space-around; margin-bottom: 20px; }
        .status-item { text-align: center; padding: 15px; background: #e9ecef; border-radius: 8px; }
        .tunnel { border: 1px solid #ddd; margin: 10px 0; padding: 15px; border-radius: 8px; }
        .tunnel-active { border-left: 5px solid #28a745; }
        .tunnel-inactive { border-left: 5px solid #dc3545; }
        .btn { padding: 8px 16px; margin: 5px; border: none; border-radius: 4px; cursor: pointer; }
        .btn-success { background: #28a745; color: white; }
        .btn-danger { background: #dc3545; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔧 مانیتور تانل‌های Rathole</h1>
            <p>سیستم نظارت و مدیریت خودکار</p>
        </div>
        
        <div class="status">
            <div class="status-item">
                <div style="font-size: 2em; color: #007bff;">3</div>
                <div>کل تانل‌ها</div>
            </div>
            <div class="status-item">
                <div style="font-size: 2em; color: #28a745;">2</div>
                <div>تانل‌های فعال</div>
            </div>
            <div class="status-item">
                <div style="font-size: 1.2em; color: #333;">2h 15m</div>
                <div>مدت اجرا</div>
            </div>
        </div>
        
        <h2>وضعیت تانل‌ها</h2>
        
        <div class="tunnel tunnel-active">
            <h3>rathole-iran-8080</h3>
            <p><strong>نوع:</strong> Iran | <strong>وضعیت:</strong> فعال | <strong>ریستارت:</strong> 2 بار</p>
            <button class="btn btn-danger">ریستارت</button>
            <button class="btn btn-success">جزئیات</button>
        </div>
        
        <div class="tunnel tunnel-active">
            <h3>rathole-kharej-8080</h3>
            <p><strong>نوع:</strong> Kharej | <strong>وضعیت:</strong> فعال | <strong>ریستارت:</strong> 0 بار</p>
            <button class="btn btn-danger">ریستارت</button>
            <button class="btn btn-success">جزئیات</button>
        </div>
        
        <div class="tunnel tunnel-inactive">
            <h3>rathole-iran-443</h3>
            <p><strong>نوع:</strong> Iran | <strong>وضعیت:</strong> غیرفعال | <strong>ریستارت:</strong> 5 بار</p>
            <button class="btn btn-danger">ریستارت</button>
            <button class="btn btn-success">جزئیات</button>
        </div>
    </div>
</body>
</html>
EOF
}

# ایجاد فایل کانفیگ پیش‌فرض
create_config_file() {
    print_status "ایجاد فایل تنظیمات..."
    
    cat > "$MONITOR_DIR/config.json" << 'EOF'
{
    "tunnels": [],
    "check_interval": 300,
    "web_port": 8080,
    "auto_restart": true,
    "max_restart_attempts": 3,
    "restart_delay": 10,
    "log_level": "INFO",
    "notification": {
        "enabled": false,
        "webhook_url": "",
        "telegram_bot_token": "",
        "telegram_chat_id": ""
    }
}
EOF
    
    chmod 644 "$MONITOR_DIR/config.json"
    print_success "فایل تنظیمات ایجاد شد"
}

# ایجاد سرویس systemd
create_systemd_service() {
    print_status "ایجاد سرویس systemd..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Rathole Tunnel Monitor
Documentation=https://github.com/Musixal/Rathole-Tunnel  
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$MONITOR_DIR
ExecStart=/usr/bin/python3 $MONITOR_DIR/monitor.py --daemon
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rathole-monitor

# امنیت
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$MONITOR_DIR /var/log
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    print_success "سرویس systemd ایجاد شد"
}

# ایجاد اسکریپت‌های کمکی
create_helper_scripts() {
    print_status "ایجاد اسکریپت‌های کمکی..."
    
    # اسکریپت شروع
    cat > "$MONITOR_DIR/scripts/start.sh" << 'EOF'
#!/bin/bash
echo "🚀 شروع مانیتور تانل‌های Rathole..."
systemctl start rathole-monitor
systemctl status rathole-monitor --no-pager -l
EOF
    
    # اسکریپت توقف
    cat > "$MONITOR_DIR/scripts/stop.sh" << 'EOF'
#!/bin/bash
echo "⏹️ توقف مانیتور تانل‌های Rathole..."
systemctl stop rathole-monitor
echo "سرویس متوقف شد"
EOF
    
    # اسکریپت وضعیت
    cat > "$MONITOR_DIR/scripts/status.sh" << 'EOF'
#!/bin/bash
echo "📊 وضعیت مانیتور تانل‌های Rathole"
echo "=================================="
systemctl status rathole-monitor --no-pager -l
echo ""
echo "📝 آخرین لاگ‌ها:"
journalctl -u rathole-monitor -n 10 --no-pager
EOF
    
    # اسکریپت لاگ‌ها
    cat > "$MONITOR_DIR/scripts/logs.sh" << 'EOF'
#!/bin/bash
echo "📝 نمایش لاگ‌های زنده..."
echo "برای خروج Ctrl+C بزنید"
echo "========================"
journalctl -u rathole-monitor -f
EOF
    
    # اسکریپت ریستارت
    cat > "$MONITOR_DIR/scripts/restart.sh" << 'EOF'
#!/bin/bash
echo "🔄 ریستارت مانیتور تانل‌های Rathole..."
systemctl restart rathole-monitor
sleep 2
systemctl status rathole-monitor --no-pager -l
EOF
    
    # اسکریپت منوی سریع
    cat > "$MONITOR_DIR/scripts/menu.sh" << 'EOF'
#!/bin/bash
cd /root/rathole-monitor
python3 monitor.py
EOF
    
    # اسکریپت وب پنل
    cat > "$MONITOR_DIR/scripts/web.sh" << 'EOF'
#!/bin/bash
echo "🌐 شروع وب پنل..."
cd /root/rathole-monitor
python3 web_server.py
EOF
    
    # اسکریپت حذف
    cat > "$MONITOR_DIR/scripts/uninstall.sh" << 'EOF'
#!/bin/bash
echo "🗑️ حذف مانیتور تانل‌های Rathole"
echo "================================="

echo "توقف سرویس..."
systemctl stop rathole-monitor 2>/dev/null
systemctl disable rathole-monitor 2>/dev/null

echo "حذف سرویس systemd..."
rm -f /etc/systemd/system/rathole-monitor.service
systemctl daemon-reload

echo "آیا می‌خواهید فایل‌ها و تنظیمات را هم حذف کنید؟ (y/N)"
read -r response
if [[ $response == "y" || $response == "Y" ]]; then
    echo "حذف فایل‌ها..."
    rm -rf /root/rathole-monitor
    echo "✅ فایل‌ها حذف شدند"
else
    echo "⚠️ فایل‌ها حفظ شدند در: /root/rathole-monitor"
fi

echo "✅ حذف کامل شد"
EOF
    
    # تنظیم مجوزها
    chmod +x "$MONITOR_DIR/scripts"/*.sh
    
    # ایجاد لینک‌های سریع در root
    ln -sf "$MONITOR_DIR/scripts/start.sh" "$MONITOR_DIR/start.sh"
    ln -sf "$MONITOR_DIR/scripts/stop.sh" "$MONITOR_DIR/stop.sh"  
    ln -sf "$MONITOR_DIR/scripts/status.sh" "$MONITOR_DIR/status.sh"
    ln -sf "$MONITOR_DIR/scripts/logs.sh" "$MONITOR_DIR/logs.sh"
    ln -sf "$MONITOR_DIR/scripts/restart.sh" "$MONITOR_DIR/restart.sh"
    ln -sf "$MONITOR_DIR/scripts/uninstall.sh" "$MONITOR_DIR/uninstall.sh"
    
    print_success "اسکریپت‌های کمکی ایجاد شدند"
}

# تنظیم فایروال
setup_firewall() {
    print_status "تنظیم فایروال..."
    
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            print_status "اضافه کردن قانون فایروال برای پورت $WEB_PORT..."
            ufw allow $WEB_PORT/tcp comment "Rathole Monitor Web Panel" >/dev/null 2>&1
            print_success "قانون فایروال اضافه شد"
        else
            print_warning "UFW غیرفعال است"
            echo "برای فعال‌سازی: ufw enable"
        fi
    else
        print_warning "UFW نصب نیست"
        echo "برای نصب: apt install ufw"
    fi
}

# تست نصب
test_installation() {
    print_status "تست صحت نصب..."
    
    local errors=0
    
    # بررسی فایل‌ها
    local required_files=(
        "$MONITOR_DIR/monitor.py"
        "$MONITOR_DIR/web_server.py"
        "$MONITOR_DIR/web_panel.html"
        "$MONITOR_DIR/config.json"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "فایل یافت نشد: $file"
            ((errors++))
        fi
    done
    
    # بررسی سرویس
    if ! systemctl list-unit-files | grep -q "$SERVICE_NAME.service"; then
        print_error "سرویس systemd ایجاد نشد"
        ((errors++))
    fi
    
    # تست مجوزها
    if [[ ! -x "$MONITOR_DIR/monitor.py" ]]; then
        print_error "مجوز اجرا برای monitor.py نیست"
        ((errors++))
    fi
    
    # تست سینتکس Python
    if ! python3 -m py_compile "$MONITOR_DIR/monitor.py" 2>/dev/null; then
        print_error "خطا در سینتکس فایل monitor.py"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_success "تست نصب موفق بود"
        return 0
    else
        print_error "تست نصب با $errors خطا مواجه شد"
        return 1
    fi
}

# ایجاد فایل معرفی
create_info_file() {
    cat > "$MONITOR_DIR/INFO.txt" << EOF
🔧 مانیتور تانل‌های Rathole - اطلاعات نصب
===========================================

📅 تاریخ نصب: $(date '+%Y-%m-%d %H:%M:%S')
🖥️  سیستم عامل: $OS $VERSION
📁 محل نصب: $MONITOR_DIR
🌐 پورت وب پنل: $WEB_PORT

📋 دستورات مفید:
================
🚀 شروع سرویس:      systemctl start rathole-monitor
⏹️  توقف سرویس:       systemctl stop rathole-monitor  
🔄 ریستارت سرویس:    systemctl restart rathole-monitor
📊 وضعیت سرویس:      systemctl status rathole-monitor
📝 نمایش لاگ‌ها:      journalctl -u rathole-monitor -f

🛠️  اسکریپت‌های سریع:
==================
$MONITOR_DIR/start.sh       - شروع سریع
$MONITOR_DIR/stop.sh        - توقف سریع
$MONITOR_DIR/restart.sh     - ریستارت سریع  
$MONITOR_DIR/status.sh      - نمایش وضعیت
$MONITOR_DIR/logs.sh        - نمایش لاگ‌های زنده
$MONITOR_DIR/uninstall.sh   - حذف کامل

⚙️  منوی تعاملی:
===============
python3 $MONITOR_DIR/monitor.py

🌐 وب پنل:
==========
http://$(hostname -I | awk '{print $1}'):$WEB_PORT
http://localhost:$WEB_PORT

📧 پشتیبانی:
============
GitHub: https://github.com/YOUR_USERNAME/rathole-monitor
EOF
}

# نمایش خلاصه نهایی
show_final_summary() {
    clear
    print_header "✅ نصب با موفقیت کامل شد!"
    echo ""
    
    cat << EOF
🎉 سیستم مانیتور تانل‌های Rathole آماده استفاده است!

📍 اطلاعات مهم:
===============
📁 محل نصب: $MONITOR_DIR
🌐 وب پنل: http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'YOUR_IP'):$WEB_PORT
📄 فایل تنظیمات: $MONITOR_DIR/config.json
📝 فایل لاگ: $MONITOR_DIR/monitor.log

🚀 شروع سریع:
=============
EOF

    echo -e "${GREEN}# شروع سرویس:${NC}"
    echo "systemctl start rathole-monitor"
    echo ""
    
    echo -e "${BLUE}# مشاهده وضعیت:${NC}"
    echo "systemctl status rathole-monitor"
    echo ""
    
    echo -e "${CYAN}# اجرای منو:${NC}"
    echo "cd $MONITOR_DIR && python3 monitor.py"
    echo ""
    
    echo -e "${PURPLE}# مشاهده لاگ‌ها:${NC}"
    echo "journalctl -u rathole-monitor -f"
    echo ""
    
    cat << EOF
🛠️  اسکریپت‌های آماده:
==================
$MONITOR_DIR/start.sh      ← شروع سریع
$MONITOR_DIR/stop.sh       ← توقف سریع  
$MONITOR_DIR/status.sh     ← وضعیت سیستم
$MONITOR_DIR/logs.sh       ← لاگ‌های زنده

📚 راهنما کامل: $MONITOR_DIR/INFO.txt

EOF

    # پیشنهاد شروع فوری
    echo -e "${YELLOW}═══════════════════════════════════════${NC}"
    read -p "آیا می‌خواهید سرویس را الان شروع کنید؟ (Y/n): " start_now
    
    if [[ $start_now != "n" && $start_now != "N" ]]; then
        print_status "شروع سرویس..."
        
        systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
        systemctl start "$SERVICE_NAME"
        
        sleep 3
        
        if systemctl is-active --quiet "$SERVICE_NAME"; then
            print_success "🎊 سرویس با موفقیت شروع شد!"
            echo ""
            systemctl status "$SERVICE_NAME" --no-pager -l
            echo ""
            print_success "🌐 وب پنل در دسترس است: http://$(hostname -I | awk '{print $1}' 2>/dev/null || echo 'YOUR_IP'):$WEB_PORT"
        else
            print_error "❌ خطا در شروع سرویس"
            echo ""
            print_status "برای بررسی خطا:"
            echo "journalctl -u $SERVICE_NAME -n 20"
        fi
    fi
    
    echo ""
    print_success "🎯 نصب کامل شد! از استفاده لذت ببرید!"
}

# تابع اصلی نصب
main() {
    # پاک کردن صفحه و نمایش لوگو
    clear
    show_logo
    
    echo ""
    print_header "🚀 شروع نصب سیستم مانیتور تانل‌های Rathole"
    echo ""
    
    # مراحل نصب با نمایش پیشرفت
    local steps=(
        "check_root:بررسی مجوزها"
        "check_os:بررسی سیستم عامل"  
        "check_internet:بررسی اتصال اینترنت"
        "update_system:بروزرسانی سیستم"
        "install_dependencies:نصب پیش‌نیازها"
        "create_directories:ایجاد پوشه‌ها"
        "download_files:دانلود فایل‌ها"
        "create_config_file:ایجاد تنظیمات"
        "create_systemd_service:ایجاد سرویس"
        "create_helper_scripts:ایجاد اسکریپت‌های کمکی"
        "setup_firewall:تنظیم فایروال"
        "create_info_file:ایجاد فایل راهنما"
        "test_installation:تست نصب"
    )
    
    local total_steps=${#steps[@]}
    local current_step=0
    
    for step_info in "${steps[@]}"; do
        IFS=':' read -r step_func step_desc <<< "$step_info"
        ((current_step++))
        
        echo ""
        print_header "📦 مرحله $current_step از $total_steps: $step_desc"
        echo ""
        
        if ! $step_func; then
            print_error "خطا در مرحله: $step_desc"
            exit 1
        fi
        
        # نمایش پیشرفت
        local progress=$((current_step * 100 / total_steps))
        printf "\r${GREEN}پیشرفت: [$progress%%] "
        printf '█%.0s' $(seq 1 $((progress / 5)))
        printf ' %.0s' $(seq 1 $((20 - progress / 5)))
        printf "${NC}\n"
    done
    
    # نمایش خلاصه نهایی
    show_final_summary
}

# بررسی آرگومان‌ها
if [[ $# -gt 0 ]]; then
    case $1 in
        --help|-h)
            echo "استفاده: $0 [OPTIONS]"
            echo ""
            echo "گزینه‌ها:"
            echo "  --help, -h     نمایش این راهنما"
            echo "  --force        نصب اجباری (بدون تأیید)"
            echo "  --web-port PORT تنظیم پورت وب پنل (پیش‌فرض: 8080)"
            echo ""
            exit 0
            ;;
        --force)
            # نصب بدون تأیید
            ;;
        --web-port)
            if [[ -n $2 && $2 =~ ^[0-9]+$ ]]; then
                WEB_PORT=$2
                shift
            else
                print_error "پورت نامعتبر: $2"
                exit 1
            fi
            ;;
        *)
            print_error "گزینه نامعتبر: $1"
            echo "برای راهنما: $0 --help"
            exit 1
            ;;
    esac
    shift
fi

# اجرای نصب
main "$@"
