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
                    # ادغام با تنظیمات پیش فرض
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
            # جستجو برای سرویس‌های rathole
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
                        
                    # استخراج اطلاعات سرویس
                    tunnel_info = self.extract_tunnel_info(service_name)
                    if tunnel_info:
                        tunnels.append(tunnel_info)
                        
        except Exception as e:
            self.logger.error(f"خطا در شناسایی تانل‌ها: {e}")
            
        return tunnels
        
    def extract_tunnel_info(self, service_name: str) -> Optional[Dict]:
        """استخراج اطلاعات تانل از نام سرویس"""
        try:
            # بررسی وضعیت سرویس
            result = subprocess.run(
                ["systemctl", "show", service_name, "--property=ActiveState,SubState,ExecStart"],
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
                    "restart_count": 0,
                    "config_path": self.find_config_path(service_name)
                }
                
        except Exception as e:
            self.logger.error(f"خطا در استخراج اطلاعات {service_name}: {e}")
            
        return None
        
    def find_config_path(self, service_name: str) -> Optional[str]:
        """پیدا کردن مسیر فایل کانفیگ تانل"""
        common_paths = [
            f"/etc/rathole/{service_name}.toml",
            f"/root/rathole/{service_name}.toml",
            f"/opt/rathole/{service_name}.toml"
        ]
        
        for path in common_paths:
            if os.path.exists(path):
                return path
                
        return None
        
    def check_port(self, host: str, port: int, timeout: int = 5) -> bool:
        """بررسی دسترسی پورت"""
        try:
            with socket.create_connection((host, port), timeout=timeout):
                return True
        except (socket.timeout, socket.error, ConnectionRefusedError):
            return False
            
    def check_tunnel_health(self, tunnel: Dict) -> bool:
        """بررسی سلامت تانل"""
        try:
            # بررسی وضعیت سرویس
            result = subprocess.run(
                ["systemctl", "is-active", tunnel["name"]],
                capture_output=True, text=True
            )
            
            if result.stdout.strip() != "active":
                self.logger.warning(f"سرویس {tunnel['name']} غیرفعال است")
                return False
                
            # بررسی لاگ‌های خطا
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
            
            # توقف سرویس
            subprocess.run(["systemctl", "stop", tunnel["name"]], check=True)
            time.sleep(self.config.get("restart_delay", 10))
            
            # شروع سرویس
            subprocess.run(["systemctl", "start", tunnel["name"]], check=True)
            
            # بروزرسانی اطلاعات
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
                # بروزرسانی لیست تانل‌ها
                current_tunnels = self.discover_tunnels()
                self.config["tunnels"] = current_tunnels
                
                # بررسی هر تانل
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
                                
                # ذخیره تنظیمات
                self.save_config()
                
                # انتظار تا چک بعدی
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

def install_requirements():
    """نصب پیش‌نیازها"""
    print("نصب پیش‌نیازها...")
    
    # بروزرسانی سیستم
    subprocess.run(["apt", "update"], check=True)
    
    # نصب پکیج‌های مورد نیاز
    packages = ["python3", "python3-pip", "systemd"]
    for package in packages:
        subprocess.run(["apt", "install", "-y", package], check=True)
        
    print("پیش‌نیازها نصب شدند")

def create_service():
    """ایجاد سرویس systemd"""
    service_content = f"""[Unit]
Description=Rathole Tunnel Monitor
After=network.target

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
    
    with open("/etc/systemd/system/rathole-monitor.service", "w") as f:
        f.write(service_content)
        
    subprocess.run(["systemctl", "daemon-reload"], check=True)
    subprocess.run(["systemctl", "enable", "rathole-monitor"], check=True)

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

def show_status(monitor):
    """نمایش وضعیت تانل‌ها"""
    status = monitor.get_status()
    
    print(f"\n📊 وضعیت سیستم:")
    print(f"وضعیت مانیتورینگ: {'فعال' if status['running'] else 'غیرفعال'}")
    print(f"مدت زمان اجرا: {status['uptime']}")
    print(f"تعداد تانل‌ها: {len(status['tunnels'])}")
    
    print(f"\n🔗 لیست تانل‌ها:")
    for tunnel in status['tunnels']:
        print(f"  - {tunnel['name']} ({tunnel['type']})")
        print(f"    وضعیت: {tunnel['status']}")
        print(f"    تعداد ریستارت: {tunnel.get('restart_count', 0)}")
        if tunnel.get('last_restart'):
            print(f"    آخرین ریستارت: {tunnel['last_restart']}")

def manual_restart(monitor):
    """ریستارت دستی تانل"""
    tunnels = monitor.config.get('tunnels', [])
    if not tunnels:
        print("هیچ تانلی یافت نشد")
        return
        
    print("\nانتخاب تانل برای ریستارت:")
    for i, tunnel in enumerate(tunnels, 1):
        print(f"{i}. {tunnel['name']}")
        
    choice = input("شماره تانل: ").strip()
    try:
        index = int(choice) - 1
        if 0 <= index < len(tunnels):
            if monitor.restart_tunnel(tunnels[index]):
                print("تانل با موفقیت ریستارت شد")
            else:
                print("خطا در ریستارت تانل")
        else:
            print("شماره نامعتبر")
    except ValueError:
        print("شماره نامعتبر")

def config_menu(monitor):
    """منوی تنظیمات"""
    while True:
        print(f"\n⚙️ تنظیمات:")
        print(f"1. فاصله چک (فعلی: {monitor.config.get('check_interval', 300)} ثانیه)")
        print(f"2. ریستارت خودکار (فعلی: {'فعال' if monitor.config.get('auto_restart', True) else 'غیرفعال'})")
        print(f"3. حداکثر تلاش ریستارت (فعلی: {monitor.config.get('max_restart_attempts', 3)})")
        print("4. بازگشت")
        
        choice = input("انتخاب: ").strip()
        
        if choice == "1":
            try:
                interval = int(input("فاصله جدید (ثانیه): "))
                monitor.config["check_interval"] = interval
                monitor.save_config()
                print("تنظیمات ذخیره شد")
            except ValueError:
                print("مقدار نامعتبر")
        elif choice == "2":
            monitor.config["auto_restart"] = not monitor.config.get("auto_restart", True)
            monitor.save_config()
            print("تنظیمات ذخیره شد")
        elif choice == "3":
            try:
                attempts = int(input("حداکثر تعداد تلاش: "))
                monitor.config["max_restart_attempts"] = attempts
                monitor.save_config()
                print("تنظیمات ذخیره شد")
            except ValueError:
                print("مقدار نامعتبر")
        elif choice == "4":
            break

def show_logs():
    """نمایش لاگ‌ها"""
    try:
        subprocess.run(["tail", "-n", "50", LOG_FILE], check=True)
    except subprocess.CalledProcessError:
        print("خطا در نمایش لاگ‌ها")

def install_service():
    """نصب سرویس"""
    try:
        create_service()
        print("سرویس با موفقیت نصب شد")
        print("برای شروع: systemctl start rathole-monitor")
    except Exception as e:
        print(f"خطا در نصب سرویس: {e}")

def start_web_panel(monitor):
    """شروع وب پنل"""
    print(f"وب پنل در حال شروع روی پورت {monitor.config.get('web_port', 8080)}...")
    # اینجا می‌تونی وب سرور اضافه کنی
    print("برای اجرای وب پنل، از فایل web_panel.py استفاده کنید")

def main():
    """تابع اصلی"""
    # بررسی مجوز root
    if os.geteuid() != 0:
        print("این اسکریپت باید با مجوز root اجرا شود")
        sys.exit(1)
        
    # ایجاد فایل start_time
    os.makedirs(MONITOR_DIR, exist_ok=True)
    with open(f"{MONITOR_DIR}/start_time", 'w') as f:
        f.write(datetime.now().isoformat())
        
    # بررسی آرگومان‌ها
    if len(sys.argv) > 1 and sys.argv[1] == "--daemon":
        # اجرا به عنوان daemon
        monitor = RatholeMonitor()
        monitor.start_monitoring()
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            monitor.stop_monitoring()
    elif len(sys.argv) > 1 and sys.argv[1] == "--install":
        # نصب پیش‌نیازها
        install_requirements()
        create_service()
        print("نصب کامل شد!")
    else:
        # نمایش منو
        show_menu()

if __name__ == "__main__":
    main()
