# 🔧 مانیتور خودکار تانل‌های Rathole

سیستم کامل نظارت و مدیریت خودکار تانل‌های Rathole با قابلیت ریستارت خودکار، وب پنل مدیریت و لاگ‌گیری پیشرفته.

## ✨ ویژگی‌ها

- 🔍 **شناسایی خودکار** تانل‌های Rathole موجود در سیستم
- 🔄 **ریستارت خودکار** تانل‌ها در صورت بروز خطا یا قطعی
- 📊 **وب پنل مدیریت** با رابط کاربری فارسی و زیبا
- 📝 **لاگ‌گیری پیشرفته** با سطوح مختلف خطا
- ⚙️ **تنظیمات قابل شخصی‌سازی** برای هر نوع استفاده
- 🔧 **منوی تعاملی** برای مدیریت آسان از خط فرمان
- 🛡️ **سرویس systemd** برای اجرای پایدار
- 📈 **آمار و گزارش‌گیری** از عملکرد تانل‌ها

## 📋 پیش‌نیازها

- سیستم عامل: Ubuntu 18.04+ یا Debian 10+
- Python 3.6 یا بالاتر
- مجوز root برای مدیریت سرویس‌ها
- تانل‌های Rathole نصب شده و فعال

## 🚀 نصب سریع

### نصب با یک دستور:

```bash
wget -O install.sh https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

### نصب دستی:

1. **دانلود فایل‌ها:**
```bash
git clone https://github.com/hayousef68/rathole-monitor.git
cd rathole-monitor
```

2. **اجرای اسکریپت نصب:**
```bash
sudo chmod +x install.sh
sudo ./install.sh
```

3. **شروع سرویس:**
```bash
sudo systemctl start rathole-monitor
sudo systemctl enable rathole-monitor
```

## 📖 راهنمای استفاده

### منوی تعاملی

برای دسترسی به منوی کامل مدیریت:

```bash
cd /root/rathole-monitor
python3 monitor.py
```

منوی اصلی شامل گزینه‌های زیر است:
- نمایش وضعیت تانل‌ها
- شروع/توقف مانیتورینگ
- ریستارت دستی تانل‌ها
- تنظیمات سیستم
- مشاهده لاگ‌ها
- مدیریت سرویس

### وب پنل مدیریت

وب پنل بر روی پورت 8080 در دسترس است:

```
http://YOUR_SERVER_IP:8080
```

**امکانات وب پنل:**
- داشبورد کامل وضعیت تانل‌ها
- ریستارت تک‌کلیکی تانل‌ها
- نمایش آمار و گزارش‌ها
- تنظیمات سیستم
- نمایش لاگ‌های زنده

### دستورات سریع

```bash
# نمایش وضعیت
sudo systemctl status rathole-monitor

# مشاهده لاگ‌های زنده
sudo journalctl -u rathole-monitor -f

# ریستارت سرویس
sudo systemctl restart rathole-monitor

# توقف سرویس
sudo systemctl stop rathole-monitor
```

### اسکریپت‌های کمکی

```bash
# شروع سریع
/root/rathole-monitor/start.sh

# توقف سریع
/root/rathole-monitor/stop.sh

# نمایش وضعیت
/root/rathole-monitor/status.sh

# نمایش لاگ‌ها
/root/rathole-monitor/logs.sh
```

## ⚙️ تنظیمات

فایل تنظیمات در مسیر `/root/rathole-monitor/config.json` قرار دارد:

```json
{
  "tunnels": [],
  "check_interval": 300,
  "web_port": 8080,
  "auto_restart": true,
  "max_restart_attempts": 3,
  "restart_delay": 10,
  "log_level": "INFO"
}
```

### توضیح تنظیمات:

- **check_interval**: فاصله بین هر بررسی (ثانیه) - پیش‌فرض: 300 (5 دقیقه)
- **web_port**: پورت وب پنل - پیش‌فرض: 8080
- **auto_restart**: ریستارت خودکار - پیش‌فرض: true
- **max_restart_attempts**: حداکثر تعداد تلاش ریستارت - پیش‌فرض: 3
- **restart_delay**: تأخیر بین توقف و شروع مجدد (ثانیه) - پیش‌فرض: 10

## 🔍 نحوه کار سیستم

### شناسایی تانل‌ها

سیستم به صورت خودکار تانل‌های Rathole را از طریق:
- جستجو در سرویس‌های systemd
- تشخیص نام‌های سرویس حاوی "rathole"
- استخراج نوع تانل (iran/kharej) از نام سرویس

### تشخیص خطا

سیستم خطاهای زیر را تشخیص و رفع می‌کند:
- **connection refused**: رد شدن اتصال
- **connection timeout**: تایم‌اوت اتصال
- **connection reset**: ریست شدن اتصال
- **broken pipe**: قطع شدن پایپ ارتباطی
- **network unreachable**: عدم دسترسی به شبکه
- **failed to connect**: شکست در اتصال

### الگوریتم ریستارت

1. تشخیص خطا در لاگ یا وضعیت سرویس
2. بررسی تعداد ریستارت‌های قبلی
3. توقف سرویس با grace period
4. انتظار برای تخلیه منابع
5. شروع مجدد سرویس
6. بررسی موفقیت ریستارت
7. ثبت در لاگ و آمار

## 📊 مانیتورینگ و لاگ‌ها

### انواع لاگ‌ها:

- **INFO**: اطلاعات عمومی (شروع، توقف، بررسی‌ها)
- **WARNING**: هشدارها (خطاهای قابل رفع)
- **ERROR**: خطاهای جدی (شکست در ریستارت)

### مکان لاگ‌ها:

- لاگ سیستم: `/root/rathole-monitor/monitor.log`
- لاگ systemd: `journalctl -u rathole-monitor`
- لاگ تانل‌ها: `journalctl -u rathole-service-name`

## 🛠️ عیب‌یابی

### مشکلات رایج:

**1. سرویس شروع نمی‌شود:**
```bash
# بررسی وضعیت
sudo systemctl status rathole-monitor

# بررسی لاگ خطاها
sudo journalctl -u rathole-monitor -n 50
```

**2. تانل‌ها شناسایی نمی‌شوند:**
```bash
# بررسی سرویس‌های rathole
sudo systemctl list-units | grep rathole

# اجرای تست شناسایی
cd /root/rathole-monitor
python3 -c "from monitor import RatholeMonitor; m=RatholeMonitor(); print(m.discover_tunnels())"
```

**3. وب پنل در دسترس نیست:**
```bash
# بررسی پورت
sudo netstat -tlnp | grep 8080

# بررسی فایروال
sudo ufw status | grep 8080
```

**4. خطای مجوز:**
```bash
# تنظیم مجوزها
sudo chmod +x /root/rathole-monitor/monitor.py
sudo chown -R root:root /root/rathole-monitor
```

### لاگ‌های عیب‌یابی:

```bash
# فعال‌سازی حالت debug
echo '{"log_level": "DEBUG"}' | sudo tee -a /root/rathole-monitor/config.json

# مشاهده لاگ‌های تفصیلی
sudo journalctl -u rathole-monitor -f --output=verbose
```

## 🔧 سفارشی‌سازی

### اضافه کردن تانل‌های دستی:

```json
{
  "tunnels": [
    {
      "name": "my-custom-tunnel",
      "type": "iran",
      "config_path": "/path/to/config.toml",
      "ports": [8080, 8443]
    }
  ]
}
```

### تنظیم اعلان‌ها:

```json
{
  "notification": {
    "enabled": true,
    "webhook_url": "https://hooks.slack.com/...",
    "telegram_bot_token": "BOT_TOKEN",
    "telegram_chat_id": "CHAT_ID"
  }
}
```

## 📁 ساختار فایل‌ها

```
/root/rathole-monitor/
├── monitor.py          # اسکریپت اصلی
├── web_server.py       # وب سرور
├── web_panel.html      # رابط وب
├── config.json         # تنظیمات
├── monitor.log         # لاگ‌ها
├── start.sh           # اسکریپت شروع
├── stop.sh            # اسکریپت توقف
├── status.sh          # نمایش وضعیت
├── logs.sh            # نمایش لاگ‌ها
└── uninstall.sh       # حذف کامل
```

## 🔄 بروزرسانی

```bash
# دانلود نسخه جدید
cd /root/rathole-monitor
wget -O monitor_new.py https://raw.githubusercontent.com/your-repo/rathole-monitor/main/monitor.py

# بک‌آپ از تنظیمات
cp config.json config.json.backup

# اعمال بروزرسانی
mv monitor_new.py monitor.py
chmod +x monitor.py

# ریستارت سرویس
sudo systemctl restart rathole-monitor
```

## 🗑️ حذف کامل

```bash
# اجرای اسکریپت حذف
/root/rathole-monitor/uninstall.sh

# یا حذف دستی
sudo systemctl stop rathole-monitor
sudo systemctl disable rathole-monitor
sudo rm /etc/systemd/system/rathole-monitor.service
sudo systemctl daemon-reload
sudo rm -rf /root/rathole-monitor
```


--------------------------------------------------------------------------------------------------------------------------------------------------

⚡ نصب سریع (تک‌خطی)

sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/install.sh)"


