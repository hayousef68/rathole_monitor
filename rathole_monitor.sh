#!/bin/bash

# Rathole Tunnel Monitor Script - Fixed Version
# Automatically monitors and restarts Rathole tunnel services

# Configuration
LOG_FILE="/var/log/rathole_monitor.log"
CHECK_INTERVAL=300  # 5 minutes in seconds
MAX_RETRIES=3
RETRY_DELAY=10
ERROR_CHECK_PERIOD="5 minutes ago"
MIN_CRITICAL_ERRORS=1
ERROR_FREQUENCY_THRESHOLD=5
ENABLE_SMART_ERROR_DETECTION=true

# Rathole configuration paths
RATHOLE_CONFIG_DIR="/etc/rathole"
RATHOLE_SERVICE_PREFIX="rathole"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages with proper format
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Write to log file and display on screen
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Improved function to check if a port is listening
check_port() {
    local port="$1"
    
    # Validate port number
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi
    
    # Primary method: netstat
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tln 2>/dev/null | grep -q ":${port} "; then
            return 0
        fi
    fi
    
    # Secondary method: ss (more modern)
    if command -v ss >/dev/null 2>&1; then
        if ss -tln 2>/dev/null | grep -q ":${port} "; then
            return 0
        fi
    fi
    
    # Tertiary method: direct connection test
    if timeout 2 bash -c "</dev/tcp/127.0.0.1/${port}" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Extract ports from rathole config file
get_service_ports() {
    local service_name="$1"
    local config_file=""
    local ports=""
    
    # Find config file from service definition
    if command -v systemctl >/dev/null 2>&1; then
        local exec_start=$(systemctl show "$service_name" --property=ExecStart --value 2>/dev/null)
        config_file=$(echo "$exec_start" | grep -oE '/[^[:space:]]*\.toml' | head -1)
    fi
    
    # Try common locations if not found
    if [[ ! -f "$config_file" ]]; then
        local service_base=$(echo "$service_name" | sed 's/\.service$//')
        for possible_config in \
            "${RATHOLE_CONFIG_DIR}/${service_base}.toml" \
            "/etc/rathole/${service_base}.toml" \
            "/opt/rathole/${service_base}.toml"; do
            if [[ -f "$possible_config" ]]; then
                config_file="$possible_config"
                break
            fi
        done
    fi
    
    if [[ -f "$config_file" ]]; then
        # Extract ports from TOML config
        ports=$(grep -E "(bind_addr|remote_addr).*:[0-9]+" "$config_file" 2>/dev/null | \
                grep -oE '[0-9]+' | sort -u | tr '\n' ' ')
    fi
    
    echo "$ports" | tr -s ' ' | sed 's/^ *//;s/ *$//'
}

# Fixed function to check service status
check_service_status() {
    local service_name="$1"
    
    if ! command -v systemctl >/dev/null 2>&1; then
        log_message "ERROR" "systemctl command not found"
        return 1
    fi
    
    local status=$(systemctl is-active "$service_name" 2>/dev/null)
    
    case "$status" in
        active)
            # Additional check: verify process is actually running
            local main_pid=$(systemctl show "$service_name" --property=MainPID --value 2>/dev/null)
            if [[ "$main_pid" != "0" ]] && kill -0 "$main_pid" 2>/dev/null; then
                return 0
            else
                log_message "WARNING" "Service $service_name shows active but process not found"
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Simplified but effective error detection
is_critical_error() {
    local error_line="$1"
    
    # Skip empty lines
    [[ -z "$error_line" ]] && return 1
    
    # Check for critical patterns (case insensitive)
    if echo "$error_line" | grep -qi -E "(panic|fatal|failed to start|process exited|service (stopped|failed)|bind.*failed|address already in use|permission denied|config.*error)"; then
        return 0
    fi
    
    return 1
}

# Improved error checking with better logic
check_service_errors() {
    local service_name="$1"
    local time_range="${ERROR_CHECK_PERIOD:-5 minutes ago}"
    
    if ! command -v journalctl >/dev/null 2>&1; then
        log_message "WARNING" "journalctl not available, skipping error check"
        return 0
    fi
    
    # Get recent error/warning logs
    local error_logs=$(journalctl -u "$service_name" --since "$time_range" -p warning --no-pager -q 2>/dev/null)
    
    [[ -z "$error_logs" ]] && return 0
    
    local critical_error_count=0
    
    while IFS= read -r line; do
        if [[ -n "$line" ]] && is_critical_error "$line"; then
            critical_error_count=$((critical_error_count + 1))
            log_message "WARNING" "Critical error in $service_name: ${line:0:100}"
        fi
    done <<< "$error_logs"
    
    log_message "INFO" "Service $service_name: $critical_error_count critical errors found"
    
    # Return failure if critical errors exceed threshold
    [[ $critical_error_count -ge $MIN_CRITICAL_ERRORS ]] && return 1 || return 0
}

# Fixed restart function with better error handling
restart_service() {
    local service_name="$1"
    local retry_count=0
    
    log_message "WARNING" "Attempting to restart service: $service_name"
    
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        retry_count=$((retry_count + 1))
        log_message "INFO" "Restart attempt $retry_count/$MAX_RETRIES for $service_name"
        
        # Stop service first
        systemctl stop "$service_name" 2>/dev/null
        sleep 3
        
        # Start service
        if systemctl start "$service_name" 2>/dev/null; then
            log_message "INFO" "Start command issued for $service_name"
            
            # Wait for service to become active
            local wait_count=0
            local max_wait=30
            
            while [[ $wait_count -lt $max_wait ]]; do
                sleep 1
                wait_count=$((wait_count + 1))
                
                if systemctl is-active "$service_name" >/dev/null 2>&1; then
                    sleep 2  # Additional wait for port binding
                    
                    if check_tunnel_connectivity "$service_name"; then
                        log_message "INFO" "Successfully restarted service: $service_name"
                        return 0
                    fi
                fi
            done
        fi
        
        log_message "ERROR" "Failed restart attempt $retry_count for $service_name"
        [[ $retry_count -lt $MAX_RETRIES ]] && sleep $RETRY_DELAY
    done
    
    log_message "ERROR" "Failed to restart $service_name after $MAX_RETRIES attempts"
    return 1
}

# Improved connectivity check
check_tunnel_connectivity() {
    local service_name="$1"
    local ports=$(get_service_ports "$service_name")
    
    if [[ -z "$ports" ]]; then
        # If no ports found, check if process is running
        local main_pid=$(systemctl show "$service_name" --property=MainPID --value 2>/dev/null)
        if [[ "$main_pid" != "0" ]] && kill -0 "$main_pid" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    fi
    
    local working_ports=0
    local total_ports=0
    
    for port in $ports; do
        if [[ -n "$port" ]]; then
            total_ports=$((total_ports + 1))
            if check_port "$port"; then
                working_ports=$((working_ports + 1))
            else
                log_message "WARNING" "Port $port not accessible for $service_name"
            fi
        fi
    done
    
    if [[ $total_ports -eq 0 ]]; then
        return 1
    fi
    
    local success_rate=$(( (working_ports * 100) / total_ports ))
    log_message "INFO" "Port connectivity for $service_name: $working_ports/$total_ports ($success_rate%)"
    
    # Service is healthy if at least 50% of ports are working
    [[ $success_rate -ge 50 ]] && return 0 || return 1
}

# Main monitoring function for a single service
monitor_service() {
    local service_name="$1"
    local needs_restart=false
    local restart_reason=""
    
    log_message "INFO" "Checking service: $service_name"
    
    # Check 1: Service status
    if ! check_service_status "$service_name"; then
        needs_restart=true
        restart_reason="Service not active"
    fi
    
    # Check 2: Recent errors (only if service is running)
    if [[ "$needs_restart" == "false" ]] && ! check_service_errors "$service_name"; then
        needs_restart=true
        restart_reason="Critical errors detected"
    fi
    
    # Check 3: Port connectivity (only if service is running)
    if [[ "$needs_restart" == "false" ]] && ! check_tunnel_connectivity "$service_name"; then
        needs_restart=true
        restart_reason="Connectivity issues"
    fi
    
    # Restart if needed
    if [[ "$needs_restart" == "true" ]]; then
        log_message "WARNING" "Service $service_name needs restart: $restart_reason"
        restart_service "$service_name"
    else
        log_message "INFO" "Service $service_name is healthy"
    fi
}

# Get all rathole services
get_rathole_services() {
    if ! command -v systemctl >/dev/null 2>&1; then
        log_message "ERROR" "systemctl command not found"
        return 1
    fi
    
    # Search for rathole services
    local services=$(systemctl list-units --type=service --all --no-legend 2>/dev/null | \
                    awk '{print $1}' | \
                    grep -E "^rathole.*\.service$" | \
                    sort -u)
    
    if [[ -n "$services" ]]; then
        log_message "DEBUG" "Found rathole services: $(echo "$services" | tr '\n' ' ')"
    else
        log_message "DEBUG" "No rathole services found"
    fi
    
    echo "$services"
}

# Main monitoring function
main_monitor() {
    log_message "INFO" "Starting Rathole tunnel monitoring..."
    
    local services=$(get_rathole_services)
    
    if [[ -z "$services" ]]; then
        log_message "WARNING" "No rathole services found"
        return 1
    fi
    
    # Monitor each service
    while IFS= read -r service; do
        if [[ -n "$service" ]]; then
            monitor_service "$service"
        fi
    done <<< "$services"
    
    log_message "INFO" "Monitoring cycle completed"
}

# Show current status
show_status() {
    echo -e "${BLUE}=== Rathole Tunnel Status ===${NC}"
    echo ""
    
    local services=$(get_rathole_services)
    
    if [[ -z "$services" ]]; then
        echo -e "${YELLOW}No rathole services found${NC}"
        return 1
    fi
    
    while IFS= read -r service; do
        if [[ -n "$service" ]]; then
            local status=$(systemctl is-active "$service" 2>/dev/null)
            local ports=$(get_service_ports "$service")
            
            if [[ "$status" == "active" ]]; then
                echo -e "${GREEN}✓${NC} $service - ${GREEN}Active${NC}"
                if [[ -n "$ports" ]]; then
                    echo -e "  ${BLUE}Ports:${NC} $ports"
                    for port in $ports; do
                        if check_port "$port"; then
                            echo -e "    ${GREEN}✓${NC} Port $port: ${GREEN}Listening${NC}"
                        else
                            echo -e "    ${RED}✗${NC} Port $port: ${RED}Not accessible${NC}"
                        fi
                    done
                fi
            else
                echo -e "${RED}✗${NC} $service - ${RED}$status${NC}"
            fi
            echo ""
        fi
    done <<< "$services"
}

# Run as daemon
run_daemon() {
    log_message "INFO" "Starting Rathole Monitor Daemon (Check interval: ${CHECK_INTERVAL}s)"
    
    # Create log file
    touch "$LOG_FILE"
    
    # Set up signal handlers
    trap 'log_message "INFO" "Received signal, shutting down..."; exit 0' SIGTERM SIGINT
    
    while true; do
        main_monitor
        sleep $CHECK_INTERVAL
    done
}

# Install as systemd service
install_service() {
    local script_path=$(realpath "$0")
    
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This function must be run as root${NC}"
        exit 1
    fi
    
    cat > /etc/systemd/system/rathole-monitor.service << EOF
[Unit]
Description=Rathole Tunnel Monitor
After=network.target

[Service]
Type=simple
User=root
ExecStart=$script_path daemon
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable rathole-monitor.service
    systemctl start rathole-monitor.service
    
    echo -e "${GREEN}Rathole monitor service installed and started${NC}"
}

# Uninstall service
uninstall_service() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Error: This function must be run as root${NC}"
        exit 1
    fi
    
    systemctl stop rathole-monitor.service 2>/dev/null
    systemctl disable rathole-monitor.service 2>/dev/null
    rm -f /etc/systemd/system/rathole-monitor.service
    systemctl daemon-reload
    
    echo -e "${GREEN}Rathole monitor service uninstalled${NC}"
}

# Help function
show_help() {
    echo "Rathole Tunnel Monitor Script - Fixed Version"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  monitor      Run monitoring once"
    echo "  daemon       Run as daemon (continuous monitoring)"
    echo "  status       Show current status of all rathole services"
    echo "  install      Install as systemd service"
    echo "  uninstall    Uninstall systemd service"
    echo "  help         Show this help message"
    echo ""
    echo "Configuration:"
    echo "  Log file: $LOG_FILE"
    echo "  Check interval: ${CHECK_INTERVAL}s"
    echo "  Max retries: $MAX_RETRIES"
}

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Main script logic
if [[ $# -eq 0 ]]; then
    show_status
    exit 0
fi

case "$1" in
    monitor)
        main_monitor
        ;;
    daemon)
        run_daemon
        ;;
    status)
        show_status
        ;;
    install)
        install_service
        ;;
    uninstall)
        uninstall_service
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
