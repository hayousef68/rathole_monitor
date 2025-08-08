#!/usr/bin/env bash
# اسکریپت نصب خودکار مانیتور تانل‌های Rathole
# Auto Install Script for Rathole Monitor System
# Version: 1.2.0

set -euo pipefail

# رنگ‌ها
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# متغیرها
MONITOR_DIR="/root/rathole-monitor"
SERVICE_NAME_MON="rathole-monitor"
SERVICE_NAME_WEB="rathole-monitor-web"
WEB_PORT="${WEB_PORT:-8080}"

# پیام‌ها
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()     { echo -e "${RED}[ERROR]${NC} $*"; }
title()   { echo -e "${PURPLE}$*${NC}"; }

logo() {
  echo -e "${CYAN}"
  cat << 'EOF'
    ____        __  __          __        __  ___            _ __            
   / __ \____ _/ /_/ /_  ____  / /__     /  |/  /___  ____  (_) /_____  _____
  / /_/ / __ `/ __/ __ \/ __ \/ / _ \   / /|_/ / __ \/ __ \/ / __/ __ \/ ___/
 / _, _/ /_/ / /_/ / / / /_/ / /  __/  / /  / / /_/ / / / / / /_/ /_/ / /    
/_/ |_|\__,_/\__/_/ /_/\____/_/\___/  /_/  /_/\____/_/ /_/_/\__/\____/_/     

   🔧 سیستم مانیتور خودکار تانل‌های Rathole
   🚀 نصب خودکار
EOF
  echo -e "${NC}"
}

# بررسی روت
check_root() {
  if [[ $EUID -ne 0 ]]; then
    err "این اسکریپت باید با مجوز root اجرا شود"
    echo -e "${YELLOW}مثال:${NC} sudo ./install.sh"
    exit 1
  fi
  ok "مجوز root تأیید شد"
}

# بررسی سیستم عامل
check_os() {
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS=$ID
    VER=$VERSION_ID
  else
    err "عدم شناسایی سیستم عامل"
    exit 1
  fi
  if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
    warn "این اسکریپت برای Ubuntu/Debian بهینه است. سیستم فعلی: $OS $VER"
    read -rp "ادامه می‌دهید؟ (y/N): " c
    [[ "${c:-N}" =~ ^[yY]$ ]] || exit 1
  fi
  ok "سیستم عامل: $OS $VER"
}

# آپدیت و وابستگی‌ها
update_system() {
  info "بروزرسانی فهرست پکیج‌ها..."
  export DEBIAN_FRONTEND=noninteractive
  apt update -qq || { err "خطا در بروزرسانی"; exit 1; }
  ok "فهرست پکیج‌ها بروزرسانی شد"
}

install_deps() {
  info "نصب پیش‌نیازها..."
  local pkgs=(python3 python3-pip python3-venv systemd curl wget unzip nano htop net-tools ufw)
  local missing=()
  for p in "${pkgs[@]}"; do
    if ! dpkg -l | grep -q "^ii  $p "; then
      missing+=("$p")
    fi
  done
  if ((${#missing[@]})); then
    info "در حال نصب: ${missing[*]}"
    apt install -y "${missing[@]}" >/dev/null
  fi
  ok "پیش‌نیازها آماده شد"
}

# ساخت پوشه‌ها
make_dirs() {
  info "ایجاد ساختار پوشه‌ها..."
  mkdir -p "$MONITOR_DIR" "$MONITOR_DIR/logs" "$MONITOR_DIR/config" "$MONITOR_DIR/scripts" "$MONITOR_DIR/temp"
  chmod 755 "$MONITOR_DIR" "$MONITOR_DIR/logs" "$MONITOR_DIR/config" "$MONITOR_DIR/scripts" "$MONITOR_DIR/temp"
  ok "پوشه‌ها آماده شدند"
}

# کپی فایل‌ها
copy_files() {
  info "کپی فایل‌ها به $MONITOR_DIR ..."
  local need=("monitor.py" "web_server.py" "web_panel.html")
  for f in "${need[@]}"; do
    if [[ ! -f "./$f" ]]; then
      err "فایل یافت نشد: ./$f — لطفاً این فایل را کنار install.sh قرار دهید"
      exit 1
    fi
  done
  cp -f ./monitor.py "$MONITOR_DIR/monitor.py"
  cp -f ./web_server.py "$MONITOR_DIR/web_server.py"
  cp -f ./web_panel.html "$MONITOR_DIR/web_panel.html"
  chmod +x "$MONITOR_DIR/monitor.py" "$MONITOR_DIR/web_server.py"
  chmod 644 "$MONITOR_DIR/web_panel.html"
  ok "فایل‌ها کپی شدند"
}

# ایجاد config.json اولیه اگر نبود
create_config() {
  if [[ -f "$MONITOR_DIR/config.json" ]]; then
    ok "config.json موجود است"
    return
  fi
  info "ایجاد config.json پیش‌فرض..."
  cat > "$MONITOR_DIR/config.json" << EOF
{
  "tunnels": [],
  "check_interval": 300,
  "web_port": ${WEB_PORT},
  "auto_restart": true,
  "max_restart_attempts": 3,
  "restart_delay": 10,
  "restart_window_seconds": 900,
  "log_level": "INFO",
  "restart_on_inactive": true,
  "journal_since_seconds": 300,
  "notification": {
    "enabled": false,
    "webhook_url": "",
    "telegram_bot_token": "",
    "telegram_chat_id": ""
  }
}
EOF
  chmod 644 "$MONITOR_DIR/config.json"
  ok "config.json ایجاد شد"
}

# سرویس‌ها
create_service_monitor() {
  info "ایجاد سرویس systemd برای مانیتور..."
  cat > "/etc/systemd/system/${SERVICE_NAME_MON}.service" << EOF
[Unit]
Description=Rathole Tunnel Monitor
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${MONITOR_DIR}
ExecStart=/usr/bin/python3 ${MONITOR_DIR}/monitor.py --daemon
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1

# امنیت
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=${MONITOR_DIR} /var/log
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME_MON}" >/dev/null
  ok "سرویس مانیتور آماده شد"
}

create_service_web() {
  info "ایجاد سرویس systemd برای وب‌پنل..."
  cat > "/etc/systemd/system/${SERVICE_NAME_WEB}.service" << EOF
[Unit]
Description=Rathole Monitor Web Panel
After=network.target ${SERVICE_NAME_MON}.service
Wants=${SERVICE_NAME_MON}.service

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=${MONITOR_DIR}
ExecStart=/usr/bin/python3 ${MONITOR_DIR}/web_server.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1

# امنیت
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=${MONITOR_DIR} /var/log
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME_WEB}" >/dev/null
  ok "سرویس وب آماده شد"
}

# فایروال
setup_firewall() {
  if command -v ufw >/dev/null 2>&1; then
    if ufw status 2>/dev/null | grep -q "Status: active"; then
      info "افزودن قانون فایروال برای پورت ${WEB_PORT}..."
      ufw allow "${WEB_PORT}"/tcp comment "Rathole Monitor Web Panel" >/dev/null 2>&1 || true
      ok "قانون فایروال اضافه شد"
    else
      warn "UFW غیرفعال است. اگر نیاز دارید: ufw enable"
    fi
  else
    warn "UFW نصب نیست"
  fi
}

# اسکریپت‌های کمکی
helper_scripts() {
  info "ایجاد اسکریپت‌های کمکی..."
  cat > "$MONITOR_DIR/scripts/start.sh" << 'EOF'
#!/usr/bin/env bash
systemctl start rathole-monitor
systemctl start rathole-monitor-web
systemctl status rathole-monitor --no-pager -l || true
systemctl status rathole-monitor-web --no-pager -l || true
EOF

  cat > "$MONITOR_DIR/scripts/stop.sh" << 'EOF'
#!/usr/bin/env bash
systemctl stop rathole-monitor-web || true
systemctl stop rathole-monitor || true
EOF

  cat > "$MONITOR_DIR/scripts/restart.sh" << 'EOF'
#!/usr/bin/env bash
systemctl restart rathole-monitor
sleep 2
systemctl restart rathole-monitor-web
EOF

  cat > "$MONITOR_DIR/scripts/status.sh" << 'EOF'
#!/usr/bin/env bash
echo "📊 وضعیت سرویس‌ها"
systemctl status rathole-monitor --no-pager -l || true
echo ""
systemctl status rathole-monitor-web --no-pager -l || true
echo ""
echo "📝 لاگ‌های اخیر مانیتور:"
journalctl -u rathole-monitor -n 30 --no-pager || true
EOF

  cat > "$MONITOR_DIR/scripts/logs.sh" << 'EOF'
#!/usr/bin/env bash
echo "📝 نمایش زنده لاگ‌های مانیتور (Ctrl+C برای خروج)"
journalctl -u rathole-monitor -f
EOF

  cat > "$MONITOR_DIR/scripts/web.sh" << 'EOF'
#!/usr/bin/env bash
cd /root/rathole-monitor
python3 web_server.py
EOF

  cat > "$MONITOR_DIR/scripts/menu.sh" << 'EOF'
#!/usr/bin/env bash
cd /root/rathole-monitor
python3 monitor.py
EOF

  chmod +x "$MONITOR_DIR/scripts/"*.sh
  ln -sf "$MONITOR_DIR/scripts/start.sh"   "$MONITOR_DIR/start.sh"
  ln -sf "$MONITOR_DIR/scripts/stop.sh"    "$MONITOR_DIR/stop.sh"
  ln -sf "$MONITOR_DIR/scripts/restart.sh" "$MONITOR_DIR/restart.sh"
  ln -sf "$MONITOR_DIR/scripts/status.sh"  "$MONITOR_DIR/status.sh"
  ln -sf "$MONITOR_DIR/scripts/logs.sh"    "$MONITOR_DIR/logs.sh"
  ln -sf "$MONITOR_DIR/scripts/web.sh"     "$MONITOR_DIR/web.sh"
  ln -sf "$MONITOR_DIR/scripts/menu.sh"    "$MONITOR_DIR/menu.sh"
  ok "اسکریپت‌ها آماده شدند"
}

# تست نصب
test_install() {
  info "تست صحت نصب..."
  local errs=0
  for f in "$MONITOR_DIR/monitor.py" "$MONITOR_DIR/web_server.py" "$MONITOR_DIR/web_panel.html" "$MONITOR_DIR/config.json"; do
    [[ -f "$f" ]] || { err "فایل وجود ندارد: $f"; ((errs++)); }
  done
  python3 -m py_compile "$MONITOR_DIR/monitor.py" 2>/dev/null || { err "سینتکس monitor.py مشکل دارد"; ((errs++)); }
  python3 -m py_compile "$MONITOR_DIR/web_server.py" 2>/dev/null || { err "سینتکس web_server.py مشکل دارد"; ((errs++)); }
  systemctl list-unit-files | grep -q "^${SERVICE_NAME_MON}.service" || { err "سرویس مانیتور ایجاد نشد"; ((errs++)); }
  systemctl list-unit-files | grep -q "^${SERVICE_NAME_WEB}.service" || { err "سرویس وب ایجاد نشد"; ((errs++)); }
  if ((errs==0)); then ok "تست نصب موفق بود"; else err "تست نصب با $errs خطا"; fi
  return $errs
}

# خلاصه نهایی
summary() {
  clear
  title "✅ نصب با موفقیت انجام شد"
  cat << EOF

📁 محل نصب: $MONITOR_DIR
🌐 وب‌پنل:  http://$(hostname -I 2>/dev/null | awk '{print $1}'):${WEB_PORT}
⚙️  تنظیمات: $MONITOR_DIR/config.json
📝 لاگ:     $MONITOR_DIR/monitor.log

دستورات سریع:
  systemctl start  ${SERVICE_NAME_MON} ${SERVICE_NAME_WEB}
  systemctl status ${SERVICE_NAME_MON} ${SERVICE_NAME_WEB}
  journalctl -u ${SERVICE_NAME_MON} -f

EOF
  read -rp "می‌خواهید همین الان سرویس‌ها شروع شوند؟ (Y/n): " s
  if [[ "${s:-Y}" =~ ^[Yy]$ ]]; then
    info "شروع سرویس‌ها..."
    systemctl start "${SERVICE_NAME_MON}" || true
    sleep 2
    systemctl start "${SERVICE_NAME_WEB}" || true
    if systemctl is-active --quiet "${SERVICE_NAME_MON}" && systemctl is-active --quiet "${SERVICE_NAME_WEB}"; then
      ok "سرویس‌ها با موفقیت شروع شدند"
      echo "وب‌پنل: http://$(hostname -I 2>/dev/null | awk '{print $1}'):${WEB_PORT}"
    else
      err "شروع سرویس‌ها با خطا مواجه شد"
      echo "برای بررسی: systemctl status ${SERVICE_NAME_MON} ${SERVICE_NAME_WEB}"
    fi
  fi
}

# گزینه‌ها
while (($#)); do
  case "$1" in
    --web-port)
      shift
      [[ "${1:-}" =~ ^[0-9]+$ ]] || { err "پورت نامعتبر"; exit 1; }
      WEB_PORT="$1"
      ;;
    --force) : ;;
    --help|-h)
      echo "Usage: $0 [--web-port PORT] [--force]"
      exit 0 ;;
    *) err "گزینه نامعتبر: $1"; exit 1 ;;
  esac
  shift || true
done

# اجرا
clear
logo
title "🚀 شروع نصب"
check_root
check_os
update_system
install_deps
make_dirs
copy_files
create_config
create_service_monitor
create_service_web
setup_firewall
helper_scripts
test_install || true
summary
