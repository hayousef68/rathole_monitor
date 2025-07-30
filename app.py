#!/usr/bin/env python3
"""
Rathole Monitor - Web Dashboard for Rathole Tunnel Status
Enhanced version with better integration with rathole_monitor.sh
"""

import os
import sys
import time
import json
import subprocess
import threading
import re
from datetime import datetime, timedelta
from flask import Flask, render_template_string, jsonify, request
import psutil
import socket

# Configuration
PORT = int(os.getenv('PORT', 3000))
DEBUG = os.getenv('DEBUG', 'false').lower() == 'true'
RATHOLE_MONITOR_SCRIPT = os.getenv('RATHOLE_MONITOR_SCRIPT', '/root/rathole_monitor/rathole_monitor.sh')
LOG_FILE = "/var/log/rathole_monitor.log"

app = Flask(__name__)

# Global variables for monitoring
tunnel_status = {}
system_stats = {}
logs = []
rathole_services = []

# HTML Template (enhanced)
HTML_TEMPLATE = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rathole Monitor Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            min-height: 100vh;
        }
        .container { 
            max-width: 1400px; 
            margin: 0 auto; 
            padding: 20px;
        }
        .header {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            text-align: center;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .header h1 {
            color: white;
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .header p {
            color: rgba(255,255,255,0.8);
            font-size: 1.2em;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .card {
            background: rgba(255,255,255,0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            border: 1px solid rgba(255,255,255,0.2);
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        .card h3 {
            color: white;
            margin-bottom: 15px;
            font-size: 1.3em;
        }
        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .service-card {
            background: rgba(255,255,255,0.05);
            border-radius: 10px;
            padding: 15px;
            border: 1px solid rgba(255,255,255,0.1);
        }
        .service-name {
            color: white;
            font-weight: bold;
            font-size: 1.1em;
            margin-bottom: 8px;
        }
        .service-status {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 5px;
        }
        .status-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 10px 0;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }
        .status-item:last-child {
            border-bottom: none;
        }
        .status-label {
            color: rgba(255,255,255,0.9);
            font-weight: 500;
        }
        .status-value {
            color: white;
            font-weight: bold;
        }
        .status-online {
            color: #4CAF50;
        }
        .status-offline {
            color: #f44336;
        }
        .status-warning {
            color: #FF9800;
        }
        .log-container {
            background: rgba(0,0,0,0.2);
            border-radius: 10px;
            padding: 15px;
            max-height: 400px;
            overflow-y: auto;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
        }
        .log-entry {
            color: rgba(255,255,255,0.8);
            margin-bottom: 5px;
            padding: 2px 0;
        }
        .log-timestamp {
            color: #81C784;
            font-weight: bold;
        }
        .log-level-info {
            color: #64B5F6;
        }
        .log-level-warning {
            color: #FFB74D;
        }
        .log-level-error {
            color: #E57373;
        }
        .control-buttons {
            display: flex;
            gap: 10px;
            margin-top: 15px;
            flex-wrap: wrap;
        }
        .btn {
            background: rgba(255,255,255,0.2);
            border: none;
            color: white;
            padding: 10px 20px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 1em;
            transition: all 0.3s ease;
        }
        .btn:hover {
            background: rgba(255,255,255,0.3);
            transform: translateY(-2px);
        }
        .btn-success {
            background: rgba(76,175,80,0.6);
        }
        .btn-warning {
            background: rgba(255,152,0,0.6);
        }
        .btn-danger {
            background: rgba(244,67,54,0.6);
        }
        .metric-bar {
            width: 100%;
            height: 20px;
            background: rgba(255,255,255,0.1);
            border-radius: 10px;
            overflow: hidden;
            margin-top: 5px;
        }
        .metric-fill {
            height: 100%;
            background: linear-gradient(90deg, #4CAF50, #81C784);
            transition: width 0.3s ease;
        }
        .metric-fill.warning {
            background: linear-gradient(90deg, #FF9800, #FFB74D);
        }
        .metric-fill.danger {
            background: linear-gradient(90deg, #f44336, #E57373);
        }
        .alert {
            background: rgba(244,67,54,0.2);
            border: 1px solid rgba(244,67,54,0.5);
            border-radius: 8px;
            padding: 10px;
            margin-bottom: 15px;
            color: white;
        }
        .alert-warning {
            background: rgba(255,152,0,0.2);
            border-color: rgba(255,152,0,0.5);
        }
        .alert-success {
            background: rgba(76,175,80,0.2);
            border-color: rgba(76,175,80,0.5);
        }
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.7; }
            100% { opacity: 1; }
        }
        .pulse {
            animation: pulse 2s infinite;
        }
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid rgba(255,255,255,0.3);
            border-radius: 50%;
            border-top-color: white;
            animation: spin 1s ease-in-out infinite;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚇 Rathole Monitor Dashboard</h1>
            <p>Real-time tunnel status and system monitoring</p>
        </div>
        
        <div id="alerts-container"></div>
        
        <div class="stats-grid">
            <div class="card">
                <h3>🔌 System Status</h3>
                <div id="system-status">
                    <div class="status-item">
                        <span class="status-label">Monitor Status:</span>
                        <span class="status-value status-online pulse" id="monitor-status">● Online</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Uptime:</span>
                        <span class="status-value" id="uptime">--</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Dashboard Port:</span>
                        <span class="status-value">{{ port }}</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Total Services:</span>
                        <span class="status-value" id="total-services">--</span>
                    </div>
                </div>
                <div class="control-buttons">
                    <button class="btn btn-success" onclick="runMonitorCheck()">🔍 Check Services</button>
                    <button class="btn btn-warning" onclick="restartAllServices()">🔄 Restart All</button>
                </div>
            </div>
            
            <div class="card">
                <h3>💾 System Resources</h3>
                <div id="system-stats">
                    <div class="status-item">
                        <span class="status-label">CPU Usage:</span>
                        <span class="status-value" id="cpu-usage">--</span>
                    </div>
                    <div class="metric-bar">
                        <div class="metric-fill" id="cpu-bar"></div>
                    </div>
                    
                    <div class="status-item">
                        <span class="status-label">Memory Usage:</span>
                        <span class="status-value" id="memory-usage">--</span>
                    </div>
                    <div class="metric-bar">
                        <div class="metric-fill" id="memory-bar"></div>
                    </div>
                    
                    <div class="status-item">
                        <span class="status-label">Disk Usage:</span>
                        <span class="status-value" id="disk-usage">--</span>
                    </div>
                    <div class="metric-bar">
                        <div class="metric-fill" id="disk-bar"></div>
                    </div>
                </div>
            </div>
            
            <div class="card">
                <h3>🌐 Network Info</h3>
                <div id="network-info">
                    <div class="status-item">
                        <span class="status-label">Server IP:</span>
                        <span class="status-value" id="server-ip">--</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Active Connections:</span>
                        <span class="status-value" id="active-connections">--</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Protocol:</span>
                        <span class="status-value">HTTP/TCP</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Last Update:</span>
                        <span class="status-value" id="last-update">--</span>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h3>🚇 Rathole Services</h3>
            <div id="services-container" class="services-grid">
                <!-- Services will be populated here -->
            </div>
            <div class="control-buttons">
                <button class="btn btn-success" onclick="refreshServices()">🔄 Refresh Services</button>
                <button class="btn btn-warning" onclick="showServiceStatus()">📊 Show Status</button>
            </div>
        </div>
        
        <div class="card">
            <h3>📋 System Logs</h3>
            <div class="log-container" id="log-container">
                <!-- Logs will be populated here -->
            </div>
            <div class="control-buttons">
                <button class="btn" onclick="refreshLogs()">🔄 Refresh Logs</button>
                <button class="btn" onclick="clearLogs()">🗑️ Clear Logs</button>
                <button class="btn" onclick="downloadLogs()">💾 Download Logs</button>
            </div>
        </div>
    </div>

    <script>
        let startTime = Date.now();
        let isLoading = false;
        
        function showAlert(message, type = 'info') {
            const alertsContainer = document.getElementById('alerts-container');
            const alert = document.createElement('div');
            alert.className = `alert alert-${type}`;
            alert.innerHTML = `${message} <button onclick="this.parentElement.remove()" style="float: right; background: none; border: none; color: white; cursor: pointer;">×</button>`;
            alertsContainer.appendChild(alert);
            
            // Auto remove after 5 seconds
            setTimeout(() => {
                if (alert.parentElement) {
                    alert.remove();
                }
            }, 5000);
        }
        
        function updateUptime() {
            const now = Date.now();
            const uptime = Math.floor((now - startTime) / 1000);
            const days = Math.floor(uptime / 86400);
            const hours = Math.floor((uptime % 86400) / 3600);
            const minutes = Math.floor((uptime % 3600) / 60);
            const seconds = uptime % 60;
            
            let uptimeStr = '';
            if (days > 0) uptimeStr += `${days}d `;
            uptimeStr += `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
            
            document.getElementById('uptime').textContent = uptimeStr;
        }
        
        function updateSystemStats() {
            if (isLoading) return;
            
            fetch('/api/stats')
                .then(response => response.json())
                .then(data => {
                    // Update CPU
                    const cpuUsage = data.cpu_percent;
                    document.getElementById('cpu-usage').textContent = `${cpuUsage}%`;
                    const cpuBar = document.getElementById('cpu-bar');
                    cpuBar.style.width = `${cpuUsage}%`;
                    cpuBar.className = `metric-fill ${cpuUsage > 80 ? 'danger' : cpuUsage > 60 ? 'warning' : ''}`;
                    
                    // Update Memory
                    const memoryUsage = data.memory_percent;
                    document.getElementById('memory-usage').textContent = `${memoryUsage}%`;
                    const memoryBar = document.getElementById('memory-bar');
                    memoryBar.style.width = `${memoryUsage}%`;
                    memoryBar.className = `metric-fill ${memoryUsage > 80 ? 'danger' : memoryUsage > 60 ? 'warning' : ''}`;
                    
                    // Update Disk
                    const diskUsage = data.disk_percent;
                    document.getElementById('disk-usage').textContent = `${diskUsage}%`;
                    const diskBar = document.getElementById('disk-bar');
                    diskBar.style.width = `${diskUsage}%`;
                    diskBar.className = `metric-fill ${diskUsage > 80 ? 'danger' : diskUsage > 60 ? 'warning' : ''}`;
                    
                    // Update other info
                    document.getElementById('active-connections').textContent = data.connections;
                    document.getElementById('server-ip').textContent = data.server_ip;
                    document.getElementById('last-update').textContent = new Date().toLocaleTimeString();
                })
                .catch(error => {
                    console.error('Error fetching stats:', error);
                    showAlert('Failed to fetch system stats', 'warning');
                });
        }
        
        function refreshServices() {
            if (isLoading) return;
            isLoading = true;
            
            fetch('/api/services')
                .then(response => response.json())
                .then(data => {
                    const container = document.getElementById('services-container');
                    container.innerHTML = '';
                    
                    document.getElementById('total-services').textContent = data.services.length;
                    
                    data.services.forEach(service => {
                        const serviceCard = document.createElement('div');
                        serviceCard.className = 'service-card';
                        
                        const statusClass = service.status === 'active' ? 'status-online' : 'status-offline';
                        const statusIcon = service.status === 'active' ? '●' : '●';
                        
                        serviceCard.innerHTML = `
                            <div class="service-name">${service.name}</div>
                            <div class="service-status">
                                <span class="status-label">Status:</span>
                                <span class="status-value ${statusClass}">${statusIcon} ${service.status}</span>
                            </div>
                            <div class="service-status">
                                <span class="status-label">Ports:</span>
                                <span class="status-value">${service.ports || 'N/A'}</span>
                            </div>
                            <div class="service-status">
                                <span class="status-label">Uptime:</span>
                                <span class="status-value">${service.uptime || 'N/A'}</span>
                            </div>
                            <div class="control-buttons" style="margin-top: 10px;">
                                <button class="btn btn-success" onclick="restartService('${service.name}')">🔄</button>
                                <button class="btn btn-warning" onclick="checkService('${service.name}')">🔍</button>
                            </div>
                        `;
                        
                        container.appendChild(serviceCard);
                    });
                    
                    isLoading = false;
                })
                .catch(error => {
                    console.error('Error fetching services:', error);
                    showAlert('Failed to fetch services', 'warning');
                    isLoading = false;
                });
        }
        
        function refreshLogs() {
            fetch('/api/logs')
                .then(response => response.json())
                .then(data => {
                    const logContainer = document.getElementById('log-container');
                    logContainer.innerHTML = '';
                    
                    data.logs.forEach(log => {
                        const logEntry = document.createElement('div');
                        logEntry.className = 'log-entry';
                        logEntry.innerHTML = `
                            <span class="log-timestamp">[${log.timestamp}]</span>
                            <span class="log-level-${log.level}">${log.level.toUpperCase()}:</span>
                            ${log.message}
                        `;
                        logContainer.appendChild(logEntry);
                    });
                    
                    // Auto-scroll to bottom
                    logContainer.scrollTop = logContainer.scrollHeight;
                })
                .catch(error => {
                    console.error('Error fetching logs:', error);
                    showAlert('Failed to fetch logs', 'warning');
                });
        }
        
        function runMonitorCheck() {
            if (isLoading) return;
            isLoading = true;
            showAlert('Running monitor check...', 'info');
            
            fetch('/api/monitor/check', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showAlert(data.message, data.success ? 'success' : 'warning');
                    refreshServices();
                    refreshLogs();
                    isLoading = false;
                })
                .catch(error => {
                    console.error('Error running monitor check:', error);
                    showAlert('Failed to run monitor check', 'warning');
                    isLoading = false;
                });
        }
        
        function restartService(serviceName) {
            if (isLoading) return;
            showAlert(`Restarting ${serviceName}...`, 'info');
            
            fetch('/api/service/restart', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ service: serviceName })
            })
                .then(response => response.json())
                .then(data => {
                    showAlert(data.message, data.success ? 'success' : 'warning');
                    refreshServices();
                    refreshLogs();
                })
                .catch(error => {
                    console.error('Error restarting service:', error);
                    showAlert('Failed to restart service', 'warning');
                });
        }
        
        function restartAllServices() {
            if (isLoading) return;
            if (!confirm('Are you sure you want to restart all services?')) return;
            
            isLoading = true;
            showAlert('Restarting all services...', 'info');
            
            fetch('/api/services/restart-all', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showAlert(data.message, data.success ? 'success' : 'warning');
                    refreshServices();
                    refreshLogs();
                    isLoading = false;
                })
                .catch(error => {
                    console.error('Error restarting all services:', error);
                    showAlert('Failed to restart services', 'warning');
                    isLoading = false;
                });
        }
        
        function checkService(serviceName) {
            showAlert(`Checking ${serviceName}...`, 'info');
            
            fetch('/api/service/check', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ service: serviceName })
            })
                .then(response => response.json())
                .then(data => {
                    showAlert(data.message, data.success ? 'success' : 'warning');
                    refreshServices();
                })
                .catch(error => {
                    console.error('Error checking service:', error);
                    showAlert('Failed to check service', 'warning');
                });
        }
        
        function showServiceStatus() {
            fetch('/api/services/status')
                .then(response => response.json())
                .then(data => {
                    const message = `Services Status:\n${data.services.map(s => `${s.name}: ${s.status}`).join('\n')}`;
                    alert(message);
                })
                .catch(error => {
                    console.error('Error fetching service status:', error);
                    showAlert('Failed to fetch service status', 'warning');
                });
        }
        
        function clearLogs() {
            if (!confirm('Are you sure you want to clear all logs?')) return;
            
            fetch('/api/logs/clear', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    showAlert(data.message, 'success');
                    refreshLogs();
                })
                .catch(error => {
                    console.error('Error clearing logs:', error);
                    showAlert('Failed to clear logs', 'warning');
                });
        }
        
        function downloadLogs() {
            window.open('/api/logs/download', '_blank');
        }
        
        // Initialize and set intervals
        setInterval(updateUptime, 1000);
        setInterval(updateSystemStats, 5000);
        setInterval(refreshServices, 30000);
        setInterval(refreshLogs, 15000);
        
        // Initial load
        updateUptime();
        updateSystemStats();
        refreshServices();
        refreshLogs();
        
        // Check for monitor script availability
        fetch('/api/monitor/status')
            .then(response => response.json())
            .then(data => {
                if (!data.available) {
                    showAlert('Monitor script not found. Some features may not work.', 'warning');
                }
            })
            .catch(error => {
                console.error('Error checking monitor status:', error);
            });
    </script>
</body>
</html>
'''

def get_server_ip():
    """Get server IP address"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except:
        return "127.0.0.1"

def get_system_stats():
    """Get current system statistics"""
    try:
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        # Count network connections
        connections = len([conn for conn in psutil.net_connections(kind='tcp') if conn.status == 'ESTABLISHED'])
        
        return {
            'cpu_percent': round(cpu_percent, 1),
            'memory_percent': round(memory.percent, 1),
            'disk_percent': round(disk.percent, 1),
            'connections': connections,
            'server_ip': get_server_ip(),
            'timestamp': datetime.now().isoformat()
        }
    except Exception as e:
        add_log('error', f'Error getting system stats: {str(e)}')
        return {
            'cpu_percent': 0,
            'memory_percent': 0,
            'disk_percent': 0,
            'connections': 0,
            'server_ip': '127.0.0.1',
            'timestamp': datetime.now().isoformat(),
            'error': str(e)
        }

def add_log(level, message):
    """Add a log entry"""
    global logs
    log_entry = {
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'level': level,
        'message': message
    }
    logs.append(log_entry)
    
    # Keep only last 500 logs
    if len(logs) > 500:
        logs = logs[-500:]
    
    print(f"[{log_entry['timestamp']}] {level.upper()}: {message}")

def run_monitor_script(action, service=None):
    """Run rathole monitor script with specified action"""
    try:
        if not os.path.exists(RATHOLE_MONITOR_SCRIPT):
            return False, "Monitor script not found"
        
        cmd = [RATHOLE_MONITOR_SCRIPT, action]
        if service:
            # For individual service operations, we might need to modify the script
            # For now, we'll run the general action
            pass
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        
        if result.returncode == 0:
            add_log('info', f'Monitor script {action} completed successfully')
            return True, result.stdout
        else:
            add_log('error', f'Monitor script {action} failed: {result.stderr}')
            return False, result.stderr
            
    except subprocess.TimeoutExpired:
        add_log('error', f'Monitor script {action} timed out')
        return False, "Operation timed out"
    except Exception as e:
        add_log('error', f'Error running monitor script {action}: {str(e)}')
        return False, str(e)

def get_rathole_services():
    """Get list of rathole services using systemctl"""
    try:
        result = subprocess.run(
            ['systemctl', 'list-units', '--type=service', '--all', '--no-legend'],
            capture_output=True, text=True, timeout=30
        )
        
        if result.returncode != 0:
            return []
        
        services = []
        for line in result.stdout.split('\n'):
            if line.strip():
                parts = line.split()
                if len(parts) > 0:
                    service_name = parts[0]
                    # Match rathole-iran*.service or rathole-kharej*.service pattern
                    if re.match(r'^rathole-(iran|kharej)\d+\.service$', service_name):
                        services.append(service_name)
        
        return sorted(services)
        
    except Exception as e:
        add_log('error', f'Error getting rathole services: {str(e)}')
        return []

def get_service_info(service_name):
    """Get detailed information about a service"""
    try:
        # Get service status
        status_result = subprocess.run(
            ['systemctl', 'is-active', service_name],
            capture_output=True, text=True
        )
        status = status_result.stdout.strip()
        
        # Get service uptime
        uptime_result = subprocess.run(
            ['systemctl', 'show', service_name, '--property=ActiveEnterTimestamp', '--value'],
            capture_output=True, text=True
        )
        uptime_str = uptime_result.stdout.strip()
        
        # Extract ports from service name (rathole-iran1234 -> 1234)
        port_match = re.search(r'rathole-(iran|kharej)(\d+)', service_name)
        ports = port_match.group(2) if port_match else 'N/A'
        
        # Calculate uptime
        uptime = 'N/A'
        if uptime_str and status == 'active':
            try:
                # Parse the timestamp and calculate uptime
                from datetime import datetime
                if 'ago' not in uptime_str and uptime_str != 'n/a':
                    # Try to parse the timestamp
                    start_time = datetime.strptime(uptime_str[:19], '%Y-%m-%d %H:%M:%S')
                    uptime_seconds = (datetime.now() - start_time).total_seconds()
                    
                    days = int(uptime_seconds // 86400)
                    hours = int((uptime_seconds % 86400) // 3600)
                    minutes = int((uptime_seconds % 3600) // 60)
                    
                    if days > 0:
                        uptime = f"{days}d {hours}h {minutes}m"
                    elif hours > 0:
                        uptime = f"{hours}h {minutes}m"
                    else:
                        uptime = f"{minutes}m"
            except:
                pass
        
        return {
            'name': service_name,
            'status': status,
            'ports': ports,
            'uptime': uptime
        }
        
    except Exception as e:
        add_log('error', f'Error getting service info for {service_name}: {str(e)}')
        return {
            'name': service_name,
            'status': 'unknown',
            'ports': 'N/A',
            'uptime': 'N/A'
        }

def restart_systemd_service(service_name):
    """Restart a systemd service"""
    try:
        result = subprocess.run(
            ['systemctl', 'restart', service_name],
            capture_output=True, text=True, timeout=30
        )
        
        if result.returncode == 0:
            add_log('info', f'Successfully restarted service: {service_name}')
            return True, f'Service {service_name} restarted successfully'
        else:
            add_log('error', f'Failed to restart service {service_name}: {result.stderr}')
            return False, f'Failed to restart {service_name}: {result.stderr}'
            
    except Exception as e:
        add_log('error', f'Error restarting service {service_name}: {str(e)}')
        return False, str(e)

def monitor_rathole_processes():
    """Monitor rathole processes in background"""
    add_log('info', 'Starting rathole process monitor thread')
    
    while True:
        try:
            # Get rathole services
            services = get_rathole_services()
            
            if services:
                add_log('info', f'Monitoring {len(services)} rathole services')
                
                # Check each service
                for service in services:
                    info = get_service_info(service)
                    if info['status'] != 'active':
                        add_log('warning', f'Service {service} is {info["status"]}')
            else:
                add_log('warning', 'No rathole services found')
            
            time.sleep(60)  # Check every minute
            
        except Exception as e:
            add_log('error', f'Monitor thread error: {str(e)}')
            time.sleep(30)

# Flask Routes
@app.route('/')
def index():
    """Main dashboard page"""
    return render_template_string(HTML_TEMPLATE, port=PORT)

@app.route('/api/stats')
def api_stats():
    """API endpoint for system statistics"""
    stats = get_system_stats()
    return jsonify(stats)

@app.route('/api/services')
def api_services():
    """API endpoint for rathole services"""
    try:
        services = get_rathole_services()
        service_info = []
        
        for service in services:
            info = get_service_info(service)
            service_info.append(info)
        
        return jsonify({
            'success': True,
            'services': service_info,
            'total': len(service_info)
        })
    except Exception as e:
        add_log('error', f'Error in api_services: {str(e)}')
        return jsonify({
            'success': False,
            'error': str(e),
            'services': []
        })

@app.route('/api/services/status')
def api_services_status():
    """API endpoint for services status summary"""
    try:
        services = get_rathole_services()
        service_status = []
        
        for service in services:
            info = get_service_info(service)
            service_status.append({
                'name': info['name'],
                'status': info['status']
            })
        
        return jsonify({
            'success': True,
            'services': service_status
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })

@app.route('/api/service/restart', methods=['POST'])
def api_service_restart():
    """API endpoint to restart a specific service"""
    try:
        data = request.get_json()
        service_name = data.get('service')
        
        if not service_name:
            return jsonify({
                'success': False,
                'message': 'Service name not provided'
            })
        
        success, message = restart_systemd_service(service_name)
        return jsonify({
            'success': success,
            'message': message
        })
        
    except Exception as e:
        add_log('error', f'Error in api_service_restart: {str(e)}')
        return jsonify({
            'success': False,
            'message': str(e)
        })

@app.route('/api/services/restart-all', methods=['POST'])
def api_services_restart_all():
    """API endpoint to restart all rathole services"""
    try:
        services = get_rathole_services()
        results = []
        
        for service in services:
            success, message = restart_systemd_service(service)
            results.append({
                'service': service,
                'success': success,
                'message': message
            })
            time.sleep(2)  # Wait between restarts
        
        successful = sum(1 for r in results if r['success'])
        total = len(results)
        
        return jsonify({
            'success': successful == total,
            'message': f'Restarted {successful}/{total} services successfully',
            'results': results
        })
        
    except Exception as e:
        add_log('error', f'Error in api_services_restart_all: {str(e)}')
        return jsonify({
            'success': False,
            'message': str(e)
        })

@app.route('/api/service/check', methods=['POST'])
def api_service_check():
    """API endpoint to check a specific service"""
    try:
        data = request.get_json()
        service_name = data.get('service')
        
        if not service_name:
            return jsonify({
                'success': False,
                'message': 'Service name not provided'
            })
        
        info = get_service_info(service_name)
        return jsonify({
            'success': info['status'] == 'active',
            'message': f'Service {service_name} is {info["status"]}',
            'info': info
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        })

@app.route('/api/monitor/check', methods=['POST'])
def api_monitor_check():
    """API endpoint to run monitor check"""
    try:
        success, message = run_monitor_script('monitor')
        return jsonify({
            'success': success,
            'message': 'Monitor check completed' if success else f'Monitor check failed: {message}'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': str(e)
        })

@app.route('/api/monitor/status')
def api_monitor_status():
    """API endpoint to check if monitor script is available"""
    return jsonify({
        'available': os.path.exists(RATHOLE_MONITOR_SCRIPT),
        'script_path': RATHOLE_MONITOR_SCRIPT
    })

@app.route('/api/logs')
def api_logs():
    """API endpoint for logs"""
    return jsonify({
        'success': True,
        'logs': logs[-100:]  # Return last 100 logs
    })

@app.route('/api/logs/clear', methods=['POST'])
def api_logs_clear():
    """API endpoint to clear logs"""
    global logs
    logs = []
    add_log('info', 'Logs cleared by user')
    return jsonify({
        'success': True,
        'message': 'Logs cleared successfully'
    })

@app.route('/api/logs/download')
def api_logs_download():
    """API endpoint to download logs"""
    try:
        from flask import make_response
        
        log_content = '\n'.join([
            f"[{log['timestamp']}] {log['level'].upper()}: {log['message']}"
            for log in logs
        ])
        
        response = make_response(log_content)
        response.headers['Content-Disposition'] = f'attachment; filename=rathole_monitor_logs_{datetime.now().strftime("%Y%m%d_%H%M%S")}.txt'
        response.headers['Content-Type'] = 'text/plain'
        return response
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })

@app.route('/api/health')
def api_health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'port': PORT,
        'monitor_script_available': os.path.exists(RATHOLE_MONITOR_SCRIPT)
    })

def main():
    """Main application entry point"""
    print(f"🚀 Starting Rathole Monitor Dashboard on port {PORT}")
    add_log('info', f'Rathole Monitor Dashboard starting on port {PORT}')
    add_log('info', f'Monitor script path: {RATHOLE_MONITOR_SCRIPT}')
    
    # Check if monitor script exists
    if os.path.exists(RATHOLE_MONITOR_SCRIPT):
        add_log('info', 'Monitor script found and available')
    else:
        add_log('warning', f'Monitor script not found at {RATHOLE_MONITOR_SCRIPT}')
    
    # Start monitoring thread
    monitor_thread = threading.Thread(target=monitor_rathole_processes, daemon=True)
    monitor_thread.start()
    add_log('info', 'Background monitoring thread started')
    
    try:
        app.run(host='0.0.0.0', port=PORT, debug=DEBUG, threaded=True)
    except KeyboardInterrupt:
        add_log('info', 'Rathole Monitor Dashboard stopped by user')
        print("\n👋 Rathole Monitor Dashboard stopped")
    except Exception as e:
        add_log('error', f'Failed to start server: {str(e)}')
        print(f"❌ Error starting server: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
