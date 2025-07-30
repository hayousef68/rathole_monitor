#!/bin/bash

# Rathole Monitor - Auto Run Script
# Usage: curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Updated paths
PROJECT_DIR="/root/rathole_monitor"
REPO_URL="https://github.com/hayousef68/rathole_monitor.git"
DEFAULT_PORT=${PORT:-3000}
LOG_FILE="/var/log/rathole_monitor_web.log"
MONITOR_LOG_FILE="/var/log/rathole_monitor.log"

# Functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    log "Installing system dependencies..."
    if command -v apt-get &>/dev/null; then
        apt-get update -qq
        apt-get install -y python3 python3-pip python3-venv git curl wget systemd-dev
        apt-get install -y python3-flask python3-requests python3-psutil 2>/dev/null || true
    elif command -v yum &>/dev/null; then
        yum install -y python3 python3-pip git curl wget systemd-devel
    elif command -v dnf &>/dev/null; then
        dnf install -y python3 python3-pip git curl wget systemd-devel
    elif command -v apk &>/dev/null; then
        apk add --no-cache python3 py3-pip git curl wget systemd-dev
    else
        error "Unsupported package manager"
        exit 1
    fi
}

# Kill existing processes
kill_existing() {
    log "Stopping existing rathole monitor processes..."
    pkill -f "python3.*app.py" 2>/dev/null || true
    pkill -f "rathole_monitor" 2>/dev/null || true
    systemctl stop rathole-monitor-web.service 2>/dev/null || true
    sleep 2
}

# Setup project
setup_project() {
    log "Setting up project directory..."
    
    # Remove existing directory
    if [[ -d "$PROJECT_DIR" ]]; then
        rm -rf "$PROJECT_DIR"
    fi
    
    # Create directory
    mkdir -p "$PROJECT_DIR"
    
    # Clone repository
    log "Cloning repository..."
    git clone "$REPO_URL" "$PROJECT_DIR"
    
    cd "$PROJECT_DIR"
    
    # Set proper permissions
    chmod +x *.sh 2>/dev/null || true
    chmod 644 *.py 2>/dev/null || true
    
    # Install Python dependencies
    install_python_deps
}

# Install Python dependencies
install_python_deps() {
    log "Installing Python dependencies..."
    
    cd "$PROJECT_DIR"
    
    # Create requirements.txt if it doesn't exist
    if [[ ! -f "requirements.txt" ]]; then
        cat > requirements.txt << EOF
Flask==2.3.3
psutil==5.9.5
requests==2.31.0
EOF
    fi
    
    # Try with virtual environment first
    if python3 -m venv venv 2>/dev/null; then
        source venv/bin/activate
        pip install -r requirements.txt --quiet || {
            warn "Failed to install requirements with venv"
        }
    else
        # Fallback to system-wide installation
        python3 -m pip install -r requirements.txt --quiet --break-system-packages 2>/dev/null || {
            warn "Failed to install requirements system-wide"
        }
    fi
}

# Create systemd service for web dashboard
create_web_service() {
    if command -v systemctl &>/dev/null; then
        log "Creating systemd service for web dashboard..."
        
        # Determine Python executable
        if [[ -f "$PROJECT_DIR/venv/bin/python3" ]]; then
            PYTHON_CMD="$PROJECT_DIR/venv/bin/python3"
        else
            PYTHON_CMD="/usr/bin/python3"
        fi
        
        cat > /etc/systemd/system/rathole-monitor-web.service << EOF
[Unit]
Description=Rathole Monitor Web Dashboard
Documentation=https://github.com/hayousef68/rathole_monitor
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$PROJECT_DIR
ExecStart=$PYTHON_CMD app.py
Restart=always
RestartSec=10
Environment=PORT=$DEFAULT_PORT
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rathole-monitor-web

# Security settings
NoNewPrivileges=yes
ProtectHome=yes
ProtectSystem=strict
ReadWritePaths=$LOG_FILE $(dirname "$LOG_FILE") $PROJECT_DIR $MONITOR_LOG_FILE $(dirname "$MONITOR_LOG_FILE")

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable rathole-monitor-web.service
        info "Web dashboard service created and enabled"
    fi
}

# Start application
start_app() {
    log "Starting Rathole Monitor Web Dashboard..."
    
    cd "$PROJECT_DIR"
    
    # Check if app.py exists
    if [[ ! -f "app.py" ]]; then
        error "app.py not found in repository"
        exit 1
    fi
    
    # Start the service
    systemctl start rathole-monitor-web.service
    
    # Wait a moment and check if service is running
    sleep 3
    
    if systemctl is-active --quiet rathole-monitor-web.service; then
        log "✅ Rathole Monitor Web Dashboard started successfully!"
        log "🌐 Port: $DEFAULT_PORT"
        log "📝 Log file: $LOG_FILE"
        log "🔍 Check status: systemctl status rathole-monitor-web"
        log "📊 View logs: journalctl -u rathole-monitor-web -f"
        log "🌐 Access dashboard: http://localhost:$DEFAULT_PORT"
    else
        error "Failed to start web dashboard service"
        journalctl -u rathole-monitor-web.service --no-pager -n 20
        exit 1
    fi
}

# Start multiple instances
start_multiple() {
    local instances=${1:-3}
    log "Starting $instances concurrent instances..."
    
    for i in $(seq 1 $instances); do
        local port=$((DEFAULT_PORT + i - 1))
        log "Starting instance $i on port $port..."
        
        # Create service for each instance
        cat > /etc/systemd/system/rathole-monitor-web-$i.service << EOF
[Unit]
Description=Rathole Monitor Web Dashboard Instance $i
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/python3 app.py
Restart=always
RestartSec=10
Environment=PORT=$port

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable rathole-monitor-web-$i.service
        systemctl start rathole-monitor-web-$i.service
        
        sleep 1
        
        if systemctl is-active --quiet rathole-monitor-web-$i.service; then
            info "Instance $i started on port $port"
        else
            error "Failed to start instance $i"
        fi
    done
}

# Show usage
show_usage() {
    cat << EOF
Rathole Monitor Web Dashboard Setup

Usage: $0 [OPTIONS]

Options:
    -p, --port PORT         Set port number (default: 3000)
    -m, --multiple NUM      Start multiple instances
    -s, --service           Create systemd service
    -k, --kill              Kill existing processes
    -h, --help              Show this help

Examples:
    $0                      # Start single instance with service
    $0 -p 8080             # Start on port 8080
    $0 -m 3                # Start 3 instances
    $0 -k                  # Kill existing processes

GitHub Repository:
    $REPO_URL

Log Files:
    Web Dashboard: $LOG_FILE
    Monitor: $MONITOR_LOG_FILE
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            DEFAULT_PORT="$2"
            shift 2
            ;;
        -m|--multiple)
            MULTIPLE_INSTANCES="$2"
            shift 2
            ;;
        -s|--service)
            CREATE_SERVICE=true
            shift
            ;;
        -k|--kill)
            kill_existing
            exit 0
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log "🚀 Starting Rathole Monitor Web Dashboard Setup..."
    
    check_root
    install_dependencies
    kill_existing
    setup_project
    create_web_service
    
    if [[ -n "${MULTIPLE_INSTANCES:-}" ]]; then
        start_multiple "$MULTIPLE_INSTANCES"
    else
        start_app
    fi
    
    log "🎉 Setup completed successfully!"
    log "💡 Run '$0 -h' for more options"
    log "🌐 Web Dashboard: http://localhost:$DEFAULT_PORT"
}

# Run main function
main "$@"
