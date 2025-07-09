#!/bin/bash

# Rathole Tunnel Monitor Script
# Automatically monitors and restarts Rathole tunnel services

# Configuration
LOG_FILE="/var/log/rathole_monitor.log"
CHECK_INTERVAL=300  # 5 minutes in seconds
MAX_RETRIES=3
RETRY_DELAY=10
ERROR_CHECK_PERIOD="5 minutes ago"  # Time range for checking errors
MIN_CRITICAL_ERRORS=1  # Minimum critical errors to trigger restart
ERROR_FREQUENCY_THRESHOLD=5  # Max errors per time period
ENABLE_SMART_ERROR_DETECTION=true  # Enable smart error filtering

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Function to check if a port is listening
check_port() {
    local port=$1
    if netstat -tuln | grep -q ":${port} "; then
        return 0
    else
        return 1
    fi
}

# Function to extract ports from service name or config
get_service_ports() {
    local service_name=$1
    local config_file=""
    
    # Try to find config file from service definition
    config_file=$(systemctl show "$service_name" --property=ExecStart --value | grep -o '/[^[:space:]]*\.toml' | head -1)
    
    if [[ -f "$config_file" ]]; then
        # Extract ports from TOML config file
        grep -E "bind_addr.*:([0-9]+)" "$config_file" | grep -o '[0-9]\+' | sort -u
    else
        # Try to extract port from service name (e.g., rathole-kharej2053 -> 2053)
        echo "$service_name" | grep -o '[0-9]\+' | tail -1
    fi
}

# Function to check service status
check_service_status() {
    local service_name=$1
    local status=$(systemctl is-active "$service_name")
    
    if [[ "$status" == "active" ]]; then
        return 0
    else
        return 1
    fi
}

# List of error patterns that should be ignored (not critical)
IGNORED_ERRORS=(
    "Connection refused"
    "Connection reset by peer"
    "Broken pipe"
    "Connection timeout"
    "Temporary failure in name resolution"
    "No route to host"
    "Connection timed out"
    "Network is unreachable"
    "Connection closed"
    "Connection lost"
    "Failed to establish connection"
    "Client.* disconnected"
    "Handshake failed"
    "Read timeout"
    "Write timeout"
    "Stream closed"
    "Connection dropped"
    "Connection aborted"
    "SSL handshake failed"
    "TLS handshake failed"
    "Retry limit exceeded"
    "Connection reset"
    "Invalid response"
    "Protocol error"
    "Connection refused by server"
    "Connection terminated"
    "Connection interrupted"
    "Authentication failed"
    "Websocket connection failed"
    "Failed to read from socket"
    "Failed to write to socket"
    "EOF while reading"
    "Unexpected EOF"
    "Connection rejected"
    "Remote connection closed"
    "Host unreachable"
    "Connection pooling failed"
    "Keepalive failed"
    "Peer closed connection"
    "Socket closed"
    "Connection was closed"
    "Connection has been closed"
    "Connection lost to server"
    "Connection was reset"
    "Connection was terminated"
    "Connection was dropped"
    "connection failed"
    "failed to connect"
    "Connection refused by remote host"
    "Connection reset by remote host"
    "Network connection failed"
    "Connection broken"
    "Connection unstable"
    "Connection error"
    "Connection exception"
    "Connection closed by remote"
    "Connection ended"
    "Connection closed unexpectedly"
    "Connection was interrupted"
    "Connection was aborted"
    "Connection was terminated by remote"
    "Connection closed by peer"
    "Connection closed by server"
    "Connection was closed by remote"
    "Connection was reset by remote"
    "Connection was terminated unexpectedly"
    "Connection has been reset"
    "Connection was broken"
    "Connection was lost"
    "Connection was dropped by remote"
    "Connection was forcefully closed"
    "Connection closed due to timeout"
    "Connection was closed due to inactivity"
    "Connection was closed due to error"
    "Connection was closed abnormally"
    "Connection was closed gracefully"
    "Connection was ended by remote"
    "Connection was ended by client"
    "Connection was ended by server"
    "Connection was ended due to timeout"
    "Connection was ended abnormally"
    "Connection was ended gracefully"
    "Network error"
    "Network timeout"
    "Network connection lost"
    "Network connection failed"
    "Network connection closed"
    "Network connection terminated"
    "Network connection reset"
    "Network connection aborted"
    "Network connection broken"
    "Network connection unstable"
    "Network connection error"
    "Network connection exception"
    "Network connection timeout"
    "Network connection refused"
    "Network connection dropped"
    "Network connection interrupted"
    "Network connection reset by peer"
    "Network connection closed by peer"
    "Network connection closed by remote"
    "Network connection closed by server"
    "Network connection closed by client"
    "Network connection closed due to timeout"
    "Network connection closed due to inactivity"
    "Network connection closed due to error"
    "Network connection closed abnormally"
    "Network connection closed gracefully"
    "Network connection ended by remote"
    "Network connection ended by client"
    "Network connection ended by server"
    "Network connection ended due to timeout"
    "Network connection ended abnormally"
    "Network connection ended gracefully"
    "Unable to connect"
    "Failed to connect"
    "Connection attempt failed"
    "Connection attempt timed out"
    "Connection attempt rejected"
    "Connection attempt refused"
    "Connection attempt aborted"
    "Connection attempt reset"
    "Connection attempt dropped"
    "Connection attempt interrupted"
    "Connection attempt terminated"
    "Connection attempt failed due to timeout"
    "Connection attempt failed due to error"
    "Connection attempt failed due to refusal"
    "Connection attempt failed due to unreachable"
    "Connection attempt failed due to reset"
    "Connection attempt failed due to abort"
    "Connection attempt failed due to drop"
    "Connection attempt failed due to interrupt"
    "Connection attempt failed due to termination"
    "Connection attempt failed due to closure"
    "Connection attempt failed due to broken pipe"
    "Connection attempt failed due to network error"
    "Connection attempt failed due to network timeout"
    "Connection attempt failed due to network issue"
    "Connection attempt failed due to network unreachable"
    "Connection attempt failed due to network down"
    "Connection attempt failed due to network congestion"
    "Connection attempt failed due to network overload"
    "Connection attempt failed due to network instability"
    "Connection attempt failed due to network maintenance"
    "Connection attempt failed due to network configuration"
    "Connection attempt failed due to network security"
    "Connection attempt failed due to network policy"
    "Connection attempt failed due to network restriction"
    "Connection attempt failed due to network limitation"
    "Connection attempt failed due to network throttling"
    "Connection attempt failed due to network blocking"
)

# List of critical error patterns that require restart
CRITICAL_ERRORS=(
    "panic"
    "fatal"
    "segmentation fault"
    "core dumped"
    "invalid memory"
    "out of memory"
    "memory leak"
    "stack overflow"
    "buffer overflow"
    "null pointer"
    "access violation"
    "illegal instruction"
    "abort"
    "crashed"
    "failed to start"
    "process exited"
    "service stopped"
    "service failed"
    "bind failed"
    "failed to bind"
    "address already in use"
    "permission denied"
    "file not found"
    "configuration error"
    "config error"
    "invalid config"
    "failed to load config"
    "failed to parse config"
    "failed to read config"
    "config validation failed"
    "invalid configuration"
    "configuration syntax error"
    "missing configuration"
    "configuration file not found"
    "configuration parse error"
    "configuration load error"
    "configuration read error"
    "PermissionError"
    "FileNotFoundError"
    "IOError"
    "OSError"
    "SystemError"
    "RuntimeError"
    "MemoryError"
    "OverflowError"
    "ZeroDivisionError"
    "ValueError"
    "TypeError"
    "AttributeError"
    "NameError"
    "SyntaxError"
    "ImportError"
    "ModuleNotFoundError"
    "KeyError"
    "IndexError"
    "NotImplementedError"
    "AssertionError"
    "StopIteration"
    "GeneratorExit"
    "KeyboardInterrupt"
    "SystemExit"
    "Exception"
    "Error"
    "Failed"
    "Panic"
    "Fatal"
    "Critical"
    "Emergency"
    "Alert"
    "Severe"
    "Major"
    "High"
    "Urgent"
    "Important"
    "Serious"
    "Bad"
    "Fail"
    "Err"
    "Err:"
    "ERROR"
    "FATAL"
    "CRITICAL"
    "PANIC"
    "EMERGENCY"
    "ALERT"
    "SEVERE"
    "MAJOR"
    "HIGH"
    "URGENT"
    "IMPORTANT"
    "SERIOUS"
    "BAD"
    "FAIL"
    "FAILED"
    "FAILURE"
    "CRASH"
    "CRASHED"
    "ABORT"
    "ABORTED"
    "STOP"
    "STOPPED"
    "KILL"
    "KILLED"
    "TERMINATE"
    "TERMINATED"
    "EXIT"
    "EXITED"
    "QUIT"
    "QUITTED"
    "CLOSE"
    "CLOSED"
    "SHUTDOWN"
    "SHUTDOW"
    "RESTART"
    "RESTARTED"
    "REBOOT"
    "REBOOTED"
    "RESET"
    "RESETED"
    "CLEAR"
    "CLEARED"
    "FLUSH"
    "FLUSHED"
    "SYNC"
    "SYNCED"
)

# Function to check if an error is critical
is_critical_error() {
    local error_line="$1"
    
    # Check if error matches any critical pattern
    for pattern in "${CRITICAL_ERRORS[@]}"; do
        if echo "$error_line" | grep -qi "$pattern"; then
            return 0  # Critical error found
        fi
    done
    
    # Check if error matches any ignored pattern (non-critical)
    for pattern in "${IGNORED_ERRORS[@]}"; do
        if echo "$error_line" | grep -qi "$pattern"; then
            return 1  # Non-critical error, ignore it
        fi
    done
    
    # If not in either list, consider it potentially critical
    return 0
}

# Function to analyze error patterns and determine if restart is needed
analyze_error_patterns() {
    local service_name=$1
    local time_range="${ERROR_CHECK_PERIOD:-5 minutes ago}"
    
    # Get all logs (not just errors) for pattern analysis
    local all_logs=$(journalctl -u "$service_name" --since "$time_range" --no-pager -q 2>/dev/null)
    
    if [[ -z "$all_logs" ]]; then
        return 0  # No logs, assume healthy
    fi
    
    local restart_indicators=0
    local connection_attempts=0
    local successful_connections=0
    local failed_connections=0
    
    # Analyze logs for patterns
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Count successful connections
            if echo "$line" | grep -qi "control channel established\|connection established\|client connected\|server connected"; then
                successful_connections=$((successful_connections + 1))
            fi
            
            # Count connection attempts
            if echo "$line" | grep -qi "attempting\|trying\|connecting"; then
                connection_attempts=$((connection_attempts + 1))
            fi
            
            # Count failed connections (only if not in ignored list)
            if echo "$line" | grep -qi "failed\|error\|warning"; then
                if is_critical_error "$line"; then
                    failed_connections=$((failed_connections + 1))
                    restart_indicators=$((restart_indicators + 1))
                fi
            fi
            
            # Check for service restart indicators
            if echo "$line" | grep -qi "service.*stopped\|service.*failed\|process.*exited\|starting.*service"; then
                restart_indicators=$((restart_indicators + 1))
            fi
        fi
    done <<< "$all_logs"
    
    # Calculate connection success rate
    local success_rate=0
    if [[ $connection_attempts -gt 0 ]]; then
        success_rate=$(( (successful_connections * 100) / connection_attempts ))
    fi
    
    log_message "INFO" "Service $service_name analysis: $successful_connections successful, $failed_connections failed, $success_rate% success rate"
    
    # Decision logic for restart
    local should_restart=false
    
    # Restart if too many critical errors
    if [[ $restart_indicators -ge $MIN_CRITICAL_ERRORS ]]; then
        log_message "WARNING" "Service $service_name has $restart_indicators critical errors (threshold: $MIN_CRITICAL_ERRORS)"
        should_restart=true
    fi
    
    # Restart if success rate is too low (less than 50% and some attempts made)
    if [[ $connection_attempts -ge 3 && $success_rate -lt 50 ]]; then
        log_message "WARNING" "Service $service_name has low success rate: $success_rate% (attempts: $connection_attempts)"
        should_restart=true
    fi
    
    # Return result
    if [[ $should_restart == true ]]; then
        return 1  # Restart needed
    fi
    
    return 0  # No restart needed
}

# Function to check if service has recent critical errors
check_service_errors() {
    local service_name=$1
    local time_range="${ERROR_CHECK_PERIOD:-5 minutes ago}"
    
    # Use advanced error analysis if enabled
    if [[ "$ENABLE_SMART_ERROR_DETECTION" == "true" ]]; then
        if ! analyze_error_patterns "$service_name"; then
            return 1  # Critical errors found
        fi
    else
        # Use simple error detection
        local error_logs=$(journalctl -u "$service_name" --since "$time_range" -p warning --no-pager -q 2>/dev/null)
        
        if [[ -z "$error_logs" ]]; then
            return 0  # No errors found
        fi
        
        # Check each error line
        local critical_error_count=0
        local total_error_count=0
        
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                total_error_count=$((total_error_count + 1))
                
                if is_critical_error "$line"; then
                    critical_error_count=$((critical_error_count + 1))
                    log_message "WARNING" "Critical error detected in $service_name: $line"
                else
                    log_message "DEBUG" "Non-critical error ignored in $service_name: $line"
                fi
            fi
        done <<< "$error_logs"
        
        log_message "INFO" "Service $service_name: $total_error_count total errors, $critical_error_count critical errors"
        
        # Only fail if we have critical errors above threshold
        if [[ $critical_error_count -ge $MIN_CRITICAL_ERRORS ]]; then
            return 1
        else
            return 0
        fi
    fi
    
    return 0
}

# Function to restart service with retries
restart_service() {
    local service_name=$1
    local retry_count=0
    
    log_message "WARNING" "Attempting to restart service: $service_name"
    
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        systemctl restart "$service_name"
        sleep $RETRY_DELAY
        
        if check_service_status "$service_name"; then
            log_message "INFO" "Successfully restarted service: $service_name"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_message "ERROR" "Failed to restart $service_name (attempt $retry_count/$MAX_RETRIES)"
            sleep $RETRY_DELAY
        fi
    done
    
    log_message "ERROR" "Failed to restart $service_name after $MAX_RETRIES attempts"
    return 1
}

# Function to check tunnel connectivity
check_tunnel_connectivity() {
    local service_name=$1
    local ports=$(get_service_ports "$service_name")
    local all_ports_ok=true
    
    for port in $ports; do
        if ! check_port "$port"; then
            log_message "WARNING" "Port $port is not listening for service $service_name"
            all_ports_ok=false
        fi
    done
    
    if [[ "$all_ports_ok" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to monitor single service
monitor_service() {
    local service_name=$1
    local needs_restart=false
    
    log_message "INFO" "Checking service: $service_name"
    
    # Check if service is active
    if ! check_service_status "$service_name"; then
        log_message "ERROR" "Service $service_name is not active"
        needs_restart=true
    fi
    
    # Check for recent errors
    if ! check_service_errors "$service_name"; then
        log_message "WARNING" "Service $service_name has recent errors"
        needs_restart=true
    fi
    
    # Check port connectivity
    if ! check_tunnel_connectivity "$service_name"; then
        log_message "WARNING" "Service $service_name has connectivity issues"
        needs_restart=true
    fi
    
    # Restart if needed
    if [[ "$needs_restart" == "true" ]]; then
        restart_service "$service_name"
    else
        log_message "INFO" "Service $service_name is healthy"
    fi
}

# Function to get all rathole services
get_rathole_services() {
    systemctl list-units --type=service --state=loaded | grep -E "rathole.*\.service" | awk '{print $1}'
}

# Function to display service status
display_status() {
    local service_name=$1
    local status=$(systemctl is-active "$service_name")
    local uptime=$(systemctl show "$service_name" --property=ActiveEnterTimestamp --value | sed 's/.*; //')
    
    if [[ "$status" == "active" ]]; then
        echo -e "${GREEN}✓${NC} $service_name - ${GREEN}Active${NC} (Up: $uptime)"
    else
        echo -e "${RED}✗${NC} $service_name - ${RED}$status${NC}"
    fi
}

# Main monitoring function
main_monitor() {
    log_message "INFO" "Starting Rathole tunnel monitoring..."
    
    # Get all rathole services
    local services=$(get_rathole_services)
    
    if [[ -z "$services" ]]; then
        log_message "WARNING" "No rathole services found"
        return 1
    fi
    
    log_message "INFO" "Found rathole services: $(echo $services | tr '\n' ' ')"
    
    # Monitor each service
    for service in $services; do
        monitor_service "$service"
    done
    
    log_message "INFO" "Monitoring cycle completed"
}

# Function to show current status
show_status() {
    echo -e "${BLUE}=== Rathole Tunnel Status ===${NC}"
    echo ""
    
    local services=$(get_rathole_services)
    
    if [[ -z "$services" ]]; then
        echo -e "${YELLOW}No rathole services found${NC}"
        return 1
    fi
    
    for service in $services; do
        display_status "$service"
    done
    
    echo ""
    echo -e "${BLUE}=== Recent Log Entries ===${NC}"
    if [[ -f "$LOG_FILE" ]]; then
        tail -10 "$LOG_FILE"
    else
        echo "No log file found"
    fi
}

# Function to run as daemon
run_daemon() {
    log_message "INFO" "Starting Rathole Monitor Daemon (Check interval: ${CHECK_INTERVAL}s)"
    
    while true; do
        main_monitor
        sleep $CHECK_INTERVAL
    done
}

# Function to install as systemd service
install_service() {
    local script_path=$(realpath "$0")
    
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

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable rathole-monitor.service
    systemctl start rathole-monitor.service
    
    echo -e "${GREEN}Rathole monitor service installed and started${NC}"
    echo "Use 'systemctl status rathole-monitor' to check status"
}

# Function to uninstall service
uninstall_service() {
    systemctl stop rathole-monitor.service 2>/dev/null
    systemctl disable rathole-monitor.service 2>/dev/null
    rm -f /etc/systemd/system/rathole-monitor.service
    systemctl daemon-reload
    
    echo -e "${GREEN}Rathole monitor service uninstalled${NC}"
}

# Help function
show_help() {
    echo "Rathole Tunnel Monitor Script"
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
    echo "Examples:"
    echo "  $0 monitor          # Run monitoring once"
    echo "  $0 daemon           # Run continuous monitoring"
    echo "  $0 status           # Show status"
    echo "  $0 install          # Install as service"
}

# Main script logic
case "${1:-status}" in
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
        echo "Unknown option: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
# Function to test service configuration
test_service_config() {
    local service_name=$1
    local config_file=""
    
    # Try to find config file from service definition
    config_file=$(systemctl show "$service_name" --property=ExecStart --value | grep -o '/[^[:space:]]*\.toml' | head -1)
    
    if [[ -f "$config_file" ]]; then
        echo -e "${BLUE}Testing configuration for $service_name${NC}"
        echo "Config file: $config_file"
        
        # Check if config file is readable
        if [[ -r "$config_file" ]]; then
            echo -e "${GREEN}✓${NC} Configuration file is readable"
            
            # Basic TOML syntax check
            if command -v toml > /dev/null 2>&1; then
                if toml verify "$config_file" > /dev/null 2>&1; then
                    echo -e "${GREEN}✓${NC} TOML syntax is valid"
                else
                    echo -e "${RED}✗${NC} TOML syntax error detected"
                    return 1
                fi
            else
                echo -e "${YELLOW}⚠${NC} TOML validator not available, skipping syntax check"
            fi
            
            # Check for required fields
            if grep -q "bind_addr" "$config_file"; then
                echo -e "${GREEN}✓${NC} bind_addr configuration found"
            else
                echo -e "${RED}✗${NC} bind_addr configuration missing"
                return 1
            fi
            
        else
            echo -e "${RED}✗${NC} Configuration file is not readable"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠${NC} Configuration file not found for $service_name"
        return 1
    fi
    
    return 0
}

# Function to show detailed service information
show_service_details() {
    local service_name=$1
    
    echo -e "${BLUE}=== Details for $service_name ===${NC}"
    echo ""
    
    # Service status
    local status=$(systemctl is-active "$service_name")
    local enabled=$(systemctl is-enabled "$service_name")
    
    echo "Status: $status"
    echo "Enabled: $enabled"
    
    # Service uptime
    local uptime=$(systemctl show "$service_name" --property=ActiveEnterTimestamp --value)
    if [[ -n "$uptime" && "$uptime" != "n/a" ]]; then
        echo "Started: $uptime"
    fi
    
    # Memory usage
    local memory=$(systemctl show "$service_name" --property=MemoryCurrent --value)
    if [[ -n "$memory" && "$memory" != "[not set]" ]]; then
        echo "Memory: $(numfmt --to=iec $memory)"
    fi
    
    # Process ID
    local pid=$(systemctl show "$service_name" --property=MainPID --value)
    if [[ -n "$pid" && "$pid" != "0" ]]; then
        echo "PID: $pid"
    fi
    
    # Ports
    local ports=$(get_service_ports "$service_name")
    if [[ -n "$ports" ]]; then
        echo "Ports: $ports"
        
        # Check port status
        for port in $ports; do
            if check_port "$port"; then
                echo -e "  Port $port: ${GREEN}Listening${NC}"
            else
                echo -e "  Port $port: ${RED}Not listening${NC}"
            fi
        done
    fi
    
    # Recent logs
    echo ""
    echo -e "${BLUE}Recent logs:${NC}"
    journalctl -u "$service_name" --lines=10 --no-pager -q 2>/dev/null || echo "No logs available"
    
    echo ""
}

# Function to export configuration
export_config() {
    local export_file="rathole_monitor_config.conf"
    
    cat > "$export_file" << EOF
# Rathole Monitor Configuration
# Generated on $(date)

# Monitoring settings
CHECK_INTERVAL=$CHECK_INTERVAL
MAX_RETRIES=$MAX_RETRIES
RETRY_DELAY=$RETRY_DELAY
ERROR_CHECK_PERIOD="$ERROR_CHECK_PERIOD"
MIN_CRITICAL_ERRORS=$MIN_CRITICAL_ERRORS
ERROR_FREQUENCY_THRESHOLD=$ERROR_FREQUENCY_THRESHOLD
ENABLE_SMART_ERROR_DETECTION=$ENABLE_SMART_ERROR_DETECTION

# Logging
LOG_FILE="$LOG_FILE"

# Services found
RATHOLE_SERVICES="$(get_rathole_services | tr '\n' ' ')"
EOF
    
    echo -e "${GREEN}Configuration exported to: $export_file${NC}"
}

# Function to import configuration
import_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}Configuration file not found: $config_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Importing configuration from: $config_file${NC}"
    
    # Source the configuration file
    source "$config_file"
    
    echo -e "${GREEN}Configuration imported successfully${NC}"
}

# Function to create backup
create_backup() {
    local backup_dir="/var/backups/rathole-monitor"
    local backup_file="$backup_dir/rathole-monitor-$(date +%Y%m%d_%H%M%S).tar.gz"
    
    # Create backup directory
    mkdir -p "$backup_dir"
    
    # Create temporary directory for backup
    local temp_dir=$(mktemp -d)
    
    # Copy important files
    cp "$0" "$temp_dir/rathole-monitor.sh" 2>/dev/null
    cp "$LOG_FILE" "$temp_dir/rathole-monitor.log" 2>/dev/null
    
    # Copy systemd service file if exists
    if [[ -f "/etc/systemd/system/rathole-monitor.service" ]]; then
        cp "/etc/systemd/system/rathole-monitor.service" "$temp_dir/"
    fi
    
    # Copy rathole configs
    mkdir -p "$temp_dir/configs"
    local services=$(get_rathole_services)
    for service in $services; do
        local config_file=$(systemctl show "$service" --property=ExecStart --value | grep -o '/[^[:space:]]*\.toml' | head -1)
        if [[ -f "$config_file" ]]; then
            cp "$config_file" "$temp_dir/configs/"
        fi
    done
    
    # Create backup archive
    tar -czf "$backup_file" -C "$temp_dir" .
    
    # Clean up
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}Backup created: $backup_file${NC}"
}

# Function to restore from backup
restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        echo -e "${RED}Backup file not found: $backup_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Restoring from backup: $backup_file${NC}"
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    
    # Extract backup
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Restore files
    if [[ -f "$temp_dir/rathole-monitor.sh" ]]; then
        cp "$temp_dir/rathole-monitor.sh" "$0"
        chmod +x "$0"
        echo -e "${GREEN}✓${NC} Script restored"
    fi
    
    if [[ -f "$temp_dir/rathole-monitor.log" ]]; then
        cp "$temp_dir/rathole-monitor.log" "$LOG_FILE"
        echo -e "${GREEN}✓${NC} Log file restored"
    fi
    
    if [[ -f "$temp_dir/rathole-monitor.service" ]]; then
        cp "$temp_dir/rathole-monitor.service" "/etc/systemd/system/"
        systemctl daemon-reload
        echo -e "${GREEN}✓${NC} Service file restored"
    fi
    
    # Restore configs
    if [[ -d "$temp_dir/configs" ]]; then
        echo -e "${GREEN}✓${NC} Configuration files found in backup"
        ls -la "$temp_dir/configs/"
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}Restore completed${NC}"
}

# Function to run diagnostics
run_diagnostics() {
    echo -e "${BLUE}=== Rathole Monitor Diagnostics ===${NC}"
    echo ""
    
    # System information
    echo -e "${BLUE}System Information:${NC}"
    echo "OS: $(uname -s) $(uname -r)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p)"
    echo "Date: $(date)"
    echo ""
    
    # Check dependencies
    echo -e "${BLUE}Dependencies:${NC}"
    local deps=("systemctl" "journalctl" "netstat" "grep" "awk" "sed")
    for dep in "${deps[@]}"; do
        if command -v "$dep" > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} $dep"
        else
            echo -e "${RED}✗${NC} $dep (missing)"
        fi
    done
    echo ""
    
    # Check permissions
    echo -e "${BLUE}Permissions:${NC}"
    if [[ $(id -u) -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} Running as root"
    else
        echo -e "${YELLOW}⚠${NC} Not running as root"
    fi
    
    # Check log file
    if [[ -f "$LOG_FILE" ]]; then
        if [[ -w "$LOG_FILE" ]]; then
            echo -e "${GREEN}✓${NC} Log file writable: $LOG_FILE"
        else
            echo -e "${RED}✗${NC} Log file not writable: $LOG_FILE"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Log file doesn't exist: $LOG_FILE"
    fi
    echo ""
    
    # Check services
    echo -e "${BLUE}Rathole Services:${NC}"
    local services=$(get_rathole_services)
    if [[ -n "$services" ]]; then
        for service in $services; do
            display_status "$service"
        done
    else
        echo -e "${YELLOW}⚠${NC} No rathole services found"
    fi
    echo ""
    
    # Network check
    echo -e "${BLUE}Network Status:${NC}"
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Internet connectivity"
    else
        echo -e "${RED}✗${NC} No internet connectivity"
    fi
    
    # Check listening ports
    echo -e "${BLUE}Listening Ports:${NC}"
    netstat -tuln | grep LISTEN | head -10
    echo ""
    
    # Disk space
    echo -e "${BLUE}Disk Usage:${NC}"
    df -h / | tail -1
    echo ""
    
    # Memory usage
    echo -e "${BLUE}Memory Usage:${NC}"
    free -h
    echo ""
    
    # Recent system errors
    echo -e "${BLUE}Recent System Errors:${NC}"
    journalctl -p err --since "1 hour ago" --no-pager -q | head -5 2>/dev/null || echo "No recent errors"
}

# Function to show version information
show_version() {
    echo "Rathole Tunnel Monitor Script"
    echo "Version: 2.0.0"
    echo "Author: System Administrator"
    echo "License: MIT"
    echo "Description: Automated monitoring and management script for Rathole tunnel services"
}

# Function to clean old logs
clean_logs() {
    local days="${1:-7}"
    
    echo -e "${BLUE}Cleaning logs older than $days days...${NC}"
    
    # Clean main log file
    if [[ -f "$LOG_FILE" ]]; then
        local temp_file=$(mktemp)
        local cutoff_date=$(date -d "$days days ago" '+%Y-%m-%d')
        
        # Keep only recent logs
        grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}" "$LOG_FILE" | \
        while IFS= read -r line; do
            local log_date=$(echo "$line" | cut -d' ' -f1)
            if [[ "$log_date" > "$cutoff_date" ]]; then
                echo "$line" >> "$temp_file"
            fi
        done
        
        # Replace original file
        mv "$temp_file" "$LOG_FILE"
        echo -e "${GREEN}✓${NC} Main log cleaned"
    fi
    
    # Clean journal logs for rathole services
    local services=$(get_rathole_services)
    for service in $services; do
        journalctl --vacuum-time="${days}d" --unit="$service" > /dev/null 2>&1
    done
    
    echo -e "${GREEN}✓${NC} Journal logs cleaned"
}

# Function to update script
update_script() {
    echo -e "${BLUE}Checking for script updates...${NC}"
    
    # Create backup of current script
    local backup_file="/tmp/rathole-monitor-backup-$(date +%Y%m%d_%H%M%S).sh"
    cp "$0" "$backup_file"
    
    echo -e "${GREEN}✓${NC} Current script backed up to: $backup_file"
    echo -e "${YELLOW}Update functionality would be implemented here${NC}"
    echo "Manual update: Replace this script with newer version"
}

# Enhanced help function with more options
show_help() {
    cat << EOF
${BLUE}Rathole Tunnel Monitor Script${NC}

${YELLOW}USAGE:${NC}
    $0 [OPTION] [ARGUMENTS]

${YELLOW}BASIC OPTIONS:${NC}
    monitor                 Run monitoring once
    daemon                  Run as daemon (continuous monitoring)
    status                  Show current status of all rathole services
    install                 Install as systemd service
    uninstall               Uninstall systemd service

${YELLOW}ADVANCED OPTIONS:${NC}
    details <service>       Show detailed information about a service
    test <service>          Test service configuration
    restart <service>       Restart specific service
    logs <service>          Show logs for specific service
    diagnostics             Run system diagnostics
    export                  Export current configuration
    import <file>           Import configuration from file
    backup                  Create backup of script and configs
    restore <file>          Restore from backup file
    clean [days]            Clean old logs (default: 7 days)
    update                  Check for script updates
    version                 Show version information

${YELLOW}EXAMPLES:${NC}
    $0 monitor                      # Run monitoring once
    $0 daemon                       # Run continuous monitoring
    $0 status                       # Show status of all services
    $0 details rathole-server       # Show details for specific service
    $0 test rathole-client          # Test service configuration
    $0 restart rathole-server       # Restart specific service
    $0 logs rathole-client          # Show logs for service
    $0 diagnostics                  # Run full diagnostics
    $0 clean 30                     # Clean logs older than 30 days
    $0 backup                       # Create backup
    $0 restore /path/to/backup.tar.gz # Restore from backup

${YELLOW}CONFIGURATION:${NC}
    Edit variables at the top of this script to customize behavior:
    - CHECK_INTERVAL: Time between checks (default: 300 seconds)
    - MAX_RETRIES: Maximum restart attempts (default: 3)
    - ERROR_CHECK_PERIOD: Time range for error analysis (default: 5 minutes)
    - LOG_FILE: Path to log file (default: /var/log/rathole_monitor.log)

${YELLOW}SERVICE MANAGEMENT:${NC}
    After installation as systemd service:
    - systemctl status rathole-monitor    # Check service status
    - systemctl start rathole-monitor     # Start service
    - systemctl stop rathole-monitor      # Stop service
    - systemctl restart rathole-monitor   # Restart service
    - journalctl -u rathole-monitor -f    # Follow service logs

EOF
}

# Enhanced main script logic with new options
case "${1:-status}" in
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
    details)
        if [[ -n "$2" ]]; then
            show_service_details "$2"
        else
            echo -e "${RED}Error: Please specify a service name${NC}"
            echo "Usage: $0 details <service_name>"
            exit 1
        fi
        ;;
    test)
        if [[ -n "$2" ]]; then
            test_service_config "$2"
        else
            echo -e "${RED}Error: Please specify a service name${NC}"
            echo "Usage: $0 test <service_name>"
            exit 1
        fi
        ;;
    restart)
        if [[ -n "$2" ]]; then
            restart_service "$2"
        else
            echo -e "${RED}Error: Please specify a service name${NC}"
            echo "Usage: $0 restart <service_name>"
            exit 1
        fi
        ;;
    logs)
        if [[ -n "$2" ]]; then
            echo -e "${BLUE}=== Logs for $2 ===${NC}"
            journalctl -u "$2" --no-pager -q 2>/dev/null || echo "No logs available"
        else
            echo -e "${RED}Error: Please specify a service name${NC}"
            echo "Usage: $0 logs <service_name>"
            exit 1
        fi
        ;;
    diagnostics)
        run_diagnostics
        ;;
    export)
        export_config
        ;;
    import)
        if [[ -n "$2" ]]; then
            import_config "$2"
        else
            echo -e "${RED}Error: Please specify a configuration file${NC}"
            echo "Usage: $0 import <config_file>"
            exit 1
        fi
        ;;
    backup)
        create_backup
        ;;
    restore)
        if [[ -n "$2" ]]; then
            restore_backup "$2"
        else
            echo -e "${RED}Error: Please specify a backup file${NC}"
            echo "Usage: $0 restore <backup_file>"
            exit 1
        fi
        ;;
    clean)
        clean_logs "${2:-7}"
        ;;
    update)
        update_script
        ;;
    version)
        show_version
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

# Exit with proper code
exit $?
