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
    "
    fi#!/bin/bash

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
    "Connection attempt failed 1 time"
    "Connection attempt failed 2 times"
    "Connection attempt failed 3 times"
    "Connection attempt failed 4 times"
    "Connection attempt failed 5 times"
    "Connection attempt failed 6 times"
    "Connection attempt failed 7 times"
    "Connection attempt failed 8 times"
    "Connection attempt failed 9 times"
    "Connection attempt failed 10 times"
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
    "failed to open"
    "failed to create"
    "failed to write"
    "failed to read"
    "failed to close"
    "failed to flush"
    "failed to seek"
    "failed to stat"
    "failed to sync"
    "failed to lock"
    "failed to unlock"
    "failed to allocate"
    "failed to free"
    "failed to initialize"
    "failed to cleanup"
    "failed to finalize"
    "failed to destroy"
    "failed to create thread"
    "failed to join thread"
    "failed to spawn thread"
    "failed to send"
    "failed to receive"
    "failed to process"
    "failed to execute"
    "failed to run"
    "failed to start process"
    "failed to stop process"
    "failed to kill process"
    "failed to restart process"
    "failed to reload"
    "failed to update"
    "failed to upgrade"
    "failed to downgrade"
    "failed to install"
    "failed to uninstall"
    "failed to configure"
    "failed to setup"
    "failed to init"
    "failed to boot"
    "failed to shutdown"
    "failed to reboot"
    "failed to mount"
    "failed to unmount"
    "failed to format"
    "failed to backup"
    "failed to restore"
    "failed to recover"
    "failed to repair"
    "failed to validate"
    "failed to verify"
    "failed to authenticate"
    "failed to authorize"
    "failed to login"
    "failed to logout"
    "failed to register"
    "failed to unregister"
    "failed to enable"
    "failed to disable"
    "failed to activate"
    "failed to deactivate"
    "failed to suspend"
    "failed to resume"
    "failed to pause"
    "failed to continue"
    "failed to stop"
    "failed to start"
    "failed to restart"
    "failed to reload"
    "failed to reset"
    "failed to clear"
    "failed to flush"
    "failed to sync"
    "failed to commit"
    "failed to rollback"
    "failed to save"
    "failed to load"
    "failed to import"
    "failed to export"
    "failed to copy"
    "failed to move"
    "failed to delete"
    "failed to remove"
    "failed to rename"
    "failed to create directory"
    "failed to create file"
    "failed to delete directory"
    "failed to delete file"
    "failed to read directory"
    "failed to read file"
    "failed to write directory"
    "failed to write file"
    "failed to access directory"
    "failed to access file"
    "failed to find directory"
    "failed to find file"
    "failed to open directory"
    "failed to open file"
    "failed to close directory"
    "failed to close file"
    "failed to lock directory"
    "failed to lock file"
    "failed to unlock directory"
    "failed to unlock file"
    "failed to chmod"
    "failed to chown"
    "failed to chgrp"
    "failed to link"
    "failed to symlink"
    "failed to unlink"
    "failed to stat"
    "failed to lstat"
    "failed to fstat"
    "failed to truncate"
    "failed to expand"
    "failed to compress"
    "failed to decompress"
    "failed to archive"
    "failed to unarchive"
    "failed to encrypt"
    "failed to decrypt"
    "failed to hash"
    "failed to checksum"
    "failed to generate"
    "failed to compute"
    "failed to calculate"
    "failed to measure"
    "failed to test"
    "failed to check"
    "failed to validate"
    "failed to verify"
    "failed to confirm"
    "failed to ensure"
    "failed to assert"
    "failed to evaluate"
    "failed to analyze"
    "failed to diagnose"
    "failed to debug"
    "failed to trace"
    "failed to profile"
    "failed to monitor"
    "failed to watch"
    "failed to observe"
    "failed to track"
    "failed to follow"
    "failed to inspect"
    "failed to examine"
    "failed to investigate"
    "failed to explore"
    "failed to discover"
    "failed to search"
    "failed to find"
    "failed to locate"
    "failed to retrieve"
    "failed to fetch"
    "failed to get"
    "failed to obtain"
    "failed to acquire"
    "failed to collect"
    "failed to gather"
    "failed to compile"
    "failed to build"
    "failed to make"
    "failed to create"
    "failed to generate"
    "failed to produce"
    "failed to construct"
    "failed to assemble"
    "failed to link"
    "failed to package"
    "failed to deploy"
    "failed to release"
    "failed to publish"
    "failed to distribute"
    "failed to install"
    "failed to uninstall"
    "failed to setup"
    "failed to configure"
    "failed to customize"
    "failed to adapt"
    "failed to adjust"
    "failed to modify"
    "failed to change"
    "failed to update"
    "failed to upgrade"
    "failed to downgrade"
    "failed to migrate"
    "failed to convert"
    "failed to transform"
    "failed to format"
    "failed to parse"
    "failed to serialize"
    "failed to deserialize"
    "failed to encode"
    "failed to decode"
    "failed to compress"
    "failed to decompress"
    "failed to zip"
    "failed to unzip"
    "failed to tar"
    "failed to untar"
    "failed to gzip"
    "failed to gunzip"
    "failed to encrypt"
    "failed to decrypt"
    "failed to sign"
    "failed to verify signature"
    "failed to hash"
    "failed to checksum"
    "failed to validate checksum"
    "failed to compare"
    "failed to match"
    "failed to filter"
    "failed to sort"
    "failed to group"
    "failed to aggregate"
    "failed to summarize"
    "failed to reduce"
    "failed to map"
    "failed to transform"
    "failed to apply"
    "failed to execute"
    "failed to run"
    "failed to call"
    "failed to invoke"
    "failed to trigger"
    "failed to fire"
    "failed to emit"
    "failed to broadcast"
    "failed to publish"
    "failed to subscribe"
    "failed to unsubscribe"
    "failed to notify"
    "failed to alert"
    "failed to warn"
    "failed to report"
    "failed to log"
    "failed to record"
    "failed to store"
    "failed to persist"
    "failed to commit"
    "failed to save"
    "failed to backup"
    "failed to restore"
    "failed to recover"
    "failed to repair"
    "failed to fix"
    "failed to resolve"
    "failed to solve"
    "failed to handle"
    "failed to process"
    "failed to manage"
    "failed to control"
    "failed to operate"
    "failed to function"
    "failed to work"
    "failed to perform"
    "failed to execute"
    "failed to complete"
    "failed to finish"
    "failed to done"
    "failed to succeed"
    "failed to fail"
    "failed to error"
    "failed to crash"
    "failed to exit"
    "failed to terminate"
    "failed to quit"
    "failed to stop"
    "failed to end"
    "failed to close"
    "failed to shutdown"
    "failed to restart"
    "failed to reboot"
    "failed to reset"
    "failed to clear"
    "failed to flush"
    "failed to sync"
    "failed to wait"
    "failed to sleep"
    "failed to pause"
    "failed to resume"
    "failed to continue"
    "failed to yield"
    "failed to return"
    "failed to respond"
    "failed to reply"
    "failed to answer"
    "failed to acknowledge"
    "failed to confirm"
    "failed to accept"
    "failed to reject"
    "failed to deny"
    "failed to allow"
    "failed to permit"
    "failed to grant"
    "failed to revoke"
    "failed to authorize"
    "failed to authenticate"
    "failed to login"
    "failed to logout"
    "failed to register"
    "failed to unregister"
    "failed to subscribe"
    "failed to unsubscribe"
    "failed to connect"
    "failed to disconnect"
    "failed to bind"
    "failed to unbind"
    "failed to attach"
    "failed to detach"
    "failed to associate"
    "failed to disassociate"
    "failed to link"
    "failed to unlink"
    "failed to couple"
    "failed to decouple"
    "failed to join"
    "failed to leave"
    "failed to enter"
    "failed to exit"
    "failed to open"
    "failed to close"
    "failed to lock"
    "failed to unlock"
    "failed to acquire"
    "failed to release"
    "failed to allocate"
    "failed to free"
    "failed to reserve"
    "failed to unreserve"
    "failed to claim"
    "failed to unclaim"
    "failed to take"
    "failed to give"
    "failed to get"
    "failed to set"
    "failed to put"
    "failed to push"
    "failed to pop"
    "failed to peek"
    "failed to insert"
    "failed to remove"
    "failed to delete"
    "failed to add"
    "failed to append"
    "failed to prepend"
    "failed to concat"
    "failed to merge"
    "failed to split"
    "failed to slice"
    "failed to cut"
    "failed to copy"
    "failed to move"
    "failed to swap"
    "failed to replace"
    "failed to substitute"
    "failed to change"
    "failed to modify"
    "failed to update"
    "failed to upgrade"
    "failed to downgrade"
    "failed to migrate"
    "failed to convert"
    "failed to transform"
    "failed to format"
    "failed to parse"
    "failed to serialize"
    "failed to deserialize"
    "config validation failed"
    "invalid configuration"
    "configuration syntax error"
    "missing configuration"
    "configuration file not found"
    "configuration parse error"
    "configuration load error"
    "configuration read error"
    "configuration write error"
    "configuration save error"
    "configuration backup error"
    "configuration restore error"
    "configuration validation error"
    "configuration check error"
    "configuration test error"
    "configuration apply error"
    "configuration update error"
    "configuration upgrade error"
    "configuration downgrade error"
    "configuration migration error"
    "configuration conversion error"
    "configuration transformation error"
    "configuration format error"
    "configuration parse error"
    "configuration serialization error"
    "configuration deserialization error"
    "configuration encoding error"
    "configuration decoding error"
    "configuration compression error"
    "configuration decompression error"
    "configuration encryption error"
    "configuration decryption error"
    "configuration signing error"
    "configuration verification error"
    "configuration hash error"
    "configuration checksum error"
    "configuration validation error"
    "configuration comparison error"
    "configuration match error"
    "configuration filter error"
    "configuration sort error"
    "configuration group error"
    "configuration aggregate error"
    "configuration summarize error"
    "configuration reduce error"
    "configuration map error"
    "configuration transform error"
    "configuration apply error"
    "configuration execute error"
    "configuration run error"
    "configuration call error"
    "configuration invoke error"
    "configuration trigger error"
    "configuration fire error"
    "configuration emit error"
    "configuration broadcast error"
    "configuration publish error"
    "configuration subscribe error"
    "configuration unsubscribe error"
    "configuration notify error"
    "configuration alert error"
    "configuration warn error"
    "configuration report error"
    "configuration log error"
    "configuration record error"
    "configuration store error"
    "configuration persist error"
    "configuration commit error"
    "configuration save error"
    "configuration backup error"
    "configuration restore error"
    "configuration recover error"
    "configuration repair error"
    "configuration fix error"
    "configuration resolve error"
    "configuration solve error"
    "configuration handle error"
    "configuration process error"
    "configuration manage error"
    "configuration control error"
    "configuration operate error"
    "configuration function error"
    "configuration work error"
    "configuration perform error"
    "configuration execute error"
    "configuration complete error"
    "configuration finish error"
    "configuration done error"
    "configuration success error"
    "configuration fail error"
    "configuration error error"
    "configuration crash error"
    "configuration exit error"
    "configuration terminate error"
    "configuration quit error"
    "configuration stop error"
    "configuration end error"
    "configuration close error"
    "configuration shutdown error"
    "configuration restart error"
    "configuration reboot error"
    "configuration reset error"
    "configuration clear error"
    "configuration flush error"
    "configuration sync error"
    "configuration wait error"
    "configuration sleep error"
    "configuration pause error"
    "configuration resume error"
    "configuration continue error"
    "configuration yield error"
    "configuration return error"
    "configuration respond error"
    "configuration reply error"
    "configuration answer error"
    "configuration acknowledge error"
    "configuration confirm error"
    "configuration accept error"
    "configuration reject error"
    "configuration deny error"
    "configuration allow error"
    "configuration permit error"
    "configuration grant error"
    "configuration revoke error"
    "configuration authorize error"
    "configuration authenticate error"
    "configuration login error"
    "configuration logout error"
    "configuration register error"
    "configuration unregister error"
    "configuration subscribe error"
    "configuration unsubscribe error"
    "configuration connect error"
    "configuration disconnect error"
    "configuration bind error"
    "configuration unbind error"
    "configuration attach error"
    "configuration detach error"
    "configuration associate error"
    "configuration disassociate error"
    "configuration link error"
    "configuration unlink error"
    "configuration couple error"
    "configuration decouple error"
    "configuration join error"
    "configuration leave error"
    "configuration enter error"
    "configuration exit error"
    "configuration open error"
    "configuration close error"
    "configuration lock error"
    "configuration unlock error"
    "configuration acquire error"
    "configuration release error"
    "configuration allocate error"
    "configuration free error"
    "configuration reserve error"
    "configuration unreserve error"
    "configuration claim error"
    "configuration unclaim error"
    "configuration take error"
    "configuration give error"
    "configuration get error"
    "configuration set error"
    "configuration put error"
    "configuration push error"
    "configuration pop error"
    "configuration peek error"
    "configuration insert error"
    "configuration remove error"
    "configuration delete error"
    "configuration add error"
    "configuration append error"
    "configuration prepend error"
    "configuration concat error"
    "configuration merge error"
    "configuration split error"
    "configuration slice error"
    "configuration cut error"
    "configuration copy error"
    "configuration move error"
    "configuration swap error"
    "configuration replace error"
    "configuration substitute error"
    "configuration change error"
    "configuration modify error"
    "configuration update error"
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
