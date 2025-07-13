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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root. Consider using a non-root user."
    fi
}

# Install dependencies
install_dependencies() {
    log "Installing system dependencies..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update -qq
        apt-get install -y python3 python3-pip git curl wget
    elif command -v yum &> /dev/null; then
        yum install -y python3 python3-pip git curl wget
    elif command -v apk &> /dev/null; then
        apk add --no-cache python3 py3-pip git curl wget
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
    sleep 2
}

# Setup project
setup_project() {
    log "Setting up project directory..."
    
    # Remove existing directory
    if [ -d "$PROJECT_DIR" ]; then
        rm -rf "$PROJECT_DIR"
    fi
    
    # Clone repository
    log "Cloning repository..."
    git clone "$REPO_URL" "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Install Python dependencies
    if [ -f "requirements.txt" ]; then
        log "Installing Python dependencies..."
        python3 -m pip install -r requirements.txt --quiet
    else
        # Install common dependencies
        log "Installing common Python packages..."
        python3 -m pip install flask requests psutil --quiet
    fi
}

# Create systemd service (optional)
create_service() {
    if command -v systemctl &> /dev/null; then
        log "Creating systemd service..."
        
        cat > /etc/systemd/system/rathole-monitor.service << EOF
[Unit]
Description=Rathole Monitor Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/python3 app.py
Restart=always
RestartSec=10
Environment=PORT=$DEFAULT_PORT

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable rathole-monitor.service
        info "Systemd service created. Use 'systemctl start rathole-monitor' to start"
    fi
}

# Start application
start_app() {
    log "Starting Rathole Monitor..."
    
    cd "$PROJECT_DIR"
    
    # Check if app.py exists
    if [ ! -f "app.py" ]; then
        error "app.py not found in repository"
        exit 1
    fi
    
    # Start in background
    nohup python3 app.py > "$LOG_FILE" 2>&1 &
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

# Start multiple instances
start_multiple() {
    local instances=${1:-3}
    log "Starting $instances concurrent instances..."
    
    for i in $(seq 1 $instances); do
        local port=$((DEFAULT_PORT + i - 1))
        log "Starting instance $i on port $port..."
        
        cd "$PROJECT_DIR"
        PORT=$port nohup python3 app.py > "/var/log/rathole_monitor_$i.log" 2>&1 &
        local pid=$!
        
        sleep 1
        if kill -0 "$pid" 2>/dev/null; then
            info "Instance $i started (PID: $pid, Port: $port)"
        else
            error "Failed to start instance $i"
        fi
    done
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -p, --port PORT       Set port number (default: 3000)"
    echo "  -m, --multiple NUM    Start multiple instances"
    echo "  -s, --service         Create systemd service"
    echo "  -k, --kill            Kill existing processes"
    echo "  -h, --help            Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                    # Start single instance"
    echo "  $0 -p 8080           # Start on port 8080"
    echo "  $0 -m 3              # Start 3 instances"
    echo "  $0 -s                # Create systemd service"
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
    log "🚀 Starting Rathole Monitor Setup..."
    
    check_root
    install_dependencies
    kill_existing
    setup_project
    
    if [[ "$CREATE_SERVICE" == true ]]; then
        create_service
    fi
    
    if [[ -n "$MULTIPLE_INSTANCES" ]]; then
        start_multiple "$MULTIPLE_INSTANCES"
    else
        start_app
    fi
    
    log "🎉 Setup completed successfully!"
    log "💡 Run '$0 -h' for more options"
}

# Run main function
main "$@"
