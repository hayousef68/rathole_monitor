# راهنمای کامل پروژه Rathole Monitor

## 📖 درباره پروژه

**Rathole Monitor** یک ابزار مانیتورینگ قدرتمند و جامع برای تونل‌های Rathole است که شامل داشبورد وب بصری و سیستم مانیتورینگ خودکار می‌باشد. این پروژه برای مدیران سرور و کاربران فنی طراحی شده که نیاز به نظارت مداوم بر وضعیت تونل‌های خود دارند[1][2].




دستور یک خطی برای نصب:
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash


ویژگی‌های کلیدی اسکریپت بهبود یافته:
🚀 نصب خودکار کامل:

نصب تمام پیش‌نیازها (Python, Git, systemd, ابزارهای شبکه)
ایجاد پوشه /root/rathole_monitor
کلون کردن فایل‌ها از GitHub
نصب وابستگی‌های Python در virtual environment

⚙️ مدیریت سرویس:

ایجاد دو سرویس systemd:

rathole-monitor: داشبورد وب
rathole-monitor-script: اسکریپت مانیتورینگ پس‌زمینه


راه‌اندازی خودکار بعد از ریستارت سرور
مدیریت کامل restart و error handling

🔧 دسترسی‌ها و امنیت:

تنظیم صحیح permissions برای تمام فایل‌ها
اجرا با دسترسی root
محافظت از system files
logging مناسب

📊 مدیریت آسان:
ایجاد alias های مفید:

rm-status: وضعیت سرویس‌ها
rm-restart: ریستارت سرویس‌ها
rm-logs: مشاهده لاگ‌ها
rm-monitor: چک کردن وضعیت rathole ها
rm-update: آپدیت از GitHub

🌐 گزینه‌های نصب:
bash# نصب پایه
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash

# نصب روی پورت خاص
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash -s -- -p 8080

# نصب چندین instance همزمان
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash -s -- -m 3

# حذف کامل
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash -s -- -u
اسکریپت بعد از نصب، IP سرور و تمام اطلاعات مورد نیاز را نمایش می‌دهد و شما می‌توانید از طریق مرورگر به






## ✨ ویژگی‌های کلیدی

### 📊 داشبورد وب تعاملی
- نمایش وضعیت real-time تونل‌ها
- مانیتورینگ منابع سیستم (CPU, Memory, Disk)
- اطلاعات شبکه و اتصالات
- لاگ‌های سیستم به‌روزرسانی خودکار
- رابط کاربری زیبا و responsive

### 🔄 مانیتورینگ خودکار
- بررسی مداوم وضعیت سرویس‌ها
- تشخیص هوشمند خطاهای بحرانی
- راه‌اندازی مجدد خودکار سرویس‌های خراب
- آنالیز ال
- پشتیبانی از چندین نمونه همزمان

### ⚙️ مدیریت پیشرفته
- ادغام کامل با systemd
- پشتیبانی از Ubuntu/Debian
- نصب خودکار وابستگی‌ها
- پیکربندی انعطاف‌پذیر
- گزارش‌گیری جامع

## 🏗️ ساختار پروژه

### فایل‌های اصلی
- **`app.py`** - داشبورد وب Flask با API endpoints[1]
- **`rathole_monitor.sh`** - اسکریپت مانیتورینگ و مدیریت سرویس‌ها[2]
- **`run.sh`** - اسکریپت نصب و راه‌اندازی خودکار[3]

### تکنولوژی‌های استفاده شده
- **Backend**: Python 3, Flask, psutil
- **Frontend**: HTML5, CSS3, JavaScript
- **System**: Bash, systemd, journalctl
- **Monitoring**: Real-time APIs, WebSocket-like updates
