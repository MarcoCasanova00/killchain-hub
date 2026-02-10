#!/bin/bash
# Centralized Logging Library for Killchain-Hub
# Usage: source lib/logger.sh

# Colors
LOG_RED='\033[0;31m'
LOG_GREEN='\033[0;32m'
LOG_YELLOW='\033[1;33m'
LOG_BLUE='\033[0;34m'
LOG_CYAN='\033[0;36m'
LOG_NC='\033[0m'

# Global log file paths (set by main script)
LOG_SESSION_FILE=""
LOG_ERROR_FILE=""
LOG_VERBOSE=0

# Initialize logging for a session
# Usage: init_logging "/path/to/session/dir"
init_logging() {
    local session_dir="$1"
    
    if [ -z "$session_dir" ]; then
        echo -e "${LOG_RED}ERROR: init_logging requires session directory${LOG_NC}" >&2
        return 1
    fi
    
    # Create session directory if it doesn't exist
    mkdir -p "$session_dir" 2>/dev/null || {
        echo -e "${LOG_RED}ERROR: Cannot create session directory: $session_dir${LOG_NC}" >&2
        return 1
    }
    
    LOG_SESSION_FILE="$session_dir/session.log"
    LOG_ERROR_FILE="$session_dir/errors.log"
    
    # Initialize log files
    echo "=== Killchain-Hub Session Log ===" > "$LOG_SESSION_FILE"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_SESSION_FILE"
    echo "User: $(whoami)" >> "$LOG_SESSION_FILE"
    echo "==============================" >> "$LOG_SESSION_FILE"
    echo "" >> "$LOG_SESSION_FILE"
    
    echo "=== Error Log ===" > "$LOG_ERROR_FILE"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_ERROR_FILE"
    echo "=================" >> "$LOG_ERROR_FILE"
    echo "" >> "$LOG_ERROR_FILE"
    
    return 0
}

# Get timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Log info message
# Usage: log_info "message"
log_info() {
    local msg="$1"
    local timestamp=$(get_timestamp)
    
    echo -e "${LOG_BLUE}[INFO]${LOG_NC} $msg"
    
    if [ -n "$LOG_SESSION_FILE" ]; then
        echo "[$timestamp] [INFO] $msg" >> "$LOG_SESSION_FILE"
    fi
}

# Log success message
# Usage: log_success "message"
log_success() {
    local msg="$1"
    local timestamp=$(get_timestamp)
    
    echo -e "${LOG_GREEN}[✓]${LOG_NC} $msg"
    
    if [ -n "$LOG_SESSION_FILE" ]; then
        echo "[$timestamp] [SUCCESS] $msg" >> "$LOG_SESSION_FILE"
    fi
}

# Log warning message
# Usage: log_warning "message"
log_warning() {
    local msg="$1"
    local timestamp=$(get_timestamp)
    
    echo -e "${LOG_YELLOW}[WARNING]${LOG_NC} $msg"
    
    if [ -n "$LOG_SESSION_FILE" ]; then
        echo "[$timestamp] [WARNING] $msg" >> "$LOG_SESSION_FILE"
    fi
}

# Log error message
# Usage: log_error "message"
log_error() {
    local msg="$1"
    local timestamp=$(get_timestamp)
    
    echo -e "${LOG_RED}[ERROR]${LOG_NC} $msg" >&2
    
    if [ -n "$LOG_SESSION_FILE" ]; then
        echo "[$timestamp] [ERROR] $msg" >> "$LOG_SESSION_FILE"
    fi
    
    if [ -n "$LOG_ERROR_FILE" ]; then
        echo "[$timestamp] $msg" >> "$LOG_ERROR_FILE"
    fi
}

# Log command execution
# Usage: log_command "command description" "actual command"
log_command() {
    local description="$1"
    local command="$2"
    local timestamp=$(get_timestamp)
    
    log_info "Executing: $description"
    
    if [ -n "$LOG_SESSION_FILE" ]; then
        echo "[$timestamp] [COMMAND] $description" >> "$LOG_SESSION_FILE"
        echo "[$timestamp] [CMD_RAW] $command" >> "$LOG_SESSION_FILE"
    fi
    
    # Execute command and capture output
    if [ "$LOG_VERBOSE" -eq 1 ]; then
        eval "$command" 2>&1 | tee -a "$LOG_SESSION_FILE"
        local exit_code=${PIPESTATUS[0]}
    else
        eval "$command" >> "$LOG_SESSION_FILE" 2>&1
        local exit_code=$?
    fi
    
    if [ $exit_code -eq 0 ]; then
        log_success "$description completed"
    else
        log_error "$description failed with exit code $exit_code"
    fi
    
    return $exit_code
}

# Log verbose message (only shown if verbose mode enabled)
# Usage: log_verbose "message"
log_verbose() {
    local msg="$1"
    local timestamp=$(get_timestamp)
    
    if [ "$LOG_VERBOSE" -eq 1 ]; then
        echo -e "${LOG_CYAN}[VERBOSE]${LOG_NC} $msg"
    fi
    
    if [ -n "$LOG_SESSION_FILE" ]; then
        echo "[$timestamp] [VERBOSE] $msg" >> "$LOG_SESSION_FILE"
    fi
}

# Enable verbose logging
enable_verbose() {
    LOG_VERBOSE=1
    log_info "Verbose logging enabled"
}

# Finalize logging session
# Usage: finalize_logging
finalize_logging() {
    local timestamp=$(get_timestamp)
    
    if [ -n "$LOG_SESSION_FILE" ]; then
        echo "" >> "$LOG_SESSION_FILE"
        echo "==============================" >> "$LOG_SESSION_FILE"
        echo "Ended: $timestamp" >> "$LOG_SESSION_FILE"
        echo "=== End of Session ===" >> "$LOG_SESSION_FILE"
    fi
    
    log_success "Session logs saved to: $LOG_SESSION_FILE"
    
    # Show error count if any
    if [ -f "$LOG_ERROR_FILE" ]; then
        local error_count=$(grep -c "^\[" "$LOG_ERROR_FILE" 2>/dev/null)
        # Handle empty result (grep error) or ensure valid integer
        [[ -z "$error_count" ]] && error_count=0
        
        if [ "$error_count" -gt 1 ]; then  # More than just the header
            log_warning "Errors logged: $((error_count - 1)) - see $LOG_ERROR_FILE"
        fi
    fi
}

# Export functions for use in other scripts
export -f init_logging
export -f get_timestamp
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_command
export -f log_verbose
export -f enable_verbose
export -f finalize_logging
