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
        elif parsed_url.path == '/api/tunnels':
            self.send_json_response(self.get_tunnels())
        elif parsed_url.path == '/api/logs':
            self.send_json_response(self.get_logs())
        elif parsed_url.
