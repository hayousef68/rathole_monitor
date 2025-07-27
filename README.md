# rathole_monitor


✨ ویژگی‌های کلیدی
📊 داشبورد وب تعاملی
نمایش وضعیت real-time تونل‌ها

مانیتورینگ منابع سیستم (CPU, Memory, Disk)

اطلاعات شبکه و اتصالات

لاگ‌های سیستم به‌روزرسانی خودکار

رابط کاربری زیبا و responsive

🔄 مانیتورینگ خودکار
بررسی مداوم وضعیت سرویس‌ها

تشخیص هوشمند خطاهای بحرانی

راه‌اندازی مجدد خودکار سرویس‌های خراب

آنالیز ال

پشتیبانی از چندین نمونه همزمان

⚙️ مدیریت پیشرفته
ادغام کامل با systemd

پشتیبانی از Ubuntu/Debian

نصب خودکار وابستگی‌ها

پیکربندی انعطاف‌پذیر

گزارش‌گیری جامع

🏗️ ساختار پروژه
فایل‌های اصلی
app.py - داشبورد وب Flask با API endpoints

rathole_monitor.sh - اسکریپت مانیتورینگ و مدیریت سرویس‌ها

run.sh - اسکریپت نصب و راه‌اندازی خودکار

تکنولوژی‌های استفاده شده
Backend: Python 3, Flask, psutil

Frontend: HTML5, CSS3, JavaScript

System: Bash, systemd, journalctl

Monitoring: Real-time APIs, WebSocket-like updates

🚀 روش‌های نصب
1️⃣ نصب سریع (یک دستوری)
bash
# نصب پایه
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash

# نصب با پورت سفارشی
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash -s -- -p 8080

# نصب چندین نمونه همزمان
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash -s -- -m 3
2️⃣ نصب دستی
bash
# کلون کردن مخزن
git clone https://github.com/hayousef68/rathole_monitor.git
cd rathole_monitor

# نصب وابستگی‌های سیستم
sudo apt update
sudo apt install -y python3 python3-pip python3-venv git

# نصب پکیج‌های Python
sudo apt install -y python3-flask python3-psutil python3-requests

# اجرای برنامه
python3 app.py
🎮 دستورات کاربردی
اسکریپت run.sh
گزینه	توضیح	مثال
-p, --port	تنظیم شماره پورت	./run.sh -p 8080
-m, --multiple	اجرای چندین نمونه	./run.sh -m 3
-s, --service	ایجاد سرویس systemd	./run.sh -s
-k, --kill	متوقف کردن پروسس‌ها	./run.sh -k
-h, --help	نمایش راهنما	./run.sh -h
اسکریپت rathole_monitor.sh
bash
# مانیتورینگ یکباره
./rathole_monitor.sh monitor

# اجرای مداوم (daemon)
./rathole_monitor.sh daemon

# نمایش وضعیت سرویس‌ها
./rathole_monitor.sh status

# نصب به عنوان سرویس systemd
sudo ./rathole_monitor.sh install

# حذف سرویس
sudo ./rathole_monitor.sh uninstall
📊 داشبورد وب
دسترسی
پس از راه‌اندازی، داشبورد در آدرس زیر قابل دسترسی است:

text
http://YOUR_SERVER_IP:3000
بخش‌های داشبورد
وضعیت تونل: نمایش وضعیت آنلاین/آفلاین، uptime، پورت‌ها

منابع سیستم: CPU, Memory, Disk usage با نمودارهای تعاملی

اطلاعات شبکه: IP سرور، پورت‌های فعال، پروتکل

لاگ‌های سیستم: نمایش real-time لاگ‌ها با فیلتر سطح

API Endpoints
GET / - صفحه اصلی داشبورد

GET /api/stats - آمار سیستم (JSON)

GET /api/logs - لاگ‌های اخیر (JSON)

GET /api/health - وضعیت سلامت سرویس

🔧 پیکربندی پیشرفته
متغیرهای محیطی
داشبورد وب
bash
export PORT=8080          # پورت وب سرور
export DEBUG=true         # حالت دیباگ
اسکریپت مانیتورینگ
bash
export LOG_FILE="/custom/path/rathole_monitor.log"
export CHECK_INTERVAL=600                           # فاصله بررسی (ثانیه)
export MAX_RETRIES=3                               # حداکثر تلاش مجدد
export ENABLE_SMART_ERROR_DETECTION=true          # تشخیص هوشمند خطا
پیکربندی rathole_monitor.sh
تنظیم	مقدار پیش‌فرض	توضیح
CHECK_INTERVAL	300	فاصله بررسی (ثانیه)
MAX_RETRIES	3	حداکثر تلاش برای راه‌اندازی
RETRY_DELAY	10	تاخیر بین تلاش‌ها (ثانیه)
MIN_CRITICAL_ERRORS	1	حداقل خطای بحرانی برای restart
RATHOLE_CONFIG_DIR	/etc/rathole	مسیر فایل‌های تنظیم
🛡️ تشخیص خطاهای هوشمند
خطاهای نادیده گرفته شده
مشکلات اتصال موقت (Connection refused, timeout)

خطاهای شبکه عادی (Network unreachable)

قطع اتصالات طبیعی (Connection closed by peer)

خطاهای بحرانی
خطاهای سیستمی (panic, fatal, segmentation fault)

مشکلات پیکربندی (config error, bind failed)

خطاهای منابع (out of memory, permission denied)

خرابی فرآیند (process exited, service failed)

📈 مانیتورینگ و لاگ‌ها
مسیرهای مهم
مسیر	توضیح
/var/log/rathole_monitor.log	لاگ اصلی
/tmp/rathole_monitor/	پوشه پروژه
/etc/systemd/system/rathole-monitor.service	فایل سرویس
/etc/rathole/	پیکربندی rathole
دستورات مفید
bash
# مشاهده لاگ‌ها
tail -f /var/log/rathole_monitor.log

# بررسی وضعیت سرویس
systemctl status rathole-monitor

# مشاهده لاگ‌های systemd
journalctl -u rathole-monitor -f

# بررسی پروسس‌های فعال
ps aux | grep python3
ps aux | grep rathole
🔄 مدیریت سرویس systemd
نصب سرویس
bash
# برای داشبورد وب
sudo ./run.sh -s

# برای مانیتورینگ خودکار
sudo ./rathole_monitor.sh install
کنترل سرویس
bash
# شروع/توقف/راه‌اندازی مجدد
sudo systemctl start rathole-monitor
sudo systemctl stop rathole-monitor
sudo systemctl restart rathole-monitor

# فعال‌سازی خودکار در بوت
sudo systemctl enable rathole-monitor

# بررسی وضعیت
sudo systemctl status rathole-monitor
🚨 عیب‌یابی
مشکلات رایج و راه‌حل‌ها
1. خطای وابستگی‌های Python
bash
# نصب مجدد وابستگی‌ها
sudo apt install -y python3-flask python3-psutil python3-requests

# یا استفاده از pip
pip3 install flask psutil requests --break-system-packages
2. مشکل دسترسی به پورت
bash
# بررسی پورت‌های باز
sudo netstat -tlnp | grep :3000
sudo ss -tlnp | grep :3000

# بررسی فایروال
sudo ufw status
sudo iptables -L
3. سرویس راه‌اندازی نمی‌شود
bash
# بررسی لاگ‌های خطا
journalctl -u rathole-monitor --no-pager

# بررسی فایل سرویس
sudo systemctl cat rathole-monitor

# تست دستی
cd /tmp/rathole_monitor && python3 app.py
4. مشکل تشخیص سرویس‌های rathole
bash
# لیست همه سرویس‌ها
systemctl list-units --type=service | grep rathole

# بررسی مسیر فایل‌های تنظیم
ls -la /etc/rathole/
ls -la /etc/systemd/system/rathole*
📋 مثال‌های کاربردی
نصب کامل با systemd
bash
# نصب پروژه
curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash -s -- -s

# شروع مانیتورینگ خودکار
sudo ./rathole_monitor.sh install

# بررسی وضعیت
./rathole_monitor.sh status
اجرای چندین نمونه
bash
# راه‌اندازی 5 نمونه روی پورت‌های 3000-3004
./run.sh -m 5

# بررسی پروسس‌ها
ps aux | grep "python3.*app.py"
مانیتورینگ دستی
bash
# یک بار بررسی
./rathole_monitor.sh monitor

# مانیتورینگ مداوم
./rathole_monitor.sh daemon
🔒 امنیت و بهترین شیوه‌ها
توصیه‌های امنیتی
فایروال: محدود کردن دسترسی به پورت داشبورد

کاربر غیر root: اجرای سرویس‌ها با کاربر محدود

HTTPS: استفاده از reverse proxy با SSL

آپدیت منظم: به‌روزرسانی وابستگی‌ها

تنظیمات فایروال
bash
# اجازه دسترسی به پورت خاص
sudo ufw allow 3000/tcp

# محدود کردن به IP خاص
sudo ufw allow from YOUR_IP to any port 3000
🤝 مشارکت و توسعه
ساختار کد
Python: کد backend در app.py با استانداردهای PEP8

Bash: اسکریپت‌های shell در rathole_monitor.sh و run.sh

HTML/CSS/JS: رابط کاربری در template های Flask

راه‌اندازی محیط توسعه
bash
git clone https://github.com/hayousef68/rathole_monitor.git
cd rathole_monitor
python3 -m venv venv
source venv/bin/activate
pip install flask psutil requests
python3 app.py
📞 پشتیبانی
مسائل رایج
بررسی لاگ‌ها در /var/log/rathole_monitor.log

استفاده از ./rathole_monitor.sh status برای تشخیص مشکلات

مراجعه به بخش عیب‌یابی این راهنما

گزارش مشکلات
مشکلات و پیشنهادات خود را در GitHub Issues پروژه مطرح کنید.

این راهنمای جامع تمامی جنبه‌های نصب، پیکربندی، استفاده و عیب‌یابی پروژه Rathole Monitor را پوشش می‌دهد. برای سوالات بیشتر یا راهنمایی تخصصی، با مستندات GitHub پروژه مراجعه کنید.




