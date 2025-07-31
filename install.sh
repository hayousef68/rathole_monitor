#!/bin/bash
set -e

echo "[+] نصب پیش‌نیازها..."
apt update && apt install -y python3 python3-pip net-tools lsof

echo "[+] نصب پکیج‌های پایتون..."
pip3 install psutil rich

echo "[+] ایجاد پوشه و فایل‌ها..."
mkdir -p /opt/rathole-monitor
cat > /opt/rathole-monitor/config.json <<EOF
{
  "services": [
    {
      "name": "rathole-iran8000.service",
      "port": 8000
    },
    {
      "name": "rathole-kharej9000.service",
      "port": 9000
    }
  ],
  "check_interval": 300
}
EOF

cat > /opt/rathole-monitor/monitor.py <<'EOF'
import subprocess, json, time, socket, os
from datetime import datetime
from rich.console import Console
from rich.table import Table

CONFIG_FILE = "/opt/rathole-monitor/config.json"
LOG_FILE = "/opt/rathole-monitor/log.txt"
console = Console()

def load_config():
    with open(CONFIG_FILE) as f:
        return json.load(f)

def is_port_open(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(2)
        return s.connect_ex(("127.0.0.1", port)) == 0

def restart_service(name):
    subprocess.run(["systemctl", "restart", name])
    with open(LOG_FILE, "a") as f:
        f.write(f"[{datetime.now()}] Restarted: {name}\n")

def check_services():
    config = load_config()
    for svc in config["services"]:
        name = svc["name"]
        port = svc["port"]
        status = subprocess.run(["systemctl", "is-active", name], capture_output=True, text=True).stdout.strip()
        if status != "active" or not is_port_open(port):
            restart_service(name)

def show_status():
    config = load_config()
    table = Table(title="وضعیت تانل‌های Rathole")
    table.add_column("سرویس")
    table.add_column("پورت")
    table.add_column("وضعیت")
    for svc in config["services"]:
        name = svc["name"]
        port = svc["port"]
        active = subprocess.run(["systemctl", "is-active", name], capture_output=True, text=True).stdout.strip()
        port_open = is_port_open(port)
        table.add_row(name, str(port), "✅ فعال" if active == "active" and port_open else "❌ قطع")
    console.print(table)

def show_last_restarts():
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE) as f:
            lines = f.readlines()[-10:]
            console.print("\n[bold yellow]آخرین ریستارت‌ها:[/bold yellow]")
            for line in lines:
                console.print(line.strip())

def main_menu():
    while True:
        console.print("\n[1] بررسی وضعیت سرویس‌ها")
        console.print("[2] مشاهده آخرین ریستارت‌ها")
        console.print("[3] اجرای بررسی دستی")
        console.print("[0] خروج")
        choice = input("انتخاب: ")
        if choice == "1":
            show_status()
        elif choice == "2":
            show_last_restarts()
        elif choice == "3":
            check_services()
            console.print("[green]بررسی انجام شد.[/green]")
        elif choice == "0":
            break

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--check":
        check_services()
    else:
        main_menu()
EOF

echo "[+] ایجاد کران برای اجرای خودکار هر ۵ دقیقه..."
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/bin/python3 /opt/rathole-monitor/monitor.py --check") | crontab -

echo "[+] ایجاد اسکریپت برای اجرای منو..."
cat > /usr/local/bin/rathole-monitor <<'EOF'
#!/bin/bash
python3 /opt/rathole-monitor/monitor.py
EOF
chmod +x /usr/local/bin/rathole-monitor

echo "[✓] نصب کامل شد. برای اجرای منو بنویس: rathole-monitor"
