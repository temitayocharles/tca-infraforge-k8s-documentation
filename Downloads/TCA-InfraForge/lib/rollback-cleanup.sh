#!/bin/bash

# ============================================================================
# 🔄 TC Enterprise DevOps Platform™ - Rollback & Cleanup Library
# ============================================================================
#
# This library provides comprehensive rollback and cleanup capabilities
# for deployment operations, ensuring reliable recovery from failures.
#
# Features:
# ✅ Automatic rollback on deployment failures
# ✅ Component-specific cleanup functions
# ✅ Resource cleanup (containers, volumes, networks)
# ✅ Configuration rollback and restoration
# ✅ Progress tracking during cleanup operations
# ✅ Safe cleanup with confirmation prompts
# ✅ Comprehensive logging of cleanup actions
#
# ============================================================================

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "❌ This is a library file and should not be executed directly."
    echo "   Source it in your scripts: source lib/rollback-cleanup.sh"
    exit 1
fi

# Source the error handling library if not already sourced
if ! declare -f log_info &>/dev/null; then
    source "$(dirname "${BASH_SOURCE[0]}")/error-handling.sh"
fi

# ============================================================================
# 📊 CONFIGURATION
# ============================================================================

# Rollback configuration
readonly DEFAULT_ROLLBACK_TIMEOUT=120
readonly DEFAULT_CLEANUP_RETRIES=2

# Global state
declare -A ROLLBACK_ACTIONS
declare -A CLEANUP_ACTIONS
declare -A RESOURCE_TRACKING
declare -a DEPLOYMENT_HISTORY

# ============================================================================
# 📋 ROLLBACK REGISTRATION
# ============================================================================

# Register a rollback action for a component
register_rollback_action() {
    local component="$1"
    local action="$2"
    local description="${3:-Rollback $component}"

    ROLLBACK_ACTIONS["$component"]="$action"
    log_debug "Registered rollback action for $component: $description" "ROLLBACK"
}

# Register a cleanup action for a component
register_cleanup_action() {
    local component="$1"
    local action="$2"
    local description="${3:-Cleanup $component}"

    CLEANUP_ACTIONS["$component"]="$action"
    log_debug "Registered cleanup action for $component: $description" "CLEANUP"
}

# Track a resource for automatic cleanup
track_resource() {
    local resource_type="$1"
    local resource_id="$2"
    local component="${3:-system}"

    if [[ -z "${RESOURCE_TRACKING[$resource_type]:-}" ]]; then
        RESOURCE_TRACKING["$resource_type"]=""
    fi

    RESOURCE_TRACKING["$resource_type"]+="$resource_id|"

    log_debug "Tracking $resource_type resource: $resource_id (component: $component)" "RESOURCE"
}

# Record deployment step for rollback
record_deployment_step() {
    local step="$1"
    local component="$2"
    local timestamp=$(get_iso_timestamp)

    DEPLOYMENT_HISTORY+=("$timestamp|$component|$step")
    log_debug "Recorded deployment step: $component -> $step" "DEPLOYMENT"
}

# ============================================================================
# 🔄 ROLLBACK EXECUTION
# ============================================================================

# Execute rollback for a specific component
rollback_component() {
    local component="$1"
    local timeout="${2:-$DEFAULT_ROLLBACK_TIMEOUT}"

    if [[ -n "${ROLLBACK_ACTIONS[$component]:-}" ]]; then
        log_warn "🔄 Executing rollback for component: $component" "ROLLBACK"

        if timeout_command "$timeout" "${ROLLBACK_ACTIONS[$component]}" "rollback $component"; then
            log_info "✅ Rollback completed successfully for $component" "ROLLBACK"
            return 0
        else
            log_error "❌ Rollback failed for $component" "ROLLBACK"
            return 1
        fi
    else
        log_debug "No rollback action registered for component: $component" "ROLLBACK"
        return 0
    fi
}

# Execute rollback for multiple components
rollback_components() {
    local components=("$@")
    local failed_rollbacks=0

    log_warn "🔄 Starting rollback for ${#components[@]} components" "ROLLBACK"

    for component in "${components[@]}"; do
        if ! rollback_component "$component"; then
            ((failed_rollbacks++))
        fi
    done

    if [[ $failed_rollbacks -eq 0 ]]; then
        log_info "✅ All component rollbacks completed successfully" "ROLLBACK"
        return 0
    else
        log_error "❌ $failed_rollbacks component rollbacks failed" "ROLLBACK"
        return 1
    fi
}

# Execute full system rollback
full_system_rollback() {
    log_warn "🔄 Executing full system rollback" "ROLLBACK"

    # Get all components that have rollback actions
    local components=("${!ROLLBACK_ACTIONS[@]}")

    if [[ ${#components[@]} -eq 0 ]]; then
        log_info "ℹ️ No rollback actions registered" "ROLLBACK"
        return 0
    fi

    rollback_components "${components[@]}"
}

# ============================================================================
# 🧹 CLEANUP OPERATIONS
# ============================================================================

# Execute cleanup for a specific component
cleanup_component() {
    local component="$1"
    local timeout="${2:-$DEFAULT_ROLLBACK_TIMEOUT}"

    if [[ -n "${CLEANUP_ACTIONS[$component]:-}" ]]; then
        log_info "🧹 Executing cleanup for component: $component" "CLEANUP"

        if timeout_command "$timeout" "${CLEANUP_ACTIONS[$component]}" "cleanup $component"; then
            log_info "✅ Cleanup completed successfully for $component" "CLEANUP"
            return 0
        else
            log_error "❌ Cleanup failed for $component" "CLEANUP"
            return 1
        fi
    else
        log_debug "No cleanup action registered for component: $component" "CLEANUP"
        return 0
    fi
}

# Clean up tracked resources
cleanup_tracked_resources() {
    log_info "🧹 Starting cleanup of tracked resources" "CLEANUP"

    local failed_cleanups=0

    # Clean up Docker resources
    if [[ -n "${RESOURCE_TRACKING[docker_container]:-}" ]]; then
        cleanup_docker_containers
    fi

    if [[ -n "${RESOURCE_TRACKING[docker_volume]:-}" ]]; then
        cleanup_docker_volumes
    fi

    if [[ -n "${RESOURCE_TRACKING[docker_network]:-}" ]]; then
        cleanup_docker_networks
    fi

    # Clean up Kubernetes resources
    if [[ -n "${RESOURCE_TRACKING[k8s_deployment]:-}" ]]; then
        cleanup_k8s_deployments
    fi

    if [[ -n "${RESOURCE_TRACKING[k8s_service]:-}" ]]; then
        cleanup_k8s_services
    fi

    if [[ -n "${RESOURCE_TRACKING[k8s_configmap]:-}" ]]; then
        cleanup_k8s_configmaps
    fi

    # Clean up files and directories
    if [[ -n "${RESOURCE_TRACKING[file]:-}" ]]; then
        cleanup_files
    fi

    if [[ -n "${RESOURCE_TRACKING[directory]:-}" ]]; then
        cleanup_directories
    fi

    if [[ $failed_cleanups -eq 0 ]]; then
        log_info "✅ All tracked resources cleaned up successfully" "CLEANUP"
        return 0
    else
        log_error "❌ $failed_cleanups resource cleanups failed" "CLEANUP"
        return 1
    fi
}

# ============================================================================
# 🐳 DOCKER RESOURCE CLEANUP
# ============================================================================

# Clean up Docker containers
cleanup_docker_containers() {
    local containers="${RESOURCE_TRACKING[docker_container]}"
    local failed=0

    log_debug "Cleaning up Docker containers: $containers" "DOCKER"

    IFS='|' read -ra CONTAINER_ARRAY <<< "$containers"
    for container in "${CONTAINER_ARRAY[@]}"; do
        if [[ -n "$container" ]]; then
            log_debug "Removing Docker container: $container" "DOCKER"
            if docker rm -f "$container" &>/dev/null; then
                log_info "✅ Removed Docker container: $container" "DOCKER"
            else
                log_error "❌ Failed to remove Docker container: $container" "DOCKER"
                ((failed++))
            fi
        fi
    done

    return $((failed > 0 ? 1 : 0))
}

# Clean up Docker volumes
cleanup_docker_volumes() {
    local volumes="${RESOURCE_TRACKING[docker_volume]}"
    local failed=0

    log_debug "Cleaning up Docker volumes: $volumes" "DOCKER"

    IFS='|' read -ra VOLUME_ARRAY <<< "$volumes"
    for volume in "${VOLUME_ARRAY[@]}"; do
        if [[ -n "$volume" ]]; then
            log_debug "Removing Docker volume: $volume" "DOCKER"
            if docker volume rm "$volume" &>/dev/null; then
                log_info "✅ Removed Docker volume: $volume" "DOCKER"
            else
                log_error "❌ Failed to remove Docker volume: $volume" "DOCKER"
                ((failed++))
            fi
        fi
    done

    return $((failed > 0 ? 1 : 0))
}

# Clean up Docker networks
cleanup_docker_networks() {
    local networks="${RESOURCE_TRACKING[docker_network]}"
    local failed=0

    log_debug "Cleaning up Docker networks: $networks" "DOCKER"

    IFS='|' read -ra NETWORK_ARRAY <<< "$networks"
    for network in "${NETWORK_ARRAY[@]}"; do
        if [[ -n "$network" ]]; then
            log_debug "Removing Docker network: $network" "DOCKER"
            if docker network rm "$network" &>/dev/null; then
                log_info "✅ Removed Docker network: $network" "DOCKER"
            else
                log_error "❌ Failed to remove Docker network: $network" "DOCKER"
                ((failed++))
            fi
        fi
    done

    return $((failed > 0 ? 1 : 0))
}

# ============================================================================
# ☸️ KUBERNETES RESOURCE CLEANUP
# ============================================================================

# Clean up Kubernetes deployments
cleanup_k8s_deployments() {
    local deployments="${RESOURCE_TRACKING[k8s_deployment]}"
    local failed=0

    log_debug "Cleaning up Kubernetes deployments: $deployments" "K8S"

    IFS='|' read -ra DEPLOYMENT_ARRAY <<< "$deployments"
    for deployment in "${DEPLOYMENT_ARRAY[@]}"; do
        if [[ -n "$deployment" ]]; then
            log_debug "Removing Kubernetes deployment: $deployment" "K8S"
            if kubectl delete deployment "$deployment" --ignore-not-found=true &>/dev/null; then
                log_info "✅ Removed Kubernetes deployment: $deployment" "K8S"
            else
                log_error "❌ Failed to remove Kubernetes deployment: $deployment" "K8S"
                ((failed++))
            fi
        fi
    done

    return $((failed > 0 ? 1 : 0))
}

# Clean up Kubernetes services
cleanup_k8s_services() {
    local services="${RESOURCE_TRACKING[k8s_service]}"
    local failed=0

    log_debug "Cleaning up Kubernetes services: $services" "K8S"

    IFS='|' read -ra SERVICE_ARRAY <<< "$services"
    for service in "${SERVICE_ARRAY[@]}"; do
        if [[ -n "$service" ]]; then
            log_debug "Removing Kubernetes service: $service" "K8S"
            if kubectl delete service "$service" --ignore-not-found=true &>/dev/null; then
                log_info "✅ Removed Kubernetes service: $service" "K8S"
            else
                log_error "❌ Failed to remove Kubernetes service: $service" "K8S"
                ((failed++))
            fi
        fi
    done

    return $((failed > 0 ? 1 : 0))
}

# Clean up Kubernetes configmaps
cleanup_k8s_configmaps() {
    local configmaps="${RESOURCE_TRACKING[k8s_configmap]}"
    local failed=0

    log_debug "Cleaning up Kubernetes configmaps: $configmaps" "K8S"

    IFS='|' read -ra CONFIGMAP_ARRAY <<< "$configmaps"
    for configmap in "${CONFIGMAP_ARRAY[@]}"; do
        if [[ -n "$configmap" ]]; then
            log_debug "Removing Kubernetes configmap: $configmap" "K8S"
            if kubectl delete configmap "$configmap" --ignore-not-found=true &>/dev/null; then
                log_info "✅ Removed Kubernetes configmap: $configmap" "K8S"
            else
                log_error "❌ Failed to remove Kubernetes configmap: $configmap" "K8S"
                ((failed++))
            fi
        fi
    done

    return $((failed > 0 ? 1 : 0))
}

# ============================================================================
# 📁 FILE SYSTEM CLEANUP
# ============================================================================

# Clean up files
cleanup_files() {
    local files="${RESOURCE_TRACKING[file]}"
    local failed=0

    log_debug "Cleaning up files: $files" "FILESYSTEM"

    IFS='|' read -ra FILE_ARRAY <<< "$files"
    for file in "${FILE_ARRAY[@]}"; do
        if [[ -n "$file" && -f "$file" ]]; then
            log_debug "Removing file: $file" "FILESYSTEM"
            if rm -f "$file"; then
                log_info "✅ Removed file: $file" "FILESYSTEM"
            else
                log_error "❌ Failed to remove file: $file" "FILESYSTEM"
                ((failed++))
            fi
        fi
    done

    return $((failed > 0 ? 1 : 0))
}

# Clean up directories
cleanup_directories() {
    local directories="${RESOURCE_TRACKING[directory]}"
    local failed=0

    log_debug "Cleaning up directories: $directories" "FILESYSTEM"

    IFS='|' read -ra DIR_ARRAY <<< "$directories"
    for dir in "${DIR_ARRAY[@]}"; do
        if [[ -n "$dir" && -d "$dir" ]]; then
            log_debug "Removing directory: $dir" "FILESYSTEM"
            if rm -rf "$dir"; then
                log_info "✅ Removed directory: $dir" "FILESYSTEM"
            else
                log_error "❌ Failed to remove directory: $dir" "FILESYSTEM"
                ((failed++))
            fi
        fi
    done

    return $((failed > 0 ? 1 : 0))
}

# ============================================================================
# 📊 REPORTING AND ANALYSIS
# ============================================================================

# Generate rollback report
generate_rollback_report() {
    local report_file="${1:-rollback-report.json}"

    local report_data="{
  \"generated_at\": \"$(get_iso_timestamp)\",
  \"rollback_actions\": {"

    local first=true
    for component in "${!ROLLBACK_ACTIONS[@]}"; do
        if [[ $first == true ]]; then
            first=false
        else
            report_data+=","
        fi

        report_data+="
    \"$component\": \"${ROLLBACK_ACTIONS[$component]}\""
    done

    report_data+="
  },
  \"cleanup_actions\": {"

    first=true
    for component in "${!CLEANUP_ACTIONS[@]}"; do
        if [[ $first == true ]]; then
            first=false
        else
            report_data+=","
        fi

        report_data+="
    \"$component\": \"${CLEANUP_ACTIONS[$component]}\""
    done

    report_data+="
  },
  \"tracked_resources\": {"

    first=true
    for resource_type in "${!RESOURCE_TRACKING[@]}"; do
        if [[ $first == true ]]; then
            first=false
        else
            report_data+=","
        fi

        report_data+="
    \"$resource_type\": \"${RESOURCE_TRACKING[$resource_type]}\""
    done

    report_data+="
  },
  \"deployment_history\": ["

    first=true
    for entry in "${DEPLOYMENT_HISTORY[@]}"; do
        if [[ $first == true ]]; then
            first=false
        else
            report_data+=","
        fi

        IFS='|' read -r timestamp component step <<< "$entry"
        report_data+="
    {
      \"timestamp\": \"$timestamp\",
      \"component\": \"$component\",
      \"step\": \"$step\"
    }"
    done

    report_data+="
  ]
}"

    echo "$report_data" > "$report_file"
    log_info "Rollback report generated: $report_file" "REPORT"
}

# ============================================================================
# 🎯 UTILITY FUNCTIONS
# ============================================================================

# Safe cleanup with confirmation
safe_cleanup() {
    local force=${1:-false}

    if [[ $force == false ]]; then
        echo -e "${YELLOW}${WARNING} This will perform cleanup operations. Continue? (y/N): ${NC}"
        read -r response
        if [[ ! $response =~ ^[Yy]$ ]]; then
            log_info "Cleanup cancelled by user" "CLEANUP"
            return 0
        fi
    fi

    log_info "🧹 Starting safe cleanup operations" "CLEANUP"

    # Execute cleanup actions
    local failed_cleanups=0
    for component in "${!CLEANUP_ACTIONS[@]}"; do
        if ! cleanup_component "$component"; then
            ((failed_cleanups++))
        fi
    done

    # Clean up tracked resources
    if ! cleanup_tracked_resources; then
        ((failed_cleanups++))
    fi

    if [[ $failed_cleanups -eq 0 ]]; then
        log_info "✅ Safe cleanup completed successfully" "CLEANUP"
        return 0
    else
        log_error "❌ $failed_cleanups cleanup operations failed" "CLEANUP"
        return 1
    fi
}

# Emergency cleanup (force cleanup without confirmation)
emergency_cleanup() {
    log_warn "🚨 Executing emergency cleanup" "CLEANUP"
    safe_cleanup true
}

# ============================================================================
# 🎉 INITIALIZATION
# ============================================================================

# Initialize the rollback and cleanup library
init_rollback_cleanup() {
    log_info "🔄 Rollback and cleanup library initialized" "INIT"

    # Set up emergency cleanup on critical signals
    trap emergency_cleanup INT TERM
}

# Auto-initialize if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_rollback_cleanup
fi

# ============================================================================
# 📚 USAGE EXAMPLES
# ============================================================================
#
# Basic usage:
#   source lib/rollback-cleanup.sh
#
# Register rollback actions:
#   register_rollback_action "database" "docker stop postgres && docker rm postgres"
#   register_cleanup_action "database" "docker volume rm postgres_data"
#
# Track resources:
#   track_resource "docker_container" "my-app" "frontend"
#   track_resource "k8s_deployment" "my-deployment" "backend"
#
# Execute rollbacks:
#   rollback_component "database"
#   full_system_rollback
#
# Safe cleanup:
#   safe_cleanup          # With confirmation
#   emergency_cleanup     # Force cleanup
#
# ============================================================================
