#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
وب سرور ساده برای پنل مانیتور تانل‌های Rathole
Simple Web Server for Rathole Monitor Panel
"""

import os
import json
import threading
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import logging

class RatholeWebHandler(SimpleHTTPRequestHandler):
    """کلاس مدیریت درخواست‌های وب"""
    
    def __init__(self, *args, monitor=None, **kwargs):
        self.monitor = monitor
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        """مدیریت درخواست‌های GET"""
        parsed_url = urlparse(self.path)
        
        # API endpoints
        if parsed_url.path == '/api/status':
            self.send_json_response(self.get_status())
        elif parsed_url.path == '/':
            # سرو کردن صفحه اصلی
            self.serve_main_page()
        else:
            # فایل‌های استاتیک
            super().do_GET()
    
    def do_POST(self):
        """مدیریت درخواست‌های POST"""
        parsed_url = urlparse(self.path)
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length).decode('utf-8')
        
        try:
            data = json.loads(post_data) if post_data else {}
        except json.JSONDecodeError:
            data = {}
        
        if parsed_url.path == '/api/restart-tunnel':
            response = self.restart_tunnel(data.get('tunnel_name'))
            self.send_json_response(response)
        elif parsed_url.path == '/api/start-monitoring':
            response = self.start_monitoring()
            self.send_json_response(response)
        elif parsed_url.path == '/api/stop-monitoring':
            response = self.stop_monitoring()
            self.send_json_response(response)
        elif parsed_url.path == '/api/update-config':
            response = self.update_config(data)
            self.send_json_response(response)
        else:
            self.send_error(404, "API endpoint not found")
    
    def send_json_response(self, data):
        """ارسال پاسخ JSON"""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
        
        json_data = json.dumps(data, ensure_ascii=False, indent=2)
        self.wfile.write(json_data.encode('utf-8'))
    
    def serve_main_page(self):
        """سرو کردن صفحه اصلی"""
        try:
            html_path = os.path.join(os.path.dirname(__file__), 'web_panel.html')
            with open(html_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(content.encode('utf-8'))
        except FileNotFoundError:
            self.send_error(404, "Web panel file not found")
    
    def get_status(self):
        """دریافت وضعیت سیستم"""
        if self.monitor:
            return self.monitor.get_status()
        else:
            return {
                "error": "Monitor not available",
                "running": False,
                "tunnels": [],
                "uptime": "0"
            }
    
    def get_tunnels(self):
        """دریافت لیست تانل‌ها"""
        if self.monitor:
            return {
                "tunnels": self.monitor.config.get('tunnels', []),
                "last_update": self.monitor.get_uptime()
            }
        else:
            return {"tunnels": [], "error": "Monitor not available"}
    
    def get_logs(self):
        """دریافت لاگ‌ها"""
        try:
            log_file = os.path.join(os.path.dirname(__file__), 'monitor.log')
            if os.path.exists(log_file):
                with open(log_file, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
                    # آخرین 100 خط
                    recent_logs = lines[-100:] if len(lines) > 100 else lines
                    return {
                        "logs": [line.strip() for line in recent_logs],
                        "total_lines": len(lines)
                    }
            else:
                return {"logs": [], "error": "Log file not found"}
        except Exception as e:
            return {"logs": [], "error": str(e)}
    
    def restart_tunnel(self, tunnel_name):
        """ریستارت تانل"""
        if not self.monitor:
            return {"success": False, "error": "Monitor not available"}
        
        if not tunnel_name:
            return {"success": False, "error": "Tunnel name required"}
        
        # پیدا کردن تانل
        tunnel = None
        for t in self.monitor.config.get('tunnels', []):
            if t['name'] == tunnel_name:
                tunnel = t
                break
        
        if not tunnel:
            return {"success": False, "error": "Tunnel not found"}
        
        # ریستارت تانل
        try:
            success = self.monitor.restart_tunnel(tunnel)
            return {
                "success": success,
                "message": f"Tunnel {tunnel_name} restarted successfully" if success else "Failed to restart tunnel"
            }
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def start_monitoring(self):
        """شروع مانیتورینگ"""
        if not self.monitor:
            return {"success": False, "error": "Monitor not available"}
        
        try:
            self.monitor.start_monitoring()
            return {"success": True, "message": "Monitoring started"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def stop_monitoring(self):
        """توقف مانیتورینگ"""
        if not self.monitor:
            return {"success": False, "error": "Monitor not available"}
        
        try:
            self.monitor.stop_monitoring()
            return {"success": True, "message": "Monitoring stopped"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def update_config(self, config_data):
        """بروزرسانی تنظیمات"""
        if not self.monitor:
            return {"success": False, "error": "Monitor not available"}
        
        try:
            # بروزرسانی تنظیمات
            for key, value in config_data.items():
                if key in ['check_interval', 'auto_restart', 'max_restart_attempts', 'restart_delay']:
                    self.monitor.config[key] = value
            
            # ذخیره تنظیمات
            self.monitor.save_config()
            return {"success": True, "message": "Configuration updated"}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def log_message(self, format, *args):
        """حذف لاگ‌های غیرضروری"""
        pass

class RatholeWebServer:
    """کلاس وب سرور"""
    
    def __init__(self, monitor, port=8080):
        self.monitor = monitor
        self.port = port
        self.server = None
        self.thread = None
        self.running = False
        
        # تنظیم لاگر
        self.logger = logging.getLogger(__name__)
    
    def create_handler(self):
        """ایجاد handler با monitor"""
        def handler(*args, **kwargs):
            return RatholeWebHandler(*args, monitor=self.monitor, **kwargs)
        return handler
    
    def start(self):
        """شروع وب سرور"""
        if self.running:
            self.logger.warning("Web server is already running")
            return False
        
        try:
            # ایجاد سرور
            handler = self.create_handler()
            self.server = HTTPServer(('0.0.0.0', self.port), handler)
            
            # تنظیم timeout
            self.server.timeout = 1
            
            # شروع در thread جداگانه
            self.thread = threading.Thread(target=self._serve_forever)
            self.thread.daemon = True
            self.thread.start()
            
            self.running = True
            self.logger.info(f"Web server started on port {self.port}")
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to start web server: {e}")
            return False
    
    def stop(self):
        """توقف وب سرور"""
        if not self.running:
            return
        
        self.running = False
        
        if self.server:
            self.server.shutdown()
            self.server.server_close()
        
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=5)
        
        self.logger.info("Web server stopped")
    
    def _serve_forever(self):
        """اجرای سرور"""
        try:
            while self.running:
                self.server.handle_request()
        except Exception as e:
            self.logger.error(f"Web server error: {e}")
        finally:
            self.running = False

def start_web_server(monitor, port=8080):
    """تابع کمکی برای شروع وب سرور"""
    web_server = RatholeWebServer(monitor, port)
    
    if web_server.start():
        print(f"🌐 وب پنل در آدرس http://localhost:{port} در دسترس است")
        print("برای توقف Ctrl+C بزنید")
        
        try:
            # نگه داشتن سرور زنده
            while web_server.running:
                import time
                time.sleep(1)
        except KeyboardInterrupt:
            print("\nتوقف وب سرور...")
            web_server.stop()
    else:
        print("❌ خطا در شروع وب سرور")

# تست مستقل وب سرور
if __name__ == "__main__":
    import sys
    import argparse
    
    # Mock monitor برای تست
    class MockMonitor:
        def __init__(self):
            self.config = {
                "tunnels": [
                    {
                        "name": "rathole-iran-8080",
                        "type": "iran",
                        "status": "active",
                        "restart_count": 2,
                        "last_restart": "2025-01-31T10:30:00"
                    },
                    {
                        "name": "rathole-kharej-8080", 
                        "type": "kharej",
                        "status": "active",
                        "restart_count": 0,
                        "last_restart": None
                    }
                ],
                "check_interval": 300,
                "auto_restart": True
            }
            self.running = True
        
        def get_status(self):
            return {
                "running": self.running,
                "tunnels": self.config["tunnels"],
                "uptime": "2 hours, 15 minutes"
            }
        
        def get_uptime(self):
            return "2 hours, 15 minutes"
        
        def restart_tunnel(self, tunnel):
            tunnel["restart_count"] += 1
            tunnel["last_restart"] = "2025-01-31T12:00:00"
            return True
        
        def start_monitoring(self):
            self.running = True
        
        def stop_monitoring(self):
            self.running = False
        
        def save_config(self):
            pass
    
    # پارس آرگومان‌ها
    parser = argparse.ArgumentParser(description='Rathole Monitor Web Server')
    parser.add_argument('--port', type=int, default=8080, help='Port to run web server on')
    parser.add_argument('--test', action='store_true', help='Run in test mode with mock data')
    args = parser.parse_args()
    
    # ایجاد monitor
    if args.test:
        monitor = MockMonitor()
    else:
        # اینجا باید RatholeMonitor واقعی import شود
        try:
            from monitor import RatholeMonitor
            monitor = RatholeMonitor()
        except ImportError:
            print("❌ فایل monitor.py یافت نشد، استفاده از حالت تست")
            monitor = MockMonitor()
    
    # شروع وب سرور
    start_web_server(monitor, args.port)path == '/api/tunnels':
            self.send_json_response(self.get_tunnels())
        elif parsed_url.path == '/api/logs':
            self.send_json_response(self.get_logs())
        elif parsed_url.
