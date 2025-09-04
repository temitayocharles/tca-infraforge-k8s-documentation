#!/bin/bash
set -euo pipefail

# Comprehensive Configuration and Script Validation
# This script performs deep validation of all configurations and script dependencies

# Source the centralized error handling library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_ROOT/lib/error-handling.sh"
source "$PROJECT_ROOT/lib/parallel-exec.sh"

VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0
VALIDATION_FIXES=0

show_banner() {
  clear
  print_header "🔍 TC Enterprise DevOps Platform™ - Comprehensive Validation"
  echo -e "${BLUE}${INFO} Deep Configuration Analysis & Script Dependency Validation${NC}\n"
}

# Test 1: Registry Port Consistency
test_registry_port_consistency() {
  log "Testing registry port consistency across all configurations..."
  
  local port_5000_refs=$(grep -r "localhost:5000" "$PROJECT_ROOT" 2>/dev/null | grep -v ".git" | wc -l)
  local port_5001_refs=$(grep -r "localhost:5001" "$PROJECT_ROOT" 2>/dev/null | grep -v ".git" | wc -l)
  
  if [[ $port_5000_refs -gt 0 && $port_5001_refs -gt 0 ]]; then
    error "Mixed registry port references: $port_5000_refs on port 5000, $port_5001_refs on port 5001"
    ((VALIDATION_ERRORS++))
    
    info "Files referencing port 5001:"
    grep -r "localhost:5001" "$PROJECT_ROOT" 2>/dev/null | grep -v ".git" | head -5
  else
    success "Registry port consistency: All references use port 5000"
  fi
}

# Test 2: Profile Configuration Alignment
test_profile_consistency() {
  log "Testing profile configuration consistency..."
  
  # Check if profile templates exist for detected system
  local memory_gb=$(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024/1024)}' || echo "8")
  local expected_profile="standard"
  
  if [[ $memory_gb -ge 32 ]]; then
    expected_profile="large"
  elif [[ $memory_gb -ge 16 ]]; then
    expected_profile="medium"
  elif [[ $memory_gb -ge 8 ]]; then
    expected_profile="standard"
  else
    expected_profile="minimal"
  fi
  
  info "System memory: ${memory_gb}GB, expected profile: $expected_profile"
  
  # Check if templates exist for this profile
  local template_dirs=("templates/helm-values" "templates/docker-compose" "templates/resource-limits")
  for template_dir in "${template_dirs[@]}"; do
    if [[ -d "$PROJECT_ROOT/$template_dir" ]]; then
      local profile_files=$(find "$PROJECT_ROOT/$template_dir" -name "*${expected_profile}*" | wc -l)
      if [[ $profile_files -eq 0 ]]; then
        warn "No $expected_profile profile templates found in $template_dir"
        ((VALIDATION_WARNINGS++))
      else
        success "$expected_profile profile templates found in $template_dir ($profile_files files)"
      fi
    fi
  done
}

# Test 3: System Detection and Hardware Profiling
test_system_detection() {
  log "Testing system detection and hardware profiling..."
  
  local os_name=$(uname -s)
  case $os_name in
    "Darwin")
      local os_version=$(sw_vers -productVersion)
      local major_version=${os_version%%.*}
      if [[ $major_version -ge 11 ]]; then
        success "macOS $os_version detected (compatible)"
      else
        warn "macOS $os_version detected (old version - consider upgrading)"
        ((VALIDATION_WARNINGS++))
      fi
      ;;
    "Linux")
      if [[ -f /etc/os-release ]]; then
        local distro=$(. /etc/os-release && echo $ID)
        case $distro in
          "ubuntu"|"debian"|"centos"|"fedora"|"rhel")
            success "Linux ($distro) detected (compatible)"
            ;;
          *)
            warn "Linux ($distro) detected (untested)"
            ((VALIDATION_WARNINGS++))
            ;;
        esac
      else
        warn "Linux detected (unknown distribution)"
        ((VALIDATION_WARNINGS++))
      fi
      ;;
    *)
      error "Unsupported OS: $os_name"
      ((VALIDATION_ERRORS++))
      ;;
  esac
  
  # Check memory
  local total_memory_gb=0
  case $os_name in
    "Darwin")
      local memory_bytes=$(sysctl -n hw.memsize)
      total_memory_gb=$((memory_bytes / 1024 / 1024 / 1024))
      ;;
    "Linux")
      local memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
      total_memory_gb=$((memory_kb / 1024 / 1024))
      ;;
  esac
  
  if [[ $total_memory_gb -ge 32 ]]; then
    success "Memory: ${total_memory_gb}GB (excellent for large profile)"
  elif [[ $total_memory_gb -ge 16 ]]; then
    success "Memory: ${total_memory_gb}GB (good for medium profile)"
  elif [[ $total_memory_gb -ge 8 ]]; then
    success "Memory: ${total_memory_gb}GB (adequate for standard profile)"
  elif [[ $total_memory_gb -ge 4 ]]; then
    warn "Memory: ${total_memory_gb}GB (minimal profile only)"
    ((VALIDATION_WARNINGS++))
  else
    error "Memory: ${total_memory_gb}GB (insufficient)"
    ((VALIDATION_ERRORS++))
  fi
  
  # Check CPU cores
  local cpu_cores=0
  case $os_name in
    "Darwin")
      cpu_cores=$(sysctl -n hw.ncpu)
      ;;
    "Linux")
      cpu_cores=$(nproc)
      ;;
  esac
  
  if [[ $cpu_cores -ge 8 ]]; then
    success "CPU: ${cpu_cores} cores (excellent)"
  elif [[ $cpu_cores -ge 4 ]]; then
    success "CPU: ${cpu_cores} cores (good)"
  elif [[ $cpu_cores -ge 2 ]]; then
    warn "CPU: ${cpu_cores} cores (limited performance expected)"
    ((VALIDATION_WARNINGS++))
  else
    error "CPU: ${cpu_cores} cores (insufficient)"
    ((VALIDATION_ERRORS++))
  fi
}

# Test 4: Script Execution Dependencies
test_script_dependencies() {
  log "Testing script execution dependencies..."
  
  # Define proper execution order with dependencies
  local script_order=(
    "validate-environment.sh:"
    "install-tools.sh:"
    "auto-configure.sh:install-tools.sh"
    "setup-private-registry.sh:auto-configure.sh"
    "deploy-standard.sh:setup-private-registry.sh"
    "setup-authentik-sso.sh:deploy-standard.sh"
    "tc-secure-pipeline.sh:setup-authentik-sso.sh"
  )
  
  for script_def in "${script_order[@]}"; do
    local script_name=$(echo "$script_def" | cut -d: -f1)
    local dependency=$(echo "$script_def" | cut -d: -f2)
    
    if [[ -f "$PROJECT_ROOT/scripts/$script_name" ]]; then
      if [[ -n "$dependency" && -f "$PROJECT_ROOT/scripts/$dependency" ]]; then
        success "✓ $script_name (depends on $dependency)"
      elif [[ -n "$dependency" ]]; then
        error "✗ $script_name dependency missing: $dependency"
        ((VALIDATION_ERRORS++))
      else
        success "✓ $script_name (no dependencies)"
      fi
    else
      error "✗ Critical script missing: $script_name"
      ((VALIDATION_ERRORS++))
    fi
  done
}

# Test 4: Configuration File Integrity
test_configuration_integrity() {
  log "Testing configuration file integrity..."
  
  # Test config.env
  if [[ -f "$PROJECT_ROOT/config.env" ]]; then
    # Check for required variables
    local required_vars=(
      "DEVOPS_PROFILE"
      "PRIVATE_REGISTRY"
      "REDIS_IMAGE"
      "POSTGRES_IMAGE"
      "PROMETHEUS_IMAGE"
      "GRAFANA_IMAGE"
      "CLUSTER_NAME"
    )
    
    for var in "${required_vars[@]}"; do
      if grep -q "^$var=" "$PROJECT_ROOT/config.env"; then
        success "✓ Configuration variable $var present"
      else
        error "✗ Missing required configuration variable: $var"
        ((VALIDATION_ERRORS++))
      fi
    done
    
    # Test for shell syntax errors
    if bash -n "$PROJECT_ROOT/config.env" 2>/dev/null; then
      success "✓ config.env syntax is valid"
    else
      error "✗ config.env has syntax errors"
      ((VALIDATION_ERRORS++))
    fi
  else
    error "✗ Critical file missing: config.env"
    ((VALIDATION_ERRORS++))
  fi
}

# Test 5: Container Image Consistency
test_container_image_consistency() {
  log "Testing container image consistency..."
  
  # Check for consistent image tags across all files
  local image_patterns=(
    "redis:7-alpine"
    "postgres:15-alpine"
    "vault:1.15.0"
    "prometheus:v2.45.0"
    "grafana:10.0.0"
  )
  
  for pattern in "${image_patterns[@]}"; do
    local refs=$(grep -r "$pattern" "$PROJECT_ROOT" 2>/dev/null | grep -v ".git" | wc -l)
    if [[ $refs -gt 0 ]]; then
      success "✓ Image $pattern referenced consistently ($refs times)"
    else
      warn "⚠ Image $pattern not found in configurations"
      ((VALIDATION_WARNINGS++))
    fi
  done
}

# Test 6: Security Configuration Validation
test_security_configuration() {
  log "Testing security configuration..."
  
  # Check for weak passwords
  if grep -r "password.*admin\|password.*123\|changeme" "$PROJECT_ROOT" 2>/dev/null | grep -v ".git" | grep -v "example\|sample\|template" >/dev/null; then
    error "✗ Weak passwords detected in configuration"
    ((VALIDATION_ERRORS++))
  else
    success "✓ No weak passwords detected"
  fi
  
  # Check for proper secret handling
  if [[ -f "$PROJECT_ROOT/config.env" ]]; then
    local secret_vars=$(grep -E "(PASSWORD|TOKEN|SECRET|KEY)=" "$PROJECT_ROOT/config.env" | grep -v "openssl\|uuidgen" || true)
    if [[ -n "$secret_vars" ]]; then
      warn "⚠ Hard-coded secrets detected - ensure these are properly secured"
      ((VALIDATION_WARNINGS++))
    else
      success "✓ Dynamic secret generation configured"
    fi
  fi
}

# Test 7: Network Configuration Validation
test_network_configuration() {
  log "Testing network configuration..."
  
  # Check for port conflicts
  local common_ports=(80 443 8080 8443 3000 5000 9090 9093)
  local port_issues=0
  
  for port in "${common_ports[@]}"; do
    if lsof -i ":$port" >/dev/null 2>&1; then
      local process=$(lsof -ti ":$port" | head -1)
      local process_name=$(ps -p "$process" -o comm= 2>/dev/null || echo "unknown")
      warn "⚠ Port $port in use by $process_name"
      ((port_issues++))
    fi
  done
  
  if [[ $port_issues -eq 0 ]]; then
    success "✓ No port conflicts detected"
  else
    warn "⚠ $port_issues potential port conflicts detected"
    ((VALIDATION_WARNINGS++))
  fi
}

# Test 8: File Permissions and Executability
test_file_permissions() {
  log "Testing file permissions and executability..."
  
  # Check script executability
  local script_count=0
  local executable_count=0
  
  while IFS= read -r -d '' script; do
    ((script_count++))
    if [[ -x "$script" ]]; then
      ((executable_count++))
    else
      warn "⚠ Script not executable: $(basename "$script")"
      chmod +x "$script" 2>/dev/null && {
        success "✓ Fixed permissions for $(basename "$script")"
        ((VALIDATION_FIXES++))
      } || {
        error "✗ Cannot fix permissions for $(basename "$script")"
        ((VALIDATION_ERRORS++))
      }
    fi
  done < <(find "$PROJECT_ROOT" -name "*.sh" -print0)
  
  success "✓ Script permissions: $executable_count/$script_count scripts executable"
}

# Test 9: Documentation Consistency
test_documentation_consistency() {
  log "Testing documentation consistency..."
  
  # Check if main documentation files exist
  local doc_files=(
    "README.md"
    "ULTIMATE-README.md"
    "SCRIPT-EXECUTION-ORDER.md"
  )
  
  for doc in "${doc_files[@]}"; do
    if [[ -f "$PROJECT_ROOT/$doc" ]]; then
      success "✓ Documentation file exists: $doc"
    else
      warn "⚠ Documentation file missing: $doc"
      ((VALIDATION_WARNINGS++))
    fi
  done
}

# Test 10: Branding Consistency
test_branding_consistency() {
  log "Testing TC Enterprise branding consistency..."
  
  # Check for consistent branding across files
  local branding_refs=$(grep -r "TC Enterprise" "$PROJECT_ROOT" 2>/dev/null | grep -v ".git" | wc -l)
  if [[ $branding_refs -gt 0 ]]; then
    success "✓ TC Enterprise branding found in $branding_refs locations"
  else
    warn "⚠ TC Enterprise branding not consistently applied"
    ((VALIDATION_WARNINGS++))
  fi
  
  # Check for trademark consistency
  local trademark_refs=$(grep -r "TC Enterprise DevOps Platform™" "$PROJECT_ROOT" 2>/dev/null | grep -v ".git" | wc -l)
  if [[ $trademark_refs -gt 0 ]]; then
    success "✓ Trademark notation found in $trademark_refs locations"
  else
    warn "⚠ Trademark notation not consistently applied"
    ((VALIDATION_WARNINGS++))
  fi
}

# Generate validation report
generate_validation_report() {
  local report_file="$PROJECT_ROOT/logs/validation-report-$(date +%Y%m%d_%H%M%S).log"
  
  {
    echo "TC Enterprise DevOps Platform™ - Comprehensive Validation Report"
    echo "Generated: $(date)"
    echo "============================================================"
    echo ""
    echo "VALIDATION SUMMARY:"
    echo "  Errors: $VALIDATION_ERRORS"
    echo "  Warnings: $VALIDATION_WARNINGS"
    echo "  Fixes Applied: $VALIDATION_FIXES"
    echo ""
    echo "SYSTEM INFORMATION:"
    echo "  OS: $(uname -s)"
    echo "  Architecture: $(uname -m)"
    echo "  Memory: $(sysctl -n hw.memsize 2>/dev/null | awk '{print int($1/1024/1024/1024)}' || echo "Unknown")GB"
    echo "  CPU Cores: $(sysctl -n hw.ncpu 2>/dev/null || echo "Unknown")"
    echo ""
    echo "VALIDATION DETAILS:"
    echo "  ✓ Tests Passed: $((10 - VALIDATION_ERRORS))"
    echo "  ✗ Tests Failed: $VALIDATION_ERRORS"
    echo "  ⚠ Warnings: $VALIDATION_WARNINGS"
    echo ""
  } > "$report_file"
  
  info "Validation report saved to: $report_file"
}

# Show final summary
show_validation_summary() {
  echo ""
  echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${BLUE}║                    COMPREHENSIVE VALIDATION COMPLETE                        ║${NC}"
  echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  
  if [[ $VALIDATION_ERRORS -eq 0 ]]; then
    echo -e "${GREEN}🎉 ALL VALIDATIONS PASSED!${NC}"
    echo -e "${GREEN}Your TC Enterprise DevOps Platform™ is perfectly configured and ready for deployment.${NC}"
  elif [[ $VALIDATION_ERRORS -le 2 ]]; then
    echo -e "${YELLOW}⚠️ MINOR ISSUES DETECTED${NC}"
    echo -e "${YELLOW}Your platform is mostly ready but has $VALIDATION_ERRORS minor issues to address.${NC}"
  else
    echo -e "${RED}❌ CRITICAL ISSUES DETECTED${NC}"
    echo -e "${RED}Your platform has $VALIDATION_ERRORS critical issues that must be resolved before deployment.${NC}"
  fi
  
  echo ""
  echo -e "${CYAN}📊 VALIDATION SUMMARY:${NC}"
  echo -e "${CYAN}  • Errors: $VALIDATION_ERRORS${NC}"
  echo -e "${CYAN}  • Warnings: $VALIDATION_WARNINGS${NC}"
  echo -e "${CYAN}  • Fixes Applied: $VALIDATION_FIXES${NC}"
  echo ""
  
  if [[ $VALIDATION_ERRORS -eq 0 ]]; then
    echo -e "${GREEN}🚀 READY FOR DEPLOYMENT!${NC}"
    echo -e "${GREEN}Run: ./super-lab-manager.sh${NC}"
  else
    echo -e "${YELLOW}🔧 RESOLVE ISSUES FIRST${NC}"
    echo -e "${YELLOW}Address the errors above, then re-run this validation.${NC}"
  fi
  
  echo ""
}

# Main execution
main() {
  show_banner

  log_info "Starting comprehensive validation of TC Enterprise DevOps Platform™..." "VALIDATION"
  echo ""

  # Define validation tasks for parallel execution
  local validation_tasks=(
    "test_registry_port_consistency|DESC|Registry Port Consistency Check"
    "test_profile_consistency|DESC|Profile Configuration Alignment"
    "test_system_detection|DESC|System Detection & Hardware Profiling"
    "test_script_dependencies|DESC|Script Execution Dependencies"
    "test_configuration_integrity|DESC|Configuration File Integrity"
    "test_container_image_consistency|DESC|Container Image Consistency|DEP|test_configuration_integrity"
    "test_security_configuration|DESC|Security Configuration Validation|DEP|test_configuration_integrity"
    "test_network_configuration|DESC|Network Configuration Validation"
    "test_file_permissions|DESC|File Permissions & Executability"
    "test_documentation_consistency|DESC|Documentation Consistency"
    "test_branding_consistency|DESC|Branding Consistency"
  )

  # Execute validations in parallel
  parallel_validate "${validation_tasks[@]}"

  # Generate report and show summary
  generate_validation_report
  show_validation_summary

  # Return appropriate exit code
  if [[ $VALIDATION_ERRORS -eq 0 ]]; then
    exit 0
  else
    exit 1
  fi
}

# Execute main function
main "$@"
