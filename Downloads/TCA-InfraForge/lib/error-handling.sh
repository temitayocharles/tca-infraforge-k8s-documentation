#!/bin/bash

# ============================================================================
# 🛡️ TC Enterprise DevOps Platform™ - Centralized Error Handling Library
# ============================================================================
#
# This library provides enterprise-grade error handling, logging, and recovery
# mechanisms for all deployment and validation scripts.
#
# Features:
# ✅ Centralized color scheme and emoji definitions
# ✅ Advanced retry mechanisms with exponential backoff
# ✅ Sophisticated timeout management
# ✅ Parallel execution helpers
# ✅ Comprehensive logging with multiple levels
# ✅ Automatic rollback and cleanup on failure
# ✅ Progress tracking and status reporting
# ✅ Cross-platform compatibility
#
# ============================================================================

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ This is a library file and should not be executed directly."
    echo "   Source it in your scripts: source lib/error-handling.sh"
    exit 1
fi

# ============================================================================
# 🎨 COLOR SCHEME & FORMATTING
# ============================================================================

# ANSI Color Codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Emoji Definitions
readonly CHECKMARK="✅"
readonly CROSS="❌"
readonly WARNING="⚠️"
readonly INFO="ℹ️"
readonly GEAR="⚙️"
readonly ROCKET="🚀"
readonly LOCK="🔒"
readonly NETWORK="🌐"
readonly DATABASE="🗄️"
readonly MONITOR="📊"
readonly CLOUD="☁️"
readonly SHIELD="🛡️"
readonly WRENCH="🔧"
readonly CLOCK="⏰"
readonly STAR="⭐"
readonly FIRE="🔥"
readonly BOMB="💣"
readonly RECYCLE="♻️"
readonly HOURGLASS="⏳"
readonly STOPWATCH="⏱️"
readonly TARGET="🎯"
readonly BULLSEYE="🎯"
readonly DART="🎯"

# ============================================================================
# 📊 GLOBAL CONFIGURATION
# ============================================================================

# Default retry configuration
readonly DEFAULT_MAX_RETRIES=3
readonly DEFAULT_RETRY_DELAY=5
readonly DEFAULT_TIMEOUT=300
readonly DEFAULT_BACKOFF_MULTIPLIER=2

# Logging configuration
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=4

# Set default log level
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Global state tracking
typeset -a ACTIVE_PROCESSES
typeset -A COMPONENT_STATUS
typeset -A COMPONENT_START_TIME
typeset -A COMPONENT_PID
typeset -A ROLLBACK_FUNCTIONS

# ============================================================================
# 📝 LOGGING FUNCTIONS
# ============================================================================

# Get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Get ISO timestamp for logs
get_iso_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

# Core logging function
_log() {
    local level=$1
    local level_num=$2
    local message=$3
    local component=${4:-"SYSTEM"}
    local timestamp=$(get_timestamp)

    # Check if we should log this level
    if [[ $level_num -lt $LOG_LEVEL ]]; then
        return 0
    fi

    # Format message
    local formatted_message="[$timestamp] [$component] [$level] $message"

    # Output to console
    echo -e "$formatted_message"

    # Log to file if LOG_FILE is set
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "$formatted_message" >> "$LOG_FILE"
    fi
}

# Public logging functions
log_debug() { _log "DEBUG" $LOG_LEVEL_DEBUG "$1" "${2:-}"; }
log_info()  { _log "INFO"  $LOG_LEVEL_INFO  "$1" "${2:-}"; }
log_warn()  { _log "WARN"  $LOG_LEVEL_WARN  "$1" "${2:-}"; }
log_error() { _log "ERROR" $LOG_LEVEL_ERROR "$1" "${2:-}"; }
log_fatal() { _log "FATAL" $LOG_LEVEL_FATAL "$1" "${2:-}"; }

# ============================================================================
# 🎨 USER-FACING OUTPUT FUNCTIONS
# ============================================================================

# Progress and status functions
print_header() {
    echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} $1 ${BLUE}$(printf '%*s' $((70-${#1})) '')║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
}

print_step() {
    local current=$1
    local total=$2
    local message=$3
    echo -e "${CYAN}${GEAR} STEP ${current}/${total}:${NC} $message"
}

print_success() {
    echo -e "${GREEN}${CHECKMARK} SUCCESS:${NC} $1"
}

print_error() {
    echo -e "${RED}${CROSS} ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}${WARNING} WARNING:${NC} $1"
}

print_info() {
    echo -e "${BLUE}${INFO} INFO:${NC} $1"
}

print_progress() {
    echo -e "${MAGENTA}${CLOCK} PROGRESS:${NC} $1"
}

print_debug() {
    if [[ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        echo -e "${GRAY}${WRENCH} DEBUG:${NC} $1"
    fi
}

# ============================================================================
# 🔄 RETRY MECHANISMS
# ============================================================================

# Execute command with retry logic
retry_command() {
    local command="$1"
    local max_retries=${2:-$DEFAULT_MAX_RETRIES}
    local delay=${3:-$DEFAULT_RETRY_DELAY}
    local backoff_multiplier=${4:-$DEFAULT_BACKOFF_MULTIPLIER}
    local description=${5:-"command"}
    local current_delay=$delay
    local attempt=1

    while [[ $attempt -le $max_retries ]]; do
        log_info "Attempting $description (attempt $attempt/$max_retries)" "RETRY"

        if eval "$command"; then
            log_info "✓ $description succeeded on attempt $attempt" "RETRY"
            return 0
        else
            local exit_code=$?
            log_warn "✗ $description failed on attempt $attempt (exit code: $exit_code)" "RETRY"

            if [[ $attempt -lt $max_retries ]]; then
                log_info "⏳ Retrying in ${current_delay}s..." "RETRY"
                sleep $current_delay
                current_delay=$((current_delay * backoff_multiplier))
            fi
        fi

        ((attempt++))
    done

    log_error "❌ $description failed after $max_retries attempts" "RETRY"
    return 1
}

# Execute command with timeout
timeout_command() {
    local timeout=${1:-$DEFAULT_TIMEOUT}
    local command="${2:-}"
    local description=${3:-"command"}

    log_debug "Executing with ${timeout}s timeout: $description" "TIMEOUT"

    # Use timeout command if available, otherwise implement basic timeout
    if command -v timeout &> /dev/null; then
        if timeout $timeout bash -c "$command"; then
            log_debug "✓ $description completed within timeout" "TIMEOUT"
            return 0
        else
            log_error "❌ $description timed out after ${timeout}s" "TIMEOUT"
            return 1
        fi
    else
        # Fallback timeout implementation
        local pid
        eval "$command" &
        pid=$!

        local count=0
        while [[ $count -lt $timeout ]] && kill -0 $pid 2>/dev/null; do
            sleep 1
            ((count++))
        done

        if kill -0 $pid 2>/dev/null; then
            kill -TERM $pid 2>/dev/null || kill -KILL $pid 2>/dev/null
            log_error "❌ $description timed out after ${timeout}s" "TIMEOUT"
            return 1
        else
            wait $pid 2>/dev/null
            local exit_code=$?
            if [[ $exit_code -eq 0 ]]; then
                log_debug "✓ $description completed within timeout" "TIMEOUT"
                return 0
            else
                log_error "❌ $description failed with exit code $exit_code" "TIMEOUT"
                return $exit_code
            fi
        fi
    fi
}

# ============================================================================
# ⚡ PARALLEL EXECUTION HELPERS
# ============================================================================

# Execute commands in parallel with progress tracking
parallel_execute() {
    local commands=("$@")
    local pids=()
    local results=()
    local descriptions=()

    # Extract descriptions and commands
    for cmd in "${commands[@]}"; do
        if [[ $cmd == *"|DESC|"* ]]; then
            descriptions+=("${cmd%%|DESC|*}")
            pids+=("${cmd##*|DESC|}")
        else
            descriptions+=("Task $(( ${#pids[@]} + 1 ))")
            pids+=("$cmd")
        fi
    done

    log_info "Starting ${#pids[@]} parallel tasks" "PARALLEL"

    # Start all commands in background
    local background_pids=()
    for i in "${!pids[@]}"; do
        eval "${pids[$i]}" &
        background_pids+=($!)
        log_debug "Started task: ${descriptions[$i]} (PID: $!)" "PARALLEL"
    done

    # Wait for all to complete with progress updates
    local completed=0
    local total=${#background_pids[@]}

    while [[ $completed -lt $total ]]; do
        local still_running=0
        for pid in "${background_pids[@]}"; do
            if kill -0 $pid 2>/dev/null; then
                ((still_running++))
            fi
        done

        if [[ $still_running -gt 0 ]]; then
            print_progress "Parallel execution: $((total - still_running))/$total tasks completed"
            sleep 2
        else
            completed=$total
        fi
    done

    # Collect results
    local failed=0
    for i in "${!background_pids[@]}"; do
        wait "${background_pids[$i]}" 2>/dev/null
        local exit_code=$?
        results[$i]=$exit_code

        if [[ $exit_code -eq 0 ]]; then
            log_info "✓ ${descriptions[$i]} completed successfully" "PARALLEL"
        else
            log_error "✗ ${descriptions[$i]} failed (exit code: $exit_code)" "PARALLEL"
            ((failed++))
        fi
    done

    if [[ $failed -eq 0 ]]; then
        log_info "✅ All parallel tasks completed successfully" "PARALLEL"
        return 0
    else
        log_error "❌ $failed out of $total parallel tasks failed" "PARALLEL"
        return 1
    fi
}

# ============================================================================
# 🔄 ROLLBACK AND CLEANUP
# ============================================================================

# Register a rollback function
register_rollback() {
    local name="$1"
    local function_name="$2"
    ROLLBACK_FUNCTIONS["$name"]="$function_name"
    log_debug "Registered rollback function: $name -> $function_name" "ROLLBACK"
}

# Execute rollback for specific component
rollback_component() {
    local component="$1"

    if [[ -n "${ROLLBACK_FUNCTIONS[$component]:-}" ]]; then
        local rollback_func="${ROLLBACK_FUNCTIONS[$component]}"
        log_warn "Executing rollback for $component" "ROLLBACK"

        if eval "$rollback_func"; then
            log_info "✓ Rollback completed for $component" "ROLLBACK"
        else
            log_error "✗ Rollback failed for $component" "ROLLBACK"
        fi
    else
        log_debug "No rollback function registered for $component" "ROLLBACK"
    fi
}

# Execute all registered rollbacks
rollback_all() {
    log_warn "Executing full rollback for all components" "ROLLBACK"

    local failed_rollbacks=0
    for component in "${!ROLLBACK_FUNCTIONS[@]}"; do
        if ! rollback_component "$component"; then
            ((failed_rollbacks++))
        fi
    done

    if [[ $failed_rollbacks -eq 0 ]]; then
        log_info "✅ Full rollback completed successfully" "ROLLBACK"
        return 0
    else
        log_error "❌ $failed_rollbacks rollbacks failed" "ROLLBACK"
        return 1
    fi
}

# Cleanup function for temporary files and processes
cleanup() {
    log_info "Starting cleanup process" "CLEANUP"

    # Kill any remaining background processes
    for pid in "${ACTIVE_PROCESSES[@]}"; do
        if kill -0 $pid 2>/dev/null; then
            log_debug "Terminating process $pid" "CLEANUP"
            kill -TERM $pid 2>/dev/null || kill -KILL $pid 2>/dev/null
        fi
    done

    # Execute rollbacks if any components are in failed state
    local failed_components=()
    for component in "${!COMPONENT_STATUS[@]}"; do
        if [[ "${COMPONENT_STATUS[$component]}" == "failed" ]]; then
            failed_components+=("$component")
        fi
    done

    if [[ ${#failed_components[@]} -gt 0 ]]; then
        log_warn "Found ${#failed_components[@]} failed components, executing rollbacks" "CLEANUP"
        for component in "${failed_components[@]}"; do
            rollback_component "$component"
        done
    fi

    # Clean up temporary files
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        log_debug "Cleaning up temporary directory: $TEMP_DIR" "CLEANUP"
        rm -rf "$TEMP_DIR"
    fi

    log_info "✅ Cleanup completed" "CLEANUP"
}

# Set up cleanup trap
setup_cleanup_trap() {
    trap cleanup EXIT INT TERM
    log_debug "Cleanup trap configured for signals: EXIT, INT, TERM" "CLEANUP"
}

# ============================================================================
# 📊 COMPONENT TRACKING
# ============================================================================

# Start tracking a component
start_component() {
    local component="$1"
    COMPONENT_STATUS["$component"]="running"
    COMPONENT_START_TIME["$component"]=$(date +%s)
    log_info "Started component: $component" "COMPONENT"
}

# Mark component as completed successfully
complete_component() {
    local component="$1"
    COMPONENT_STATUS["$component"]="completed"
    local start_time="${COMPONENT_START_TIME[$component]:-0}"
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_info "✓ Component $component completed successfully (${duration}s)" "COMPONENT"
}

# Mark component as failed
fail_component() {
    local component="$1"
    local error_message="${2:-Unknown error}"
    COMPONENT_STATUS["$component"]="failed"
    log_error "✗ Component $component failed: $error_message" "COMPONENT"
}

# Get component status
get_component_status() {
    local component="$1"
    echo "${COMPONENT_STATUS[$component]:-unknown}"
}

# Generate status report
generate_status_report() {
    local report_file="${1:-status-report.json}"

    local report_data="{
  \"generated_at\": \"$(get_iso_timestamp)\",
  \"components\": {"

    local first=true
    for component in "${!COMPONENT_STATUS[@]}"; do
        if [[ $first == true ]]; then
            first=false
        else
            report_data+=","
        fi

        local status="${COMPONENT_STATUS[$component]}"
        local start_time="${COMPONENT_START_TIME[$component]:-0}"
        local duration="null"

        if [[ $start_time -gt 0 ]]; then
            local current_time=$(date +%s)
            duration=$((current_time - start_time))
        fi

        report_data+="
    \"$component\": {
      \"status\": \"$status\",
      \"start_time\": $start_time,
      \"duration_seconds\": $duration
    }"
    done

    report_data+="
  }
}"

    echo "$report_data" > "$report_file"
    log_info "Status report generated: $report_file" "REPORT"
}

# ============================================================================
# 🔍 VALIDATION HELPERS
# ============================================================================

# Validate required tools
validate_tools() {
    local tools=("$@")
    local missing_tools=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}" "VALIDATION"
        return 1
    else
        log_info "✓ All required tools are available" "VALIDATION"
        return 0
    fi
}

# Validate system resources
validate_resources() {
    local min_memory_gb=${1:-4}
    local min_cpu_cores=${2:-2}

    # Check memory
    local total_memory_bytes
    if [[ "$OSTYPE" == "darwin"* ]]; then
        total_memory_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    else
        total_memory_bytes=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2*1024}' || echo "0")
    fi

    local total_memory_gb=$((total_memory_bytes / 1024 / 1024 / 1024))

    if [[ $total_memory_gb -lt $min_memory_gb ]]; then
        log_error "Insufficient memory: ${total_memory_gb}GB (minimum ${min_memory_gb}GB required)" "VALIDATION"
        return 1
    fi

    # Check CPU cores
    local cpu_cores
    if [[ "$OSTYPE" == "darwin"* ]]; then
        cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "1")
    else
        cpu_cores=$(nproc 2>/dev/null || echo "1")
    fi

    if [[ $cpu_cores -lt $min_cpu_cores ]]; then
        log_error "Insufficient CPU cores: $cpu_cores (minimum $min_cpu_cores required)" "VALIDATION"
        return 1
    fi

    log_info "✓ System resources validated: ${total_memory_gb}GB RAM, $cpu_cores CPU cores" "VALIDATION"
    return 0
}

# ============================================================================
# 🎯 UTILITY FUNCTIONS
# ============================================================================

# Create temporary directory
create_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    log_debug "Created temporary directory: $TEMP_DIR" "UTILS"
    echo "$TEMP_DIR"
}

# Get script directory
get_script_dir() {
    local script_path="${BASH_SOURCE[1]}"
    local script_dir="$(cd "$(dirname "$script_path")" && pwd)"
    echo "$script_dir"
}

# Get project root directory
get_project_root() {
    local script_dir=$(get_script_dir)
    local project_root="$script_dir"

    # Try to find project root by looking for common markers
    while [[ "$project_root" != "/" ]]; do
        if [[ -f "$project_root/README.md" || -f "$project_root/package.json" || -f "$project_root/.git" ]]; then
            echo "$project_root"
            return 0
        fi
        project_root=$(dirname "$project_root")
    done

    # Fallback to current directory
    echo "$(pwd)"
}

# ============================================================================
# 🎉 INITIALIZATION
# ============================================================================

# Initialize the library
init_error_handling() {
    # Set up cleanup trap
    setup_cleanup_trap

    # Create temp directory if needed
    if [[ -z "${TEMP_DIR:-}" ]]; then
        TEMP_DIR=$(create_temp_dir)
    fi

    # Set strict mode if not already set
    if [[ "${BASHOPTS:-}" != *"errexit"* ]]; then
        set -e
    fi

    log_info "🛡️ Error handling library initialized" "INIT"
}

# Auto-initialize if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_error_handling
fi

# ============================================================================
# 📚 USAGE EXAMPLES
# ============================================================================
#
# Basic usage:
#   source lib/error-handling.sh
#
# Retry a command:
#   retry_command "kubectl get nodes" 3 5 2 "check cluster nodes"
#
# Timeout a command:
#   timeout_command 60 "sleep 30" "long running task"
#
# Parallel execution:
#   parallel_execute \
#     "echo 'Task 1' |DESC|sleep 2" \
#     "echo 'Task 2' |DESC|sleep 3"
#
# Component tracking:
#   start_component "database"
#   # ... do work ...
#   complete_component "database"
#
# Rollback registration:
#   register_rollback "database" "cleanup_database"
#
# ============================================================================
