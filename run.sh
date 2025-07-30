#!/bin/bash

# Rathole Monitor - Auto Installation & Setup Script
# Usage: curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="rathole_monitor"
PROJECT_DIR="/root/$PROJECT_NAME"
REPO_URL="https://github.com/hayousef68/rathole_monitor.git"
DEFAULT_PORT=${PORT:-3000}
LOG_FILE="/var/log/rathole_monitor.log"
SERVICE_NAME="rathole-monitor"
MONITOR_SCRIPT_PATH="$PROJECT_DIR/rathole_monitor.sh"

# Banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    🚇 Rathole Monitor                        ║"
    echo "║              Automated Installation & Setup                  ║"
    echo "║                                                              ║"
    echo "║    GitHub: https://github.com/hayousef68/rathole_monitor     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] ❌ $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING] ⚠️  $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] ℹ️  $1${NC}"
}

step() {
    echo -e "${CYAN}[STEP] 🔧 $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root!"
        error "Please run: sudo bash $0"
        exit 1
    fi
    log "Running as root - OK"
}

# Detect system
detect_system() {
    step "Detecting operating system..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$NAME
        OS_VERSION=$VERSION_ID
        info "Detected: $OS_NAME $OS_VERSION"
    else
        warn "Cannot detect OS version, proceeding with generic setup"
        OS_NAME="Unknown"
    fi
}

# Install system dependencies
install_dependencies() {
    step "Installing system dependencies..."
    
    # Update package manager
    if command -v apt-get &> /dev/null; then
        info "Using apt package manager..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y \
            python3 \
            python3-pip \
            python3-venv \
            python3-dev \
            git \
            curl \
            wget \
            systemd \
            net-tools \
            lsof \
            htop \
            nano \
            unzip \
            build-essential \
            2>/dev/null || true
            
        # Try to install Python packages from system repos
        apt-get install -y \
            python3-flask \
            python3-psutil \
            python3-requests \
            2>/dev/null || true
            
    elif command -v yum &> /dev/null; then
        info "Using yum package manager..."
        yum update -y -q
        yum install -y \
            python3 \
            python3-pip \
            python3-devel \
            git \
            curl \
            wget \
            systemd \
            net-tools \
            lsof \
            htop \
            nano \
            unzip \
            gcc \
            2>/dev/null || true
            
    elif command -v dnf &> /dev/null; then
        info "Using dnf package manager..."
        dnf update -y -q
        dnf install -y \
            python3 \
            python3-pip \
            python3-devel \
            git \
            curl \
            wget \
            systemd \
            net-tools \
            lsof \
            htop \
            nano \
            unzip \
            gcc \
            2>/dev/null || true
            
    elif command -v apk &> /dev/null; then
        info "Using apk package manager..."
        apk update
        apk add --no-cache \
            python3 \
            py3-pip \
            python3-dev \
            git \
            curl \
            wget \
            systemd \
            net-tools \
            lsof \
            htop \
            nano \
            unzip \
            build-base \
            2>/dev/null || true
    else
        error "Unsupported package manager!"
        exit 1
    fi
    
    log "System dependencies installed successfully"
}

# Stop existing services and processes
stop_existing() {
    step "Stopping existing rathole monitor processes..."
    
    # Stop systemd service if exists
    if systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        systemctl stop $SERVICE_NAME
        info "Stopped existing systemd service"
    fi
    
    # Kill any running processes
    pkill -f "python3.*app.py" 2>/dev/null || true
    pkill -f "rathole_monitor" 2>/dev/null || true
    pkill -f "rathole-monitor" 2>/dev/null || true
    
    sleep 3
    log "Existing processes stopped"
}

# Setup project directory
setup_project() {
    step "Setting up project directory..."
    
    # Remove existing directory
    if [ -d "$PROJECT_DIR" ]; then
        warn "Removing existing project directory..."
        rm -rf "$PROJECT_DIR"
    fi
    
    # Create project directory
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    # Clone repository
    info "Cloning repository from GitHub..."
    if ! git clone "$REPO_URL" . ; then
        error "Failed to clone repository!"
        exit 1
    fi
    
    log "Project directory setup completed"
}

# Install Python dependencies
install_python_deps() {
    step "Installing Python dependencies..."
    
    cd "$PROJECT_DIR"
    
    # Create virtual environment
    if python3 -m venv venv; then
        info "Virtual environment created successfully"
        source venv/bin/activate
        
        # Upgrade pip
        pip install --upgrade pip --quiet
        
        # Install dependencies
        if [ -f "requirements.txt" ]; then
            info "Installing from requirements.txt..."
            pip install -r requirements.txt --quiet
        else
            info "Installing essential packages..."
            pip install flask psutil requests --quiet
        fi
        
        log "Python dependencies installed in virtual environment"
    else
        warn "Virtual environment creation failed, using system packages..."
        
        # Fallback to system-wide installation
        python3 -m pip install --break-system-packages \
            flask psutil requests --quiet 2>/dev/null || \
        python3 -m pip install flask psutil requests --quiet || \
        pip3 install flask psutil requests --quiet || true
        
        log "Python dependencies installed system-wide"
    fi
}

# Set proper permissions
set_permissions() {
    step "Setting proper file permissions..."
    
    cd "$PROJECT_DIR"
    
    # Make scripts executable
    chmod +x app.py 2>/dev/null || true
    chmod +x rathole_monitor.sh
    chmod +x run.sh 2>/dev/null || true
    
    # Set directory permissions
    chmod -R 755 "$PROJECT_DIR"
    
    # Create log directory and file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Set ownership
    chown -R root:root "$PROJECT_DIR"
    chown root:root "$LOG_FILE"
    
    log "File permissions set correctly"
}

# Create systemd service
create_systemd_service() {
    step "Creating systemd service..."
    
    # Determine Python executable path
    if [ -f "$PROJECT_DIR/venv/bin/python3" ]; then
        PYTHON_EXEC="$PROJECT_DIR/venv/bin/python3"
    else
        PYTHON_EXEC="/usr/bin/python3"
    fi
    
    # Create service file
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=Rathole Monitor Dashboard
Documentation=https://github.com/hayousef68/rathole_monitor
After=network.target network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$PROJECT_DIR
ExecStart=$PYTHON_EXEC app.py
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=10
StartLimitBurst=3
StartLimitInterval=60

# Environment variables
Environment=PORT=$DEFAULT_PORT
Environment=DEBUG=false
Environment=RATHOLE_MONITOR_SCRIPT=$MONITOR_SCRIPT_PATH

# Resource limits
LimitNOFILE=65536

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=$PROJECT_DIR /var/log /tmp
PrivateDevices=true

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rathole-monitor

[Install]
WantedBy=multi-user.target
EOF

    # Create monitor script service
    cat > "/etc/systemd/system/rathole-monitor-script.service" << EOF
[Unit]
Description=Rathole Monitor Background Script
Documentation=https://github.com/hayousef68/rathole_monitor
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/rathole_monitor.sh daemon
Restart=always
RestartSec=30
StartLimitBurst=3
StartLimitInterval=60

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=rathole-monitor-script

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable services
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
    systemctl enable rathole-monitor-script
    
    log "Systemd services created and enabled"
}

# Start services
start_services() {
    step "Starting services..."
    
    # Start the monitor script first
    if systemctl start rathole-monitor-script; then
        info "Rathole monitor script service started"
    else
        warn "Failed to start monitor script service"
    fi
    
    sleep 2
    
    # Start the dashboard
    if systemctl start $SERVICE_NAME; then
        log "Rathole monitor dashboard service started successfully"
    else
        error "Failed to start dashboard service"
        systemctl status $SERVICE_NAME --no-pager
        exit 1
    fi
    
    sleep 3
    
    # Verify services are running
    if systemctl is-active --quiet $SERVICE_NAME; then
        log "Dashboard service is active and running"
    else
        error "Dashboard service failed to start properly"
        exit 1
    fi
}

# Create management aliases
create_aliases() {
    step "Creating management aliases..."
    
    # Create alias file
    cat > /root/.rathole_monitor_aliases << 'EOF'
# Rathole Monitor Management Aliases
alias rm-status='systemctl status rathole-monitor rathole-monitor-script'
alias rm-start='systemctl start rathole-monitor rathole-monitor-script'
alias rm-stop='systemctl stop rathole-monitor rathole-monitor-script'
alias rm-restart='systemctl restart rathole-monitor rathole-monitor-script'
alias rm-logs='journalctl -u rathole-monitor -f --no-pager'
alias rm-script-logs='journalctl -u rathole-monitor-script -f --no-pager'
alias rm-monitor='cd /root/rathole_monitor && ./rathole_monitor.sh status'
alias rm-update='cd /root/rathole_monitor && git pull origin main && systemctl restart rathole-monitor rathole-monitor-script'
EOF

    # Add to .bashrc if not already present
    if ! grep -q "rathole_monitor_aliases" /root/.bashrc 2>/dev/null; then
        echo "" >> /root/.bashrc
        echo "# Rathole Monitor Aliases" >> /root/.bashrc
        echo "source /root/.rathole_monitor_aliases" >> /root/.bashrc
    fi
    
    log "Management aliases created"
}

# Show installation summary
show_summary() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                    🎉 Installation Complete!                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get server IP
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP")
    
    echo -e "${GREEN}✅ Rathole Monitor Dashboard:${NC}"
    echo -e "   🌐 URL: ${YELLOW}http://$SERVER_IP:$DEFAULT_PORT${NC}"
    echo -e "   🌐 Local: ${YELLOW}http://localhost:$DEFAULT_PORT${NC}"
    echo ""
    
    echo -e "${GREEN}✅ Service Status:${NC}"
    echo -e "   📊 Dashboard: $(systemctl is-active rathole-monitor)"
    echo -e "   🔍 Monitor Script: $(systemctl is-active rathole-monitor-script)"
    echo ""
    
    echo -e "${GREEN}✅ Management Commands:${NC}"
    echo -e "   📊 Check Status: ${YELLOW}rm-status${NC}"
    echo -e "   🔄 Restart Services: ${YELLOW}rm-restart${NC}"
    echo -e "   📋 View Logs: ${YELLOW}rm-logs${NC}"
    echo -e "   🔍 Monitor Status: ${YELLOW}rm-monitor${NC}"
    echo -e "   ⬆️  Update: ${YELLOW}rm-update${NC}"
    echo ""
    
    echo -e "${GREEN}✅ Manual Commands:${NC}"
    echo -e "   systemctl status rathole-monitor"
    echo -e "   systemctl restart rathole-monitor"
    echo -e "   journalctl -u rathole-monitor -f"
    echo -e "   cd $PROJECT_DIR && ./rathole_monitor.sh status"
    echo ""
    
    echo -e "${GREEN}✅ Files Location:${NC}"
    echo -e "   📁 Project Directory: ${YELLOW}$PROJECT_DIR${NC}"
    echo -e "   📋 Log File: ${YELLOW}$LOG_FILE${NC}"
    echo -e "   ⚙️  Service Files: ${YELLOW}/etc/systemd/system/rathole-monitor*.service${NC}"
    echo ""
    
    echo -e "${BLUE}💡 Notes:${NC}"
    echo -e "   • Services will auto-start on system reboot"
    echo -e "   • Dashboard monitors rathole-iran* and rathole-kharej* services"
    echo -e "   • Run 'source ~/.bashrc' to enable aliases in current session"
    echo ""
    
    echo -e "${YELLOW}🔗 GitHub Repository: https://github.com/hayousef68/rathole_monitor${NC}"
}

# Handle different installation modes
install_basic() {
    show_banner
    check_root
    detect_system
    install_dependencies
    stop_existing
    setup_project
    install_python_deps
    set_permissions
    create_systemd_service
    start_services
    create_aliases
    show_summary
}

install_multiple() {
    local instances=${1:-3}
    info "Installing $instances concurrent instances..."
    
    for i in $(seq 1 $instances); do
        local port=$((DEFAULT_PORT + i - 1))
        
        # Create separate service for each instance
        cat > "/etc/systemd/system/rathole-monitor-$i.service" << EOF
[Unit]
Description=Rathole Monitor Dashboard Instance $i
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/python3 app.py
Environment=PORT=$port
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable rathole-monitor-$i
        systemctl start rathole-monitor-$i
        
        info "Instance $i started on port $port"
    done
}

# Uninstall function
uninstall() {
    step "Uninstalling Rathole Monitor..."
    
    # Stop and disable services
    systemctl stop rathole-monitor rathole-monitor-script 2>/dev/null || true
    systemctl disable rathole-monitor rathole-monitor-script 2>/dev/null || true
    
    # Remove service files
    rm -f /etc/systemd/system/rathole-monitor*.service
    systemctl daemon-reload
    
    # Remove project directory
    rm -rf "$PROJECT_DIR"
    
    # Remove aliases
    rm -f /root/.rathole_monitor_aliases
    sed -i '/rathole_monitor_aliases/d' /root/.bashrc 2>/dev/null || true
    
    log "Rathole Monitor uninstalled successfully"
}

# Show usage
show_usage() {
    echo "Rathole Monitor - Installation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -p, --port PORT       Set dashboard port (default: 3000)"
    echo "  -m, --multiple NUM    Install multiple instances"
    echo "  -u, --uninstall       Uninstall Rathole Monitor"
    echo "  -h, --help            Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                    # Basic installation"
    echo "  $0 -p 8080           # Install on port 8080"
    echo "  $0 -m 3              # Install 3 concurrent instances"
    echo "  $0 -u                # Uninstall"
    echo ""
    echo "One-liner installation:"
    echo "  curl -fsSL https://raw.githubusercontent.com/hayousef68/rathole_monitor/main/run.sh | bash"
}

# Parse command line arguments
INSTALL_TYPE="basic"
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            DEFAULT_PORT="$2"
            shift 2
            ;;
        -m|--multiple)
            INSTALL_TYPE="multiple"
            MULTIPLE_INSTANCES="$2"
            shift 2
            ;;
        -u|--uninstall)
            uninstall
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
    case $INSTALL_TYPE in
        basic)
            install_basic
            ;;
        multiple)
            install_basic
            install_multiple "$MULTIPLE_INSTANCES"
            ;;
        *)
            error "Unknown installation type"
            exit 1
            ;;
    esac
}

# Set trap for cleanup on exit
trap 'echo -e "\n${RED}Installation interrupted!${NC}"; exit 1' INT TERM

# Run main function
main "$@"
