#!/bin/bash
set -euo pipefail

# Script Execution Order and Dependency Matrix
# This defines the proper execution order for all scripts in the platform

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ❌${NC} $1"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] ℹ️${NC} $1"; }
success() { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅${NC} $1"; }

show_banner() {
  clear
  echo -e "${BOLD}${PURPLE}"
  cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║    🎯 TC Enterprise DevOps Platform™ - Script Execution Matrix              ║
║                                                                              ║
║    Professional Deployment Order & Dependency Management                    ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}\n"
}

# Define the complete script execution matrix with dependencies
declare -A SCRIPT_MATRIX=(
  # Phase 1: Pre-flight Validation
  ["validate-environment.sh"]="1|Environment validation and compatibility check|None|scripts/"
  ["system-check.sh"]="1|System readiness and resource validation|None|scripts/"
  
  # Phase 2: Tool Installation and Configuration
  ["install-tools.sh"]="2|Development tools installation|validate-environment.sh|scripts/"
  ["auto-configure.sh"]="2|System-optimized configuration generation|install-tools.sh|scripts/"
  
  # Phase 3: Infrastructure Preparation
  ["setup-private-registry.sh"]="3|Private container registry setup|auto-configure.sh|scripts/"
  
  # Phase 4: Core Deployment
  ["deploy-minimal.sh"]="4|Minimal profile deployment|setup-private-registry.sh|scripts/deployment/"
  ["deploy-standard.sh"]="4|Standard profile deployment|setup-private-registry.sh|scripts/deployment/"
  ["deploy-medium.sh"]="4|Medium profile deployment|setup-private-registry.sh|scripts/deployment/"
  ["deploy-large.sh"]="4|Large profile deployment|setup-private-registry.sh|scripts/deployment/"
  ["complete-deployment.sh"]="4|Complete platform deployment|setup-private-registry.sh|."
  ["setup-devops-lab.sh"]="4|Main lab orchestrator|setup-private-registry.sh|."
  
  # Phase 5: Service Integration
  ["setup-authentik-sso.sh"]="5|Enterprise SSO integration|deploy-standard.sh|scripts/"
  ["setup-domain-access.sh"]="5|Domain-based ingress setup|setup-authentik-sso.sh|scripts/"
  
  # Phase 6: Security and Compliance
  ["tc-secure-pipeline.sh"]="6|Security hardening and compliance|setup-authentik-sso.sh|scripts/"
  
  # Phase 7: Post-deployment Validation
  ["tc-readiness-check.sh"]="7|Platform readiness validation|tc-secure-pipeline.sh|scripts/"
  ["system-health-report.sh"]="7|System health and status report|tc-readiness-check.sh|."
  
  # Phase 8: Maintenance and Operations
  ["migrate.sh"]="8|Backup and migration operations|tc-readiness-check.sh|scripts/"
  ["rebrand-images.sh"]="8|Image rebranding for enterprise|tc-readiness-check.sh|scripts/"
  ["tc-registry-manager.sh"]="8|Registry management operations|setup-private-registry.sh|scripts/"
  
  # Phase 9: Cleanup and Reset
  ["cleanup-minimal.sh"]="9|Minimal profile cleanup|None|scripts/deployment/"
  ["cleanup-standard.sh"]="9|Standard profile cleanup|None|scripts/deployment/"
  ["cleanup-medium.sh"]="9|Medium profile cleanup|None|scripts/deployment/"
  ["cleanup-large.sh"]="9|Large profile cleanup|None|scripts/deployment/"
  ["fix-platform.sh"]="9|Platform repair and fixes|None|."
)

# Special orchestrator scripts
declare -A ORCHESTRATOR_SCRIPTS=(
  ["super-lab-manager.sh"]="0|Ultimate orchestrator with AI-like intelligence|None|."
  ["tc-full-pipeline.sh"]="0|Complete CI/CD pipeline orchestrator|None|."
)

show_execution_matrix() {
  echo -e "${BOLD}${CYAN}📋 COMPLETE SCRIPT EXECUTION MATRIX${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Show orchestrator scripts first
  echo -e "${BOLD}${PURPLE}🎭 ORCHESTRATOR SCRIPTS (Zero-Touch Deployment)${NC}"
  echo "────────────────────────────────────────────────────────────────────────────────────"
  for script in "${!ORCHESTRATOR_SCRIPTS[@]}"; do
    IFS='|' read -r phase description dependencies location <<< "${ORCHESTRATOR_SCRIPTS[$script]}"
    local status="❓"
    local full_path=""
    
    if [[ "$location" == "." ]]; then
      full_path="$script"
    else
      full_path="$location$script"
    fi
    
    if [[ -f "$full_path" ]]; then
      if [[ -x "$full_path" ]]; then
        status="✅"
      else
        status="⚠️"
      fi
    else
      status="❌"
    fi
    
    printf "%-3s %-35s %s\n" "$status" "$script" "$description"
  done
  echo ""
  
  # Show regular scripts by phase
  for phase in {1..9}; do
    local phase_name=""
    case $phase in
      1) phase_name="PRE-FLIGHT VALIDATION" ;;
      2) phase_name="TOOL INSTALLATION & CONFIGURATION" ;;
      3) phase_name="INFRASTRUCTURE PREPARATION" ;;
      4) phase_name="CORE DEPLOYMENT" ;;
      5) phase_name="SERVICE INTEGRATION" ;;
      6) phase_name="SECURITY & COMPLIANCE" ;;
      7) phase_name="POST-DEPLOYMENT VALIDATION" ;;
      8) phase_name="MAINTENANCE & OPERATIONS" ;;
      9) phase_name="CLEANUP & RESET" ;;
    esac
    
    echo -e "${BOLD}${BLUE}🔄 PHASE $phase: $phase_name${NC}"
    echo "────────────────────────────────────────────────────────────────────────────────────"
    
    local phase_scripts=()
    for script in "${!SCRIPT_MATRIX[@]}"; do
      IFS='|' read -r script_phase description dependencies location <<< "${SCRIPT_MATRIX[$script]}"
      if [[ "$script_phase" == "$phase" ]]; then
        phase_scripts+=("$script")
      fi
    done
    
    # Sort scripts within phase
    IFS=$'\n' sorted_scripts=($(sort <<<"${phase_scripts[*]}"))
    unset IFS
    
    for script in "${sorted_scripts[@]}"; do
      IFS='|' read -r script_phase description dependencies location <<< "${SCRIPT_MATRIX[$script]}"
      local status="❓"
      local full_path=""
      
      if [[ "$location" == "." ]]; then
        full_path="$script"
      else
        full_path="$location$script"
      fi
      
      if [[ -f "$full_path" ]]; then
        if [[ -x "$full_path" ]]; then
          status="✅"
        else
          status="⚠️"
        fi
      else
        status="❌"
      fi
      
      local dependency_info=""
      if [[ "$dependencies" != "None" ]]; then
        dependency_info=" (after $dependencies)"
      fi
      
      printf "%-3s %-35s %s%s\n" "$status" "$script" "$description" "$dependency_info"
    done
    echo ""
  done
}

show_dependency_graph() {
  echo -e "${BOLD}${CYAN}🔗 DEPENDENCY RELATIONSHIP GRAPH${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  # Build dependency tree
  local processed=()
  local level=0
  
  # Function to print dependencies recursively
  print_dependencies() {
    local script="$1"
    local indent="$2"
    local current_level="$3"
    
    # Avoid infinite loops
    for proc in "${processed[@]}"; do
      if [[ "$proc" == "$script" ]]; then
        echo "${indent}↻ $script (circular reference)"
        return
      fi
    done
    
    processed+=("$script")
    
    if [[ -v SCRIPT_MATRIX["$script"] ]]; then
      IFS='|' read -r phase description dependencies location <<< "${SCRIPT_MATRIX[$script]}"
      
      local status_icon="✅"
      local full_path=""
      if [[ "$location" == "." ]]; then
        full_path="$script"
      else
        full_path="$location$script"
      fi
      
      if [[ ! -f "$full_path" ]]; then
        status_icon="❌"
      elif [[ ! -x "$full_path" ]]; then
        status_icon="⚠️"
      fi
      
      echo "$indent$status_icon $script"
      
      if [[ "$dependencies" != "None" ]]; then
        print_dependencies "$dependencies" "  $indent" $((current_level + 1))
      fi
    else
      echo "$indent❓ $script (not in matrix)"
    fi
  }
  
  # Start with orchestrator scripts
  echo -e "${PURPLE}🎭 ORCHESTRATOR DEPENDENCIES:${NC}"
  for script in "${!ORCHESTRATOR_SCRIPTS[@]}"; do
    processed=()
    print_dependencies "$script" "" 0
    echo ""
  done
  
  # Show critical path (most important deployment flow)
  echo -e "${BLUE}🎯 CRITICAL DEPLOYMENT PATH:${NC}"
  local critical_path=(
    "super-lab-manager.sh"
    "validate-environment.sh"
    "auto-configure.sh"
    "setup-private-registry.sh"
    "deploy-standard.sh"
    "setup-authentik-sso.sh"
    "tc-secure-pipeline.sh"
    "tc-readiness-check.sh"
  )
  
  for i in "${!critical_path[@]}"; do
    local script="${critical_path[$i]}"
    local arrow=""
    if [[ $i -lt $((${#critical_path[@]} - 1)) ]]; then
      arrow=" → "
    fi
    
    local status_icon="✅"
    local full_path=""
    
    # Determine path
    if [[ "$script" == "super-lab-manager.sh" ]]; then
      full_path="$script"
    elif [[ "$script" == *"deploy-"* ]]; then
      full_path="scripts/deployment/$script"
    else
      full_path="scripts/$script"
    fi
    
    if [[ ! -f "$full_path" ]]; then
      status_icon="❌"
    elif [[ ! -x "$full_path" ]]; then
      status_icon="⚠️"
    fi
    
    printf "%s %s%s" "$status_icon" "$script" "$arrow"
  done
  echo -e "\n"
}

show_execution_commands() {
  echo -e "${BOLD}${GREEN}🚀 RECOMMENDED EXECUTION COMMANDS${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  echo -e "${CYAN}🎯 Option 1: Zero-Touch Deployment (Recommended)${NC}"
  echo "────────────────────────────────────────────────────────────────────────────────────"
  echo "# Ultimate orchestrator - handles everything automatically"
  echo "./super-lab-manager.sh"
  echo ""
  
  echo -e "${CYAN}🎓 Option 2: Step-by-Step Learning Path${NC}"
  echo "────────────────────────────────────────────────────────────────────────────────────"
  echo "# 1. Validate your environment"
  echo "./scripts/validate-environment.sh"
  echo ""
  echo "# 2. Configure for your system"
  echo "./scripts/auto-configure.sh"
  echo ""
  echo "# 3. Set up private registry"
  echo "./scripts/setup-private-registry.sh"
  echo ""
  echo "# 4. Deploy infrastructure"
  echo "./scripts/deployment/deploy-standard.sh"
  echo ""
  echo "# 5. Set up SSO (optional)"
  echo "./scripts/setup-authentik-sso.sh"
  echo ""
  echo "# 6. Validate deployment"
  echo "./scripts/tc-readiness-check.sh"
  echo ""
  
  echo -e "${CYAN}🔧 Option 3: Troubleshooting & Maintenance${NC}"
  echo "────────────────────────────────────────────────────────────────────────────────────"
  echo "# Check system health"
  echo "./scripts/validate-environment.sh"
  echo ""
  echo "# Fix issues"
  echo "./fix-platform.sh"
  echo ""
  echo "# Clean slate (if needed)"
  echo "./scripts/deployment/cleanup-standard.sh"
  echo ""
  echo "# Start fresh"
  echo "./super-lab-manager.sh"
  echo ""
}

show_status_legend() {
  echo -e "${BOLD}${YELLOW}📋 STATUS LEGEND${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "✅ Script exists and is executable"
  echo -e "⚠️  Script exists but not executable (will be fixed automatically)"
  echo -e "❌ Script missing (critical issue)"
  echo -e "❓ Script not in dependency matrix"
  echo -e "↻ Circular dependency detected"
  echo ""
}

main() {
  show_banner
  
  log "Analyzing script execution order and dependencies..."
  echo ""
  
  show_execution_matrix
  show_dependency_graph
  show_execution_commands
  show_status_legend
  
  echo -e "${BOLD}${GREEN}🎉 Script execution matrix analysis complete!${NC}"
  echo -e "${GREEN}Use this guide to understand the proper execution order and dependencies.${NC}"
  echo ""
  echo -e "${CYAN}💡 Pro Tip: Run './super-lab-manager.sh' for fully automated deployment!${NC}"
  echo ""
}

# Execute main function
main "$@"
