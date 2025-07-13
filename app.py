#!/usr/bin/env python3
"""
Rathole Monitor - Web Dashboard for Rathole Tunnel Status
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

app = Flask(__name__)

# Global variables for monitoring
tunnel_status = {}
system_stats = {}
logs = []

# HTML Template
HTML_TEMPLATE = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rathole Monitor</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            min-height: 100vh;
        }
        .container { 
            max-width: 1200px; 
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
        .log-container {
            background: rgba(0,0,0,0.2);
            border-radius: 10px;
            padding: 15px;
            max-height: 300px;
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
        .refresh-btn {
            background: rgba(255,255,255,0.2);
            border: none;
            color: white;
            padding: 10px 20px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 1em;
            margin-top: 10px;
            transition: all 0.3s ease;
        }
        .refresh-btn:hover {
            background: rgba(255,255,255,0.3);
            transform: translateY(-2px);
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
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.7; }
            100% { opacity: 1; }
        }
        .pulse {
            animation: pulse 2s infinite;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚇 Rathole Monitor</h1>
            <p>Real-time tunnel status and system monitoring</p>
        </div>
        
        <div class="stats-grid">
            <div class="card">
                <h3>🔌 Tunnel Status</h3>
                <div id="tunnel-status">
                    <div class="status-item">
                        <span class="status-label">Status:</span>
                        <span class="status-value status-online pulse">● Online</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Uptime:</span>
                        <span class="status-value" id="uptime">--</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Port:</span>
                        <span class="status-value">{{ port }}</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Connections:</span>
                        <span class="status-value" id="connections">--</span>
                    </div>
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
                        <span class="status-label">Listening Port:</span>
                        <span class="status-value">{{ port }}</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Protocol:</span>
                        <span class="status-value">HTTP/TCP</span>
                    </div>
                    <div class="status-item">
                        <span class="status-label">Last Check:</span>
                        <span class="status-value" id="last-check">--</span>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="card">
            <h3>📋 System Logs</h3>
            <div class="log-container" id="log-container">
                <!-- Logs will be populated here -->
            </div>
            <button class="refresh-btn" onclick="refreshLogs()">🔄 Refresh Logs</button>
        </div>
    </div>

    <script>
        let startTime = Date.now();
        
        function updateUptime() {
            const now = Date.now();
            const uptime = Math.floor((now - startTime) / 1000);
            const hours = Math.floor(uptime / 3600);
            const minutes = Math.floor((uptime % 3600) / 60);
            const seconds = uptime % 60;
            document.getElementById('uptime').textContent = 
                `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
        }
        
        function updateSystemStats() {
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
                    document.getElementById('connections').textContent = data.connections;
                    document.getElementById('server-ip').textContent = data.server_ip;
                    document.getElementById('last-check').textContent = new Date().toLocaleTimeString();
                })
                .catch(error => {
                    console.error('Error fetching stats:', error);
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
                });
        }
        
        // Initialize
        setInterval(updateUptime, 1000);
        setInterval(updateSystemStats, 5000);
        setInterval(refreshLogs, 10000);
        
        // Initial load
        updateUptime();
        updateSystemStats();
        refreshLogs();
    </script>
</body>
</html>
'''

def get_server_ip():
    """Get server IP address"""
    try:
        # Connect to a remote server to get local IP
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
        connections = len(psutil.net_connections(kind='tcp'))
        
        return {
            'cpu_percent': round(cpu_percent, 1),
            'memory_percent': round(memory.percent, 1),
            'disk_percent': round(disk.percent, 1),
            'connections': connections,
            'server_ip': get_server_ip(),
            'timestamp': datetime.now().isoformat()
        }
    except Exception as e:
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
    
    # Keep only last 100 logs
    if len(logs) > 100:
        logs = logs[-100:]
    
    print(f"[{log_entry['timestamp']}] {level.upper()}: {message}")

def monitor_rathole():
    """Monitor rathole process"""
    add_log('info', 'Starting rathole monitor thread')
    
    while True:
        try:
            # Check if rathole process is running
            rathole_running = False
            for proc in psutil.process_iter(['pid', 'name', 'cmdline']):
                try:
                    if 'rathole' in proc.info['name'].lower():
                        rathole_running = True
                        break
                except:
                    continue
            
            if rathole_running:
                add_log('info', 'Rathole process is running')
            else:
                add_log('warning', 'Rathole process not found')
            
            time.sleep(30)  # Check every 30 seconds
            
        except Exception as e:
            add_log('error', f'Monitor error: {str(e)}')
            time.sleep(10)

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template_string(HTML_TEMPLATE, port=PORT)

@app.route('/api/stats')
def api_stats():
    """API endpoint for system statistics"""
    stats = get_system_stats()
    return jsonify(stats)

@app.route('/api/logs')
def api_logs():
    """API endpoint for logs"""
    return jsonify({'logs': logs[-50:]})  # Return last 50 logs

@app.route('/api/health')
def api_health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'port': PORT
    })

def main():
    """Main application entry point"""
    print(f"🚀 Starting Rathole Monitor on port {PORT}")
    add_log('info', f'Rathole Monitor starting on port {PORT}')
    
    # Start monitoring thread
    monitor_thread = threading.Thread(target=monitor_rathole, daemon=True)
    monitor_thread.start()
    
    try:
        app.run(host='0.0.0.0', port=PORT, debug=DEBUG, threaded=True)
    except KeyboardInterrupt:
        add_log('info', 'Rathole Monitor stopped by user')
        print("\n👋 Rathole Monitor stopped")
    except Exception as e:
        add_log('error', f'Failed to start server: {str(e)}')
        print(f"❌ Error starting server: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
