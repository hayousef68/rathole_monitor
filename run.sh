#!/bin/bash
# Rathole Monitor - Auto Run Script
# Usage: curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/tmp/rathole_monitor"
RATHOLE_MONITOR_DIR="/root/rathole_monitor"  # مسیر جدید برای اسکریپت مانیتور
REPO_URL="https://github.com/hayousef68/rathole_monitor.git"
DEFAULT_PORT=${PORT:-3000}
LOG_FILE="/var/log/rathole_monitor.log"

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

install_dependencies() {
    log "Installing required dependencies..."
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y python3 python3-pip git curl wget python3-venv
    elif command -v yum &> /dev/null; then
        yum install -y epel-release || true
        yum install -y python3 python3-pip git curl wget
    elif command -v dnf &> /dev/null; then
        dnf install -y python3 python3-pip git curl wget
    elif command -v apk &> /dev/null; then
        apk add --no-cache python3 py3-pip git curl wget
    else
        error "Unsupported package manager"
        exit 1
    fi
}

kill_existing() {
    log "Stopping existing rathole monitor processes..."
    pkill -f "python3.*app.py" 2>/dev/null || true
    pkill -f "rathole_monitor" 2>/dev/null || true
    sleep 2
}

setup_project() {
    log "Setting up project directory..."
    # Remove existing directory
    if [ -d "$PROJECT_DIR" ]; then
        rm -rf "$PROJECT_DIR"
    fi
    
    # Create rathole monitor directory if it doesn't exist
    if [ ! -d "$RATHOLE_MONITOR_DIR" ]; then
        mkdir -p "$RATHOLE_MONITOR_DIR"
    fi
    
    # Clone repository
    log "Cloning repository..."
    git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Copy rathole_monitor.sh to the correct location
    if [ -f "rathole_monitor.sh" ]; then
        log "Copying rathole_monitor.sh to $RATHOLE_MONITOR_DIR..."
        cp "rathole_monitor.sh" "$RATHOLE_MONITOR_DIR/"
        chmod +x "$RATHOLE_MONITOR_DIR/rathole_monitor.sh"
        log "rathole_monitor.sh copied and permissions set"
    else
        error "rathole_monitor.sh not found in repository"
        exit 1
    fi
    
    # Install Python dependencies
    log "Creating virtual environment..."
    python3 -m venv venv || {
        error "Failed to create virtual environment. Make sure python3-venv is installed."
        exit 1
    }
    
    log "Installing Python dependencies in virtual environment..."
    source venv/bin/activate
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt --quiet
    else
        pip install flask requests psutil --quiet
    fi
    deactivate
}

create_service() {
    if [[ "$CREATE_SERVICE" != true ]]; then
        return
    fi
    
    log "Creating systemd service..."
    
    cat > /etc/systemd/system/rathole-monitor.service << EOF
[Unit]
Description=Rathole Monitor Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python app.py
Restart=always
RestartSec=10
Environment=PORT=$DEFAULT_PORT
Environment=RATHOLE_MONITOR_SCRIPT=$RATHOLE_MONITOR_DIR/rathole_monitor.sh

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable rathole-monitor.service
    info "Systemd service created. Use 'systemctl start rathole-monitor' to start"
}

start_app() {
    log "Starting Rathole Monitor..."
    cd "$PROJECT_DIR"
    
    # Check if app.py exists
    if [ ! -f "app.py" ]; then
        error "app.py not found in repository"
        exit 1
    fi
    
    # Start in background using virtual environment
    nohup $PROJECT_DIR/venv/bin/python app.py > "$LOG_FILE" 2>&1 &
    APP_PID=$!
    
    # Wait a moment and check if process is running
    sleep 3
    if kill -0 "$APP_PID" 2>/dev/null; then
        log "✅ Rathole Monitor started successfully!"
        log "📋 Process ID: $APP_PID"
        log "🌐 Port: $DEFAULT_PORT"
        log "📝 Log file: $LOG_FILE"
        log "🔍 Check status: ps aux | grep app.py"
        log "📊 View logs: tail -f $LOG_FILE"
    else
        error "Failed to start application"
        exit 1
    fi
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -p, --port PORT    Set port number (default: 3000)"
    echo "  -s, --service      Create systemd service"
    echo "  -h, --help         Show this help message"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--port)
                DEFAULT_PORT="$2"
                shift 2
                ;;
            -s|--service)
                CREATE_SERVICE=true
                shift
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
}

# Main execution
main() {
    log "🚀 Starting Rathole Monitor Setup..."
    check_root
    install_dependencies
    kill_existing
    setup_project
    
    if [[ "$CREATE_SERVICE" == true ]]; then
        create_service
    else
        start_app
    fi
    
    log "🎉 Setup completed successfully!"
    log "💡 Run '$0 -h' for more options"
    
    if [[ "$CREATE_SERVICE" == true ]]; then
        log "✅ Service installed. Use 'systemctl start rathole-monitor' to start it"
        log "🔍 Check status: systemctl status rathole-monitor"
        log "📊 View logs: journalctl -u rathole-monitor -f"
    fi
}

# Run main function
parse_args "$@"
main "$@"
