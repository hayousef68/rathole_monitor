#!/usr/bin/env python3
"""
Rathole Monitor - Web Dashboard for Rathole Tunnel Status
Enhanced version with systemd service support
"""

import os
import sys
import time
import json
import subprocess
import threading
from datetime import datetime
from flask import Flask, render_template_string, jsonify, request
import psutil
import socket

# Configuration
PORT = int(os.getenv('PORT', 3000))
DEBUG = os.getenv('DEBUG', 'false').lower() == 'true'
MONITOR_LOG_FILE = '/var/log/rathole_monitor.log'

app = Flask(__name__)

# Global variables for monitoring
tunnel_status = {}
system_stats = {}
logs = []
rathole_services = []

# Service patterns to monitor
RATHOLE_SERVICE_PATTERNS = ['rathole-iran*', 'rathole-kharej*']

def add_log(level, message):
    """Add log entry"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = {
        'timestamp': timestamp,
        'level': level,
        'message': message
    }
    logs.append(log_entry)
    
    # Keep only last 1000 logs
    if len(logs) > 1000:
        logs.pop(0)
    
    print(f"[{timestamp}] [{level.upper()}] {message}")

def run_command(command):
    """Run system command and return output"""
    try:
        result = subprocess.run(
            command, 
            shell=True, 
            capture_output=True, 
            text=True, 
            timeout=10
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", "Command timed out", 1
    except Exception as e:
        return "", str(e), 1

def get_rathole_services():
    """Get all rathole services matching our patterns"""
    services = []
    
    try:
        # Get all systemd services
        stdout, stderr, code = run_command(
            "systemctl list-units --type=service --state=loaded --no-legend 2>/dev/null | awk '{print $1}'"
        )
        
        if code == 0:
            all_services = stdout.split('\n')
            for service in all_services:
                service = service.strip()
                if service:
                    # Check if service matches our patterns
                    for pattern in RATHOLE_SERVICE_PATTERNS:
                        pattern_regex = pattern.replace('*', '.*')
                        if service.startswith(pattern.replace('*', '')):
                            services.append(service)
                            break
    except Exception as e:
        add_log('error', f'Failed to get rathole services: {str(e)}')
    
    return services

def get_service_status(service_name):
    """Get detailed status of a service"""
    status_info = {
        'name': service_name,
        'active': False,
        'status': 'unknown',
        'uptime': 'unknown',
        'ports': [],
        'errors': 0,
        'last_restart': 'unknown'
    }
    
    try:
        # Get service status
        stdout, stderr, code = run_command(f"systemctl is-active {service_name}")
        if code == 0 and stdout == 'active':
            status_info['active'] = True
            status_info['status'] = 'active'
        else:
            status_info['status'] = stdout or 'inactive'
        
        # Get uptime
        stdout, stderr, code = run_command(
            f"systemctl show {service_name} --property=ActiveEnterTimestamp --value"
        )
        if code == 0 and stdout:
            status_info['uptime'] = stdout
        
        # Get recent errors count
        stdout, stderr, code = run_command(
            f"journalctl -u {service_name} --since '5 minutes ago' -p warning --no-pager -q | wc -l"
        )
        if code == 0:
            status_info['errors'] = int(stdout) if stdout.isdigit() else 0
        
        # Try to get ports from config (simplified)
        service_base = service_name.replace('.service', '')
        config_paths = [
            f'/etc/rathole/{service_base}.toml',
            f'/opt/rathole/{service_base}.toml'
        ]
        
        for config_path in config_paths:
            if os.path.exists(config_path):
                try:
                    with open(config_path, 'r') as f:
                        content = f.read()
                        # Simple port extraction
                        import re
                        ports = re.findall(r':(\d+)', content)
                        status_info['ports'] = list(set(ports))
                        break
                except:
                    pass
                    
    except Exception as e:
        add_log('error', f'Failed to get status for {service_name}: {str(e)}')
    
    return status_info

def update_tunnel_status():
    """Update tunnel status information"""
    global tunnel_status, rathole_services
    
    try:
        # Get current rathole services
        rathole_services = get_rathole_services()
        
        # Update status for each service
        tunnel_status = {}
        for service in rathole_services:
            status = get_service_status(service)
            tunnel_status[service] = status
            
    except Exception as e:
        add_log('error', f'Failed to update tunnel status: {str(e)}')

def update_system_stats():
    """Update system statistics"""
    global system_stats
    
    try:
        # CPU usage
        cpu_percent = psutil.cpu_percent(interval=1)
        
        # Memory usage
        memory = psutil.virtual_memory()
        
        # Disk usage
        disk = psutil.disk_usage('/')
        
        # Network stats
        network = psutil.net_io_counters()
        
        # Load average
        load_avg = os.getloadavg() if hasattr(os, 'getloadavg') else (0, 0, 0)
        
        system_stats = {
            'cpu_percent': cpu_percent,
            'memory_percent': memory.percent,
            'memory_used': memory.used,
            'memory_total': memory.total,
            'disk_percent': (disk.used / disk.total) * 100,
            'disk_used': disk.used,
            'disk_total': disk.total,
            'network_sent': network.bytes_sent,
            'network_recv': network.bytes_recv,
            'load_avg': load_avg,
            'uptime': time.time() - psutil.boot_time()
        }
        
    except Exception as e:
        add_log('error', f'Failed to update system stats: {str(e)}')

def monitor_rathole():
    """Enhanced rathole monitoring with systemd services"""
    add_log('info', 'Starting enhanced rathole monitor thread')
    
    while True:
        try:
            # Update tunnel status
            update_tunnel_status()
            
            # Update system stats
            update_system_stats()
            
            # Log status
            active_count = sum(1 for status in tunnel_status.values() if status['active'])
            total_count = len(tunnel_status)
            
            add_log('info', f'Monitoring {total_count} rathole services, {active_count} active')
            
            # Check if main monitor service logs exist
            if os.path.exists(MONITOR_LOG_FILE):
                try:
                    # Read recent logs from main monitor
                    with open(MONITOR_LOG_FILE, 'r') as f:
                        lines = f.readlines()
                        recent_lines = lines[-10:] if len(lines) > 10 else lines
                        for line in recent_lines:
                            if 'ERROR' in line or 'WARNING' in line:
                                add_log('info', f'Monitor: {line.strip()}')
                except:
                    pass
            
            time.sleep(30)  # Check every 30 seconds
            
        except Exception as e:
            add_log('error', f'Monitor error: {str(e)}')
            time.sleep(10)

# API Routes (rest of the routes remain similar but with updated data)

@app.route('/api/services')
def api_services():
    """Get all rathole services status"""
    return jsonify({
        'services': tunnel_status,
        'total': len(tunnel_status),
        'active': sum(1 for s in tunnel_status.values() if s['active']),
        'timestamp': datetime.now().isoformat()
    })

@app.route('/api/restart/<service_name>')
def api_restart_service(service_name):
    """Restart a specific service"""
    try:
        stdout, stderr, code = run_command(f"systemctl restart {service_name}")
        if code == 0:
            add_log('info', f'Service {service_name} restarted successfully')
            return jsonify({'success': True, 'message': f'Service {service_name} restarted'})
        else:
            add_log('error', f'Failed to restart {service_name}: {stderr}')
            return jsonify({'success': False, 'message': stderr})
    except Exception as e:
        add_log('error', f'Error restarting {service_name}: {str(e)}')
        return jsonify({'success': False, 'message': str(e)})

# ... (rest of the HTML template and other routes remain similar)

if __name__ == '__main__':
    print(f"🚀 Starting Enhanced Rathole Monitor on port {PORT}")
    add_log('info', f'Enhanced Rathole Monitor starting on port {PORT}')
    
    # Start monitoring thread
    monitor_thread = threading.Thread(target=monitor_rathole, daemon=True)
    monitor_thread.start()
    
    # Start Flask app
    try:
        app.run(host='0.0.0.0', port=PORT, debug=DEBUG, threaded=True)
    except Exception as e:
        add_log('error', f'Failed to start web server: {str(e)}')
        sys.exit(1)
