# راهنمای کامل پروژه Rathole Monitor

## 📖 درباره پروژه

**Rathole Monitor** یک ابزار مانیتورینگ قدرتمند و جامع برای تونل‌های Rathole است که شامل داشبورد وب بصری و سیستم مانیتورینگ خودکار می‌باشد. این پروژه برای مدیران سرور و کاربران فنی طراحی شده که نیاز به نظارت مداوم بر وضعیت تونل‌های خود دارند[1][2].

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

## 🚀 روش‌های نصب

### 1️⃣ نصب سریع (یک دستوری)


curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash
### 2️⃣ نصب دستی


# نصب پایه
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash

# نصب روی پورت خاص
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash -s -- -p 8080

# نصب چندین instance همزمان
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash -s -- -m 3

# حذف کامل
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash -s -- -u


## 🔄 مدیریت سرویس systemd

### نصب سرویس
```bash
# برای داشبورد وب
sudo ./run.sh -s

# برای مانیتورینگ خودکار
sudo ./rathole_monitor.sh install
```

### کنترل سرویس
```bash
# شروع/توقف/راه‌اندازی مجدد
sudo systemctl start rathole-monitor
sudo systemctl stop rathole-monitor
sudo systemctl restart rathole-monitor

# فعال‌سازی خودکار در بوت
sudo systemctl enable rathole-monitor

# بررسی وضعیت
sudo systemctl status rathole-monitor
```

## 🚨 عیب‌یابی

### مشکلات رایج و راه‌حل‌ها

#### 1. خطای وابستگی‌های Python
```bash
# نصب مجدد وابستگی‌ها
sudo apt install -y python3-flask python3-psutil python3-requests

# یا استفاده از pip
pip3 install flask psutil requests --break-system-packages
```

#### 2. مشکل دسترسی به پورت
```bash
# بررسی پورت‌های باز
sudo netstat -tlnp | grep :3000
sudo ss -tlnp | grep :3000

# بررسی فایروال
sudo ufw status
sudo iptables -L
```

#### 3. سرویس راه‌اندازی نمی‌شود
```bash
# بررسی لاگ‌های خطا
journalctl -u rathole-monitor --no-pager

# بررسی فایل سرویس
sudo systemctl cat rathole-monitor

# تست دستی
cd /tmp/rathole_monitor && python3 app.py
```

#### 4. مشکل تشخیص سرویس‌های rathole
```bash
# لیست همه سرویس‌ها
systemctl list-units --type=service | grep rathole

# بررسی مسیر فایل‌های تنظیم
ls -la /etc/rathole/
ls -la /etc/systemd/system/rathole*
```

## 📋 مثال‌های کاربردی

### نصب کامل با systemd
```bash
# نصب پروژه
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash -s -- -s

# شروع مانیتورینگ خودکار
sudo ./rathole_monitor.sh install

# بررسی وضعیت
./rathole_monitor.sh status
```

### اجرای چندین نمونه
```bash
# راه‌اندازی 5 نمونه روی پورت‌های 3000-3004
./run.sh -m 5

# بررسی پروسس‌ها
ps aux | grep "python3.*app.py"
```

### مانیتورینگ دستی
```bash
# یک بار بررسی
./rathole_monitor.sh monitor

# مانیتورینگ مداوم
./rathole_monitor.sh daemon
```

## 🔒 امنیت و بهترین شیوه‌ها

### توصیه‌های امنیتی
1. **فایروال**: محدود کردن دسترسی به پورت داشبورد
2. **کاربر غیر root**: اجرای سرویس‌ها با کاربر محدود
3. **HTTPS**: استفاده از reverse proxy با SSL
4. **آپدیت منظم**: به‌روزرسانی وابستگی‌ها

### تنظیمات فایروال
```bash
# اجازه دسترسی به پورت خاص
sudo ufw allow 3000/tcp

# محدود کردن به IP خاص
sudo ufw allow from YOUR_IP to any port 3000
```

## 🤝 مشارکت و توسعه

### ساختار کد
- **Python**: کد backend در `app.py` با استانداردهای PEP8
- **Bash**: اسکریپت‌های shell در `rathole_monitor.sh` و `run.sh`
- **HTML/CSS/JS**: رابط کاربری در template های Flask

### راه‌اندازی محیط توسعه
```bash
git clone https://github.com/hayousef68/rathole_monitor.git
cd rathole_monitor
python3 -m venv venv
source venv/bin/activate
pip install flask psutil requests
python3 app.py
```

## 📞 پشتیبانی

### مسائل رایج
- بررسی لاگ‌ها در `/var/log/rathole_monitor.log`
- استفاده از `./rathole_monitor.sh status` برای تشخیص مشکلات
- مراجعه به بخش عیب‌یابی این راهنما

### گزارش مشکلات
مشکلات و پیشنهادات خود را در GitHub Issues پروژه مطرح کنید.

این راهنمای جامع تمامی جنبه‌های نصب، پیکربندی، استفاده و عیب‌یابی پروژه Rathole Monitor را پوشش می‌دهد. برای سوالات بیشتر یا راهنمایی تخصصی، با مستندات GitHub پروژه مراجعه کنید.

[1] https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/75305267/72882432-aa5b-481d-8606-6faf0721a324/app.py
[2] https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/75305267/76b96c53-6a00-4093-b4ff-95d680ecdc88/rathole_monitor.sh
[3] https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/75305267/908b5185-6c79-4529-96cd-fc350bdc0901/run.sh
[4] https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/75305267/50f4f613-d9cd-4863-a46a-f976fd45b6c3/README.md
