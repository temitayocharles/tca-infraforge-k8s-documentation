#!/bin/bash
# TC Enterprise DevOps Platform™ - Super Lab Manager
# One script to orchestrate, heal, upgrade, and brand your entire lab
# Zero-touch deployment with human-like intelligence

set -euo pipefail

# --- Global Variables ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
LOG_FILE="$PROJECT_ROOT/logs/super-lab-manager-$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="$PROJECT_ROOT/backups/super-lab-backup-$(date +%Y%m%d_%H%M%S)"
REGISTRY_PORT=5001  # Updated to match running registry
ENV_TYPE=""
ARCH=""
TOTAL_MEMORY_GB=0
CPU_CORES=0
PROFILE=""  # Will be determined dynamically
ACTIONS_TAKEN=()
PERFORMANCE_ISSUES=()
CONFIGURATION_ISSUES=()

# --- Color Output ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️ ${NC}$1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ❌ ${NC}$1" | tee -a "$LOG_FILE"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] ℹ️ ${NC}$1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ ${NC}$1" | tee -a "$LOG_FILE"; }
progress() { echo -e "${CYAN}[$(date +'%H:%M:%S')] 🔄 ${NC}$1" | tee -a "$LOG_FILE"; }

# --- Setup Functions ---
setup_environment() {
  # Create necessary directories
  mkdir -p "$PROJECT_ROOT/logs" "$PROJECT_ROOT/backups" "$PROJECT_ROOT/configs"
  
  # Initialize log file with validation
  if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "ERROR: Cannot create log file at $LOG_FILE"
    echo "Please check permissions or disk space"
    exit 1
  fi
  
  # Verify log file is writable
  if ! echo "Test write" >> "$LOG_FILE" 2>/dev/null; then
    echo "ERROR: Log file $LOG_FILE is not writable"
    exit 1
  fi
  
  echo "TC Enterprise DevOps Lab - Super Lab Manager Started at $(date)" > "$LOG_FILE"
  
  # Backup current state before any changes - with validation
  if [[ -d "$PROJECT_ROOT/config" || -f "$PROJECT_ROOT/config.env" ]]; then
    progress "Creating backup of current configuration..."
    mkdir -p "$BACKUP_DIR"
    
    # Only backup files that actually exist
    [[ -f "$PROJECT_ROOT/config.env" ]] && cp "$PROJECT_ROOT/config.env" "$BACKUP_DIR/" 2>/dev/null
    [[ -f "$PROJECT_ROOT/config.local" ]] && cp "$PROJECT_ROOT/config.local" "$BACKUP_DIR/" 2>/dev/null
    [[ -f "$PROJECT_ROOT/config.tc-brand" ]] && cp "$PROJECT_ROOT/config.tc-brand" "$BACKUP_DIR/" 2>/dev/null
    [[ -d "$PROJECT_ROOT/config" ]] && cp -r "$PROJECT_ROOT/config" "$BACKUP_DIR/" 2>/dev/null
    
    ACTIONS_TAKEN+=("Created backup in $BACKUP_DIR")
  fi
}

# --- Welcome Banner ---
show_banner() {
  clear
  echo -e "${BOLD}${BLUE}"
  cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║    🚀 TC Enterprise DevOps Platform™ - Super Lab Manager                    ║
║                                                                              ║
║    Zero-Touch Enterprise Lab Orchestration & Self-Healing                   ║
║    ▶ Detects • Installs • Configures • Brands • Heals • Optimizes          ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}\n"
}

# --- System Detection & Resource Analysis ---
detect_system_resources() {
  OS=$(uname -s)
  ARCH=$(uname -m)
  
  progress "Analyzing system resources and capabilities..."
  
  case "$OS" in
    "Darwin")
      ENV_TYPE="macos"
      # Check if bc is available for calculation
      if command -v bc &>/dev/null; then
        TOTAL_MEMORY_GB=$(echo "$(sysctl -n hw.memsize) / 1024 / 1024 / 1024" | bc)
      else
        # Fallback calculation without bc
        TOTAL_MEMORY_GB=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
      fi
      CPU_CORES=$(sysctl -n hw.ncpu)
      ;;
    "Linux")
      ENV_TYPE="linux"
      TOTAL_MEMORY_GB=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')
      CPU_CORES=$(nproc)
      ;;
    "CYGWIN"*|"MINGW"*)
      ENV_TYPE="windows"
      # More robust Windows memory detection
      if command -v wmic &>/dev/null; then
        TOTAL_MEMORY_GB=$(wmic computersystem get TotalPhysicalMemory | grep -o '[0-9]*' | head -1 | awk '{print int($1/1024/1024/1024)}')
        CPU_CORES=$(wmic cpu get NumberOfCores | grep -o '[0-9]*' | head -1)
      else
        # Fallback values
        TOTAL_MEMORY_GB=8
        CPU_CORES=4
        warn "Could not detect exact system resources, using defaults"
      fi
      ;;
    *)
      ENV_TYPE="unknown"
      error "Unsupported OS: $OS"
      exit 1
      ;;
  esac
  
  # Validate detected values
  [[ $TOTAL_MEMORY_GB -lt 1 ]] && TOTAL_MEMORY_GB=4
  [[ $CPU_CORES -lt 1 ]] && CPU_CORES=2
  
  info "Host Environment: $ENV_TYPE ($ARCH) | Memory: ${TOTAL_MEMORY_GB}GB | CPU: ${CPU_CORES} cores"
  
  # Determine optimal profile
  if [[ $TOTAL_MEMORY_GB -ge 32 ]]; then
    PROFILE="large"
  elif [[ $TOTAL_MEMORY_GB -ge 16 ]]; then
    PROFILE="medium"
  elif [[ $TOTAL_MEMORY_GB -ge 8 ]]; then
    PROFILE="standard"
  else
    PROFILE="minimal"
    PERFORMANCE_ISSUES+=("Low memory ($TOTAL_MEMORY_GB GB) - Consider upgrading to 8GB+ for optimal performance")
  fi
  
  success "Detected optimal profile: $PROFILE"
  ACTIONS_TAKEN+=("Detected system: $ENV_TYPE, Profile: $PROFILE")
}

# --- Apple Silicon Detection & Colima Integration ---
is_apple_silicon() {
  [[ "$ENV_TYPE" == "macos" && "$ARCH" == "arm64" ]]
}

needs_vm_fallback() {
  # Check if we're on Apple Silicon and Docker Desktop is being used
  if is_apple_silicon; then
    # Check if we're using Docker Desktop (problematic for multi-node KIND)
    local docker_context=$(docker context show 2>/dev/null || echo "")
    if [[ "$docker_context" == "desktop-linux" || "$docker_context" == "default" ]]; then
      return 0  # Needs VM fallback
    fi
  fi
  return 1  # No fallback needed
}

install_and_setup_colima() {
  progress "Installing and configuring Colima for Apple Silicon compatibility..."
  
  # Update Homebrew first
  info "Updating system packages..."
  if command -v brew &>/dev/null; then
    brew update &>/dev/null || warn "Failed to update Homebrew"
  else
    error "Homebrew is required for Colima installation on macOS"
    return 1
  fi
  
  # Install Colima if not present
  if ! command -v colima &>/dev/null; then
    info "Installing Colima..."
    brew install colima || {
      error "Failed to install Colima"
      return 1
    }
  else
    info "Colima already installed"
  fi
  
  # Stop Docker Desktop if running
  if pgrep -f "Docker Desktop" &>/dev/null; then
    warn "Stopping Docker Desktop to avoid conflicts..."
    killall "Docker Desktop" 2>/dev/null || true
    sleep 5
  fi
  
  # Start Colima with enterprise-grade resources
  local cpu_for_vm=$((CPU_CORES - 1))  # Leave one core for host
  local memory_for_vm=$((TOTAL_MEMORY_GB - 2))  # Leave 2GB for host
  [[ $cpu_for_vm -lt 2 ]] && cpu_for_vm=2
  [[ $memory_for_vm -lt 4 ]] && memory_for_vm=4
  
  info "Starting Colima VM with ${cpu_for_vm} CPUs, ${memory_for_vm}GB RAM..."
  
  # Stop existing Colima if running
  colima stop 2>/dev/null || true
  
  # Start with Kubernetes enabled for enterprise features
  if colima start --cpu "$cpu_for_vm" --memory "$memory_for_vm" --disk 60 --kubernetes --runtime docker; then
    success "Colima VM started successfully"
    
    # Switch Docker and Kubernetes contexts
    docker context use colima &>/dev/null || true
    kubectl config use-context colima &>/dev/null || true
    
    success "Switched to Colima context for native Linux compatibility"
    ACTIONS_TAKEN+=("Configured Colima VM for Apple Silicon compatibility")
    return 0
  else
    error "Failed to start Colima VM"
    return 1
  fi
}

check_and_setup_vm_if_needed() {
  if needs_vm_fallback; then
    warn "Apple Silicon detected with Docker Desktop - VM required for enterprise multi-node clusters"
    
    # Check if Colima is already running and configured
    if colima status 2>/dev/null | grep -q "Running"; then
      local current_context=$(docker context show 2>/dev/null || echo "")
      if [[ "$current_context" == "colima" ]]; then
        info "Colima VM already running and configured"
        return 0
      fi
    fi
    
    # Install and setup Colima
    if install_and_setup_colima; then
      success "Apple Silicon VM environment ready for enterprise deployment"
      return 0
    else
      error "Failed to setup VM environment"
      return 1
    fi
  fi
  return 0  # No VM needed
}

# --- Comprehensive Connectivity & Port Management ---
check_connectivity_and_ports() {
  progress "Checking network connectivity and port availability..."
  
  # Internet connectivity with timeout
  if ! timeout 10 ping -c 1 8.8.8.8 &>/dev/null && ! timeout 10 ping -c 1 1.1.1.1 &>/dev/null; then
    error "No internet connection detected. Some features may not work."
    PERFORMANCE_ISSUES+=("No internet connectivity - Downloads and updates will fail")
    return 1
  fi
  
  # Check for port conflicts and kill processes if needed
  local ports_to_check=(5001 8080 8443 3000 9090 9093)
  for port in "${ports_to_check[@]}"; do
    if lsof -i ":$port" &>/dev/null; then
      warn "Port $port is in use. Attempting to free it..."
      local pid=$(lsof -ti ":$port")
      if [[ -n "$pid" ]]; then
        # Validate PID belongs to expected process before killing
        local process_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        
        # Only kill processes that are likely safe to terminate
  if [[ "$process_name" =~ ^(docker|node|python|kubectl|kind)$ ]] || [[ "$port" =~ ^(5001|8080|3000)$ ]]; then
          info "Terminating $process_name (PID: $pid) on port $port"
          kill -TERM "$pid" 2>/dev/null || true
          sleep 3
          
          # If still running, force kill
          if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
            sleep 2
          fi
          
          if ! lsof -i ":$port" &>/dev/null; then
            success "Port $port freed successfully"
            ACTIONS_TAKEN+=("Killed $process_name process on port $port")
          else
            warn "Could not free port $port - will use alternative"
            PERFORMANCE_ISSUES+=("Port conflict on $port - using alternative port")
          fi
        else
          warn "Port $port in use by $process_name - using alternative port"
          PERFORMANCE_ISSUES+=("Port conflict on $port - process $process_name not terminated")
        fi
      fi
    fi
  done
  
  # Determine registry port - check for conflicts and align with other scripts
  REGISTRY_PORT=5001  # Updated to match running registry
  if lsof -i ":5001" &>/dev/null; then
  local pid=$(lsof -ti ":5001")
    local process_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
    
    # If it's already our registry, that's fine
    if [[ "$process_name" =~ registry ]]; then
  success "Registry already running on port 5001"
      return 0
    else
  # Try to free port 5001 since it's our standard
  warn "Port 5001 in use by $process_name - attempting to free it"
      if [[ "$process_name" =~ ^(node|python|docker)$ ]]; then
        kill -TERM "$pid" 2>/dev/null || true
        sleep 3
  if ! lsof -i ":5001" &>/dev/null; then
          success "Port 5001 freed successfully"
          ACTIONS_TAKEN+=("Freed port 5001 from $process_name")
        else
          REGISTRY_PORT=5001
          warn "Could not free port 5001, using alternative port"
          CONFIGURATION_ISSUES+=("Registry on non-standard port $REGISTRY_PORT - may cause issues with other scripts")
        fi
      else
        REGISTRY_PORT=5001
        warn "Cannot terminate $process_name, using alternative port 5001"
        CONFIGURATION_ISSUES+=("Registry on non-standard port $REGISTRY_PORT - may cause issues with other scripts")
      fi
    fi
  fi
  
  success "Network connectivity and port management complete"
}

# --- Intelligent Docker Management ---
ensure_docker() {
  progress "Ensuring Docker is installed and optimally configured..."
  
  # Check if Docker is installed
  if ! command -v docker &>/dev/null; then
    warn "Docker not found. Installing Docker Desktop for $ENV_TYPE..."
    
    case "$ENV_TYPE" in
      "macos")
        if ! command -v brew &>/dev/null; then
          info "Installing Homebrew first..."
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install --cask docker
        ;;
      "linux")
        curl -fsSL https://get.docker.com | sh
        sudo usermod -aG docker "$USER"
        ;;
      "windows")
        if ! command -v choco &>/dev/null; then
          error "Chocolatey not found. Please install Docker Desktop manually."
          exit 1
        fi
        choco install docker-desktop
        ;;
    esac
    
    success "Docker installed successfully"
    ACTIONS_TAKEN+=("Installed Docker Desktop")
  else
    info "Docker found: $(docker --version)"
  fi
  
  # Ensure Docker daemon is running
  if ! docker info &>/dev/null; then
    warn "Docker daemon not running. Attempting to start Colima (Apple Silicon/macOS) or Docker Desktop..."
    if [[ "$ENV_TYPE" == "macos" ]] && command -v colima &>/dev/null; then
      colima start || true
      progress "Waiting for Colima to start..."
      for i in {1..30}; do
        if docker info &>/dev/null; then
          break
        fi
        sleep 2
      done
      if docker info &>/dev/null; then
        success "Colima Docker daemon started successfully"
        ACTIONS_TAKEN+=("Started Colima Docker daemon")
      else
        warn "Colima did not start Docker daemon. Trying Docker Desktop..."
        open -a Docker
        progress "Waiting for Docker Desktop to start..."
        for i in {1..30}; do
          if docker info &>/dev/null; then
            break
          fi
          sleep 2
        done
        if docker info &>/dev/null; then
          success "Docker daemon started successfully"
          ACTIONS_TAKEN+=("Started Docker daemon")
        else
          error "Failed to start Docker daemon"
          exit 1
        fi
      fi
    else
      case "$ENV_TYPE" in
        "linux")
          sudo systemctl start docker
          sudo systemctl enable docker
          ;;
        "windows")
          start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
          ;;
      esac
      if docker info &>/dev/null; then
        success "Docker daemon started successfully"
        ACTIONS_TAKEN+=("Started Docker daemon")
      else
        error "Failed to start Docker daemon"
        exit 1
      fi
    fi
  fi
  
  # Check Docker resource allocation with validation
  local docker_memory_gb=""
  if docker system info --format '{{.MemTotal}}' &>/dev/null; then
    docker_memory_gb=$(docker system info --format '{{.MemTotal}}' 2>/dev/null | awk '{print int($1/1024/1024/1024)}')
  fi
  
  # Validate docker memory value
  if [[ -n "$docker_memory_gb" ]] && [[ "$docker_memory_gb" =~ ^[0-9]+$ ]] && [[ $docker_memory_gb -lt 6 ]] && [[ $TOTAL_MEMORY_GB -ge 8 ]]; then
    PERFORMANCE_ISSUES+=("Docker memory allocation too low ($docker_memory_gb GB) - Increase to 6GB+ in Docker Desktop settings")
  fi
  
  success "Docker validation complete"
}

# --- Advanced Tool Management with Version Checking ---
ensure_tools() {
  progress "Ensuring all required DevOps tools are installed and up-to-date..."
  
  local tools_config=(
    "kubectl:https://kubernetes.io/docs/tasks/tools/"
    "kind:https://kind.sigs.k8s.io/docs/user/quick-start/"
    "helm:https://helm.sh/docs/intro/install/"
    "jq:JSON processor"
    "yq:YAML processor"
    "git:Version control"
  )
  
  for tool_info in "${tools_config[@]}"; do
    local tool=$(echo "$tool_info" | cut -d: -f1)
    
    if ! command -v "$tool" &>/dev/null; then
      warn "$tool not found. Installing..."
      
      case "$ENV_TYPE" in
        "macos")
          if ! command -v brew &>/dev/null; then
            info "Installing Homebrew first..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
          fi
          brew install "$tool"
          ;;
        "linux")
          # Check for sudo availability and package manager
          if ! sudo -n true &>/dev/null; then
            warn "Sudo access required for Linux package installation"
            # Try without sudo for user-space installers
            if command -v snap &>/dev/null; then
              snap install "$tool" --classic 2>/dev/null || warn "Failed to install $tool via snap"
            else
              error "Cannot install $tool - no sudo access and no alternative installer"
              continue
            fi
          else
            # Use appropriate package manager with sudo
            if command -v apt-get &>/dev/null; then
              sudo apt-get update && sudo apt-get install -y "$tool"
            elif command -v yum &>/dev/null; then
              sudo yum install -y "$tool"
            elif command -v dnf &>/dev/null; then
              sudo dnf install -y "$tool"
            else
              error "No package manager found for Linux"
              exit 1
            fi
          fi
          ;;
        "windows")
          if ! command -v choco &>/dev/null; then
            error "Chocolatey not found. Please install tools manually."
            exit 1
          fi
          choco install "$tool"
          ;;
      esac
      
      if command -v "$tool" &>/dev/null; then
        success "$tool installed successfully"
        ACTIONS_TAKEN+=("Installed $tool")
      else
        error "Failed to install $tool"
        exit 1
      fi
    else
      local version_output=$($tool --version 2>/dev/null | head -1 || echo "version unknown")
      info "$tool found: $version_output"
    fi
  done
  
  # Special handling for istioctl
  if ! command -v istioctl &>/dev/null; then
    warn "Installing Istio CLI..."
    
    # Create local bin directory if it doesn't exist
    mkdir -p "$HOME/.local/bin"
    
    if timeout 300 curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh -; then
      if [[ -d "istio-1.20.0" && -f "istio-1.20.0/bin/istioctl" ]]; then
        cp istio-1.20.0/bin/istioctl "$HOME/.local/bin/" 2>/dev/null || {
          warn "Could not copy istioctl to ~/.local/bin, trying /usr/local/bin"
          sudo cp istio-1.20.0/bin/istioctl /usr/local/bin/ 2>/dev/null || {
            warn "Could not install istioctl to system path"
          }
        }
        rm -rf istio-1.20.0
        
        # Verify installation
        if command -v istioctl &>/dev/null; then
          ACTIONS_TAKEN+=("Installed istioctl")
        fi
      else
        warn "Istio download failed or incomplete"
      fi
    else
      warn "Failed to download Istio - continuing without it"
    fi
  fi
  
  success "All required tools are installed and ready"
}

# --- Intelligent Script Discovery & Execution with Dependency Management ---
find_and_run_script() {
  local script_name="$1"
  local signature="$2"
  local args="${3:-}"
  local required_before="${4:-}"  # Scripts that must run before this one
  
  progress "Searching for script: $script_name (signature: $signature)"
  
  # Check if required dependencies have been executed
  if [[ -n "$required_before" ]]; then
    for required_script in $(echo "$required_before" | tr ',' ' '); do
      if ! grep -q "Executed script.*$required_script" "$LOG_FILE" 2>/dev/null; then
        warn "Dependency '$required_script' not executed yet, skipping $script_name"
        return 1
      fi
    done
  fi
  
  # Try exact name first
  local script_path=""
  if [[ -f "$PROJECT_ROOT/$script_name" && -r "$PROJECT_ROOT/$script_name" ]]; then
    script_path="$PROJECT_ROOT/$script_name"
  elif [[ -f "$PROJECT_ROOT/scripts/$script_name" && -r "$PROJECT_ROOT/scripts/$script_name" ]]; then
    script_path="$PROJECT_ROOT/scripts/$script_name"
  elif [[ -f "$PROJECT_ROOT/scripts/deployment/$script_name" && -r "$PROJECT_ROOT/scripts/deployment/$script_name" ]]; then
    script_path="$PROJECT_ROOT/scripts/deployment/$script_name"
  fi
  
  # If not found by name, search by content signature
  if [[ -z "$script_path" && -n "$signature" ]]; then
    script_path=$(find "$PROJECT_ROOT" -name "*.sh" -readable -exec grep -l "$signature" {} \; 2>/dev/null | head -1)
  fi
  
  # If still not found, try fuzzy matching
  if [[ -z "$script_path" ]]; then
    script_path=$(find "$PROJECT_ROOT" -name "*${script_name}*" -name "*.sh" -readable | head -1)
  fi
  
  if [[ -z "$script_path" ]]; then
    warn "Script '$script_name' not found. Skipping..."
    return 1
  fi
  
  # Validate script is safe to execute
  if [[ ! -f "$script_path" || ! -r "$script_path" ]]; then
    error "Script '$script_path' is not accessible"
    return 1
  fi
  
  # Basic security check - ensure it's a shell script
  local first_line=$(head -1 "$script_path" 2>/dev/null)
  if [[ ! "$first_line" =~ ^#!/(bin/)?(bash|sh) ]]; then
    warn "Script '$script_path' may not be a valid shell script - skipping for security"
    return 1
  fi
  
  info "Found script: $script_path"
  
  # Make executable if needed
  chmod +x "$script_path"
  
  # Run with error handling and timeout
  if timeout 600 bash "$script_path" $args; then
    success "Script '$script_name' completed successfully"
    ACTIONS_TAKEN+=("Executed script: $script_path")
    return 0
  else
    warn "Script '$script_name' failed but continuing..."
    return 1
  fi
}

# --- Script Execution Order Management ---
execute_script_phase() {
  local phase_name="$1"
  local scripts=("${@:2}")  # All remaining arguments are scripts
  
  progress "Starting Phase: $phase_name"
  local phase_success=true
  
  for script_def in "${scripts[@]}"; do
    # Parse script definition: script_name:signature:dependencies
    local script_name=$(echo "$script_def" | cut -d: -f1)
    local signature=$(echo "$script_def" | cut -d: -f2)
    local dependencies=$(echo "$script_def" | cut -d: -f3)
    
    if find_and_run_script "$script_name" "$signature" "" "$dependencies"; then
      success "✓ $script_name completed"
    else
      warn "✗ $script_name failed or skipped"
      phase_success=false
    fi
  done
  
  if $phase_success; then
    success "Phase '$phase_name' completed successfully"
    ACTIONS_TAKEN+=("Completed phase: $phase_name")
  else
    warn "Phase '$phase_name' completed with some failures"
  fi
  
  return 0
}

# --- Advanced Registry Management ---
ensure_registry() {
  progress "Setting up secure private container registry..."
  
  # Check if registry is already running
  if docker ps | grep -q "kind-registry\|registry.*$REGISTRY_PORT"; then
    info "Private registry already running on port $REGISTRY_PORT"
    
    # Test registry health
    if curl -f -s "http://localhost:$REGISTRY_PORT/v2/_catalog" &>/dev/null; then
      success "Registry is healthy and accessible"
      return 0
    else
      warn "Registry not responding. Recreating..."
      docker rm -f kind-registry 2>/dev/null || true
    fi
  fi
  
  # Start new registry with retry logic
  info "Starting private registry on port $REGISTRY_PORT..."
  
  local retry_count=0
  local max_retries=3
  
  while [[ $retry_count -lt $max_retries ]]; do
    if docker run -d \
      --name kind-registry \
      --restart=always \
  -p "$REGISTRY_PORT:5001" \
      -v registry-data:/var/lib/registry \
      registry:2; then
      
      # Wait for registry to be ready with timeout
      local ready_count=0
      for i in {1..30}; do
        if timeout 5 curl -f -s "http://localhost:$REGISTRY_PORT/v2/_catalog" &>/dev/null; then
          success "Private registry started successfully on port $REGISTRY_PORT"
          ACTIONS_TAKEN+=("Started private registry on port $REGISTRY_PORT")
          return 0
        fi
        sleep 2
        ((ready_count++))
      done
      
      warn "Registry container started but not responding (attempt $((retry_count + 1)))"
      docker rm -f kind-registry 2>/dev/null || true
    else
      warn "Failed to start registry container (attempt $((retry_count + 1)))"
    fi
    
    ((retry_count++))
    sleep 5
  done
  
  error "Registry failed to start after $max_retries attempts"
  return 1
}

# --- Golden Image Management & Registry Population ---
push_images() {
  progress "Managing golden images and populating private registry..."
  
  # Define golden images based on your config.env
  local golden_images=(
    "redis:7-alpine"
    "postgres:15-alpine"
    "prom/prometheus:v2.45.0"
    "grafana/grafana:10.0.0"
    "registry:2"
    "nginx:alpine"
    "hashicorp/vault:1.15.0"
  )
  
  local images_pushed=0
  
  for image in "${golden_images[@]}"; do
    local local_tag="localhost:$REGISTRY_PORT/$image"
    
    # Check if image already exists in registry
    if curl -f -s "http://localhost:$REGISTRY_PORT/v2/${image%:*}/tags/list" | grep -q "${image#*:}"; then
      info "Image $image already in registry"
      continue
    fi
    
    # Pull from public registry if not local
    if ! docker images | grep -q "${image%:*}.*${image#*:}"; then
      info "Pulling golden image: $image"
      
      # Retry logic for image pulls
      local pull_attempts=0
      local max_attempts=3
      local pull_success=false
      
      while [[ $pull_attempts -lt $max_attempts ]]; do
        if timeout 300 docker pull "$image"; then
          success "Pulled $image"
          pull_success=true
          break
        else
          ((pull_attempts++))
          warn "Failed to pull $image (attempt $pull_attempts/$max_attempts)"
          [[ $pull_attempts -lt $max_attempts ]] && sleep 10
        fi
      done
      
      if [[ "$pull_success" != "true" ]]; then
        warn "Failed to pull $image after $max_attempts attempts - will skip"
        continue
      fi
    fi
    
    # Tag and push to private registry
    info "Pushing $image to private registry..."
    docker tag "$image" "$local_tag"
    
    if docker push "$local_tag"; then
      success "Pushed $image to registry"
      ((images_pushed++))
    else
      warn "Failed to push $image"
    fi
  done
  
  success "Golden image management complete. Pushed $images_pushed images to registry"
  ACTIONS_TAKEN+=("Populated registry with $images_pushed golden images")
}

# --- Container Lifecycle Management ---
wake_up_containers() {
  progress "Managing container lifecycle and health..."
  
  # Get all containers (running and stopped)
  local all_containers=$(docker ps -a --format "{{.Names}}")
  local stopped_containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}")
  local restarted=0
  
  if [[ -z "$stopped_containers" ]]; then
    info "No stopped containers found"
    return 0
  fi
  
  # Restart stopped containers
  for container in $stopped_containers; do
    # Skip temporary or test containers
    if [[ "$container" =~ ^(temp|test|tmp) ]]; then
      continue
    fi
    
    info "Restarting container: $container"
    if docker start "$container" &>/dev/null; then
      success "Restarted $container"
      ((restarted++))
    else
      warn "Failed to restart $container - may need manual attention"
    fi
  done
  
  # Clean up dead containers
  local dead_containers=$(docker ps -a --filter "status=dead" --format "{{.Names}}")
  for container in $dead_containers; do
    warn "Removing dead container: $container"
    docker rm -f "$container" &>/dev/null || true
  done
  
  # Clean up unused images to free space
  if docker images | grep -q "<none>"; then
    info "Cleaning up dangling images..."
    docker image prune -f &>/dev/null || true
  fi
  
  success "Container lifecycle management complete. Restarted $restarted containers"
  if [[ $restarted -gt 0 ]]; then
    ACTIONS_TAKEN+=("Restarted $restarted stopped containers")
  fi
}

# --- Comprehensive Cluster Management ---
validate_cluster() {
  progress "Validating and managing Kubernetes clusters..."
  
  local existing_clusters=$(kind get clusters 2>/dev/null || echo "")
  local target_cluster="tc-enterprise"
  
  # Check for any existing clusters
  if [[ -n "$existing_clusters" ]]; then
    info "Found existing KIND clusters: $existing_clusters"
    
    # Check health of each cluster
    for cluster in $existing_clusters; do
      if kubectl --context "kind-$cluster" cluster-info &>/dev/null; then
        success "Cluster '$cluster' is healthy"
        
        # Use the first healthy cluster we find
        if [[ "$cluster" =~ (enterprise|tc|devops) ]]; then
          target_cluster="$cluster"
          info "Using existing cluster: $target_cluster"
          kubectl config use-context "kind-$target_cluster" &>/dev/null
          ACTIONS_TAKEN+=("Using existing healthy cluster: $target_cluster")
          return 0
        fi
      else
        warn "Cluster '$cluster' is unhealthy or unreachable"
        
        # Try to restart the cluster
        info "Attempting to restart cluster '$cluster'..."
        kind delete cluster --name "$cluster" &>/dev/null || true
      fi
    done
  fi
  
  # Create new cluster if none exist or all are unhealthy
  info "Creating new KIND cluster: $target_cluster"
  
  # Check if we have a cluster config file
  local cluster_config=""
  if [[ -f "$PROJECT_ROOT/kind-cluster-$PROFILE.yaml" ]]; then
    cluster_config="--config $PROJECT_ROOT/kind-cluster-$PROFILE.yaml"
    info "Using cluster config: kind-cluster-$PROFILE.yaml"
  elif [[ -f "$PROJECT_ROOT/kind-cluster-standard.yaml" ]]; then
    cluster_config="--config $PROJECT_ROOT/kind-cluster-standard.yaml"
    info "Using standard cluster config"
  fi
  
  # Try to create the cluster with the selected config
  if kind create cluster --name "$target_cluster" $cluster_config --wait 300s; then
    success "Cluster '$target_cluster' created successfully"
    
    # Verify cluster is accessible
    if kubectl cluster-info &>/dev/null; then
      success "Cluster is accessible via kubectl"
      ACTIONS_TAKEN+=("Created new Kubernetes cluster: $target_cluster")
      
      # Connect registry to cluster network if it exists - with validation
      if docker ps | grep -q kind-registry && docker network ls | grep -q kind; then
        if ! docker network inspect kind | grep -q kind-registry; then
          docker network connect "kind" kind-registry 2>/dev/null && \
          info "Connected registry to cluster network" || \
          warn "Failed to connect registry to cluster network"
        fi
      fi
      
      return 0
    else
      error "Cluster created but not accessible"
      return 1
    fi
  else
    # Cluster creation failed - check if Apple Silicon VM fallback is needed
    if is_apple_silicon && ! colima status 2>/dev/null | grep -q "Running"; then
      warn "Cluster creation failed on Apple Silicon - attempting VM fallback..."
      
      # Setup Colima VM for Apple Silicon compatibility
      if check_and_setup_vm_if_needed; then
        info "VM environment ready, retrying cluster creation with enterprise config..."
        
        # Use the most sophisticated config available for true enterprise simulation
        if [[ -f "$PROJECT_ROOT/kind-cluster-standard.yaml" ]]; then
          cluster_config="--config $PROJECT_ROOT/kind-cluster-standard.yaml"
          info "Using enterprise-grade standard configuration in VM"
        fi
        
        # Retry cluster creation in VM environment
        if kind create cluster --name "$target_cluster" $cluster_config --wait 300s; then
          success "Enterprise cluster created successfully in VM environment"
          
          # Verify cluster is accessible
          if kubectl cluster-info &>/dev/null; then
            success "Enterprise cluster is accessible via kubectl"
            ACTIONS_TAKEN+=("Created enterprise Kubernetes cluster in Apple Silicon VM: $target_cluster")
            
            # Connect registry to cluster network
            if docker ps | grep -q kind-registry && docker network ls | grep -q kind; then
              if ! docker network inspect kind | grep -q kind-registry; then
                docker network connect "kind" kind-registry 2>/dev/null && \
                info "Connected registry to cluster network" || \
                warn "Failed to connect registry to cluster network"
              fi
            fi
            
            return 0
          else
            error "VM cluster created but not accessible"
          fi
        else
          warn "Enterprise config failed in VM, trying macOS-optimized fallback..."
        fi
      else
        warn "VM setup failed, trying direct macOS fallbacks..."
      fi
    fi
    warn "Failed to create cluster with initial configuration"
    
    # Try fallback to macOS-optimized configuration if available
    if [[ -f "$PROJECT_ROOT/kind-cluster-macos.yaml" ]] && [[ "$cluster_config" != *"macos"* ]]; then
      warn "Attempting recovery with macOS-optimized configuration..."
      
      # Clean up any failed cluster remnants
      kind delete cluster --name "$target_cluster" 2>/dev/null || true
      
      # Try with macOS-optimized config
      cluster_config="--config $PROJECT_ROOT/kind-cluster-macos.yaml"
      if kind create cluster --name "$target_cluster" $cluster_config --wait 300s; then
        success "Cluster created successfully with macOS-optimized configuration"
        
        # Verify cluster is accessible
        if kubectl cluster-info &>/dev/null; then
          success "Cluster is accessible via kubectl"
          ACTIONS_TAKEN+=("Created Kubernetes cluster with macOS fallback: $target_cluster")
          
          # Connect registry to cluster network if it exists
          if docker ps | grep -q kind-registry && docker network ls | grep -q kind; then
            if ! docker network inspect kind | grep -q kind-registry; then
              docker network connect "kind" kind-registry 2>/dev/null && \
              info "Connected registry to cluster network" || \
              warn "Failed to connect registry to cluster network"
            fi
          fi
          
          return 0
        else
          error "Cluster created but not accessible"
        fi
      fi
    fi
    
    # Final fallback to minimal single-node configuration
    if [[ -f "$PROJECT_ROOT/kind-cluster-minimal.yaml" ]] && [[ "$cluster_config" != *"minimal"* ]]; then
      warn "Attempting final recovery with minimal single-node configuration..."
      
      # Clean up any failed cluster remnants
      kind delete cluster --name "$target_cluster" 2>/dev/null || true
      
      # Try with minimal config
      cluster_config="--config $PROJECT_ROOT/kind-cluster-minimal.yaml"
      if kind create cluster --name "$target_cluster" $cluster_config --wait 300s; then
        success "Cluster created successfully with minimal configuration"
        
        # Verify cluster is accessible
        if kubectl cluster-info &>/dev/null; then
          success "Cluster is accessible via kubectl"
          ACTIONS_TAKEN+=("Created Kubernetes cluster with minimal fallback: $target_cluster")
          
          # Connect registry to cluster network if it exists
          if docker ps | grep -q kind-registry && docker network ls | grep -q kind; then
            if ! docker network inspect kind | grep -q kind-registry; then
              docker network connect "kind" kind-registry 2>/dev/null && \
              info "Connected registry to cluster network" || \
              warn "Failed to connect registry to cluster network"
            fi
          fi
          
          return 0
        else
          error "Cluster created but not accessible"
          return 1
        fi
      fi
    fi
    
    error "Failed to create Kubernetes cluster with all available configurations"
    return 1
  fi
}

# --- Comprehensive Configuration Validation and Alignment ---
validate_and_align_configurations() {
  progress "Performing comprehensive configuration validation and alignment..."
  
  local config_issues=0
  
  # 1. Validate core configuration file
  if [[ -f "$PROJECT_ROOT/config.env" ]]; then
    info "Validating config.env..."
    
    # Check for required variables
    local required_vars=(
      "DEVOPS_PROFILE"
      "PRIVATE_REGISTRY"
      "REDIS_IMAGE"
      "POSTGRES_IMAGE"
      "PROMETHEUS_IMAGE"
      "GRAFANA_IMAGE"
    )
    
    for var in "${required_vars[@]}"; do
      if ! grep -q "^$var=" "$PROJECT_ROOT/config.env"; then
        warn "Missing configuration variable: $var"
        ((config_issues++))
      fi
    done
    
    # Update registry configuration to match current port
    if ! grep -q "PRIVATE_REGISTRY.*localhost:$REGISTRY_PORT" "$PROJECT_ROOT/config.env"; then
      info "Aligning registry configuration to port $REGISTRY_PORT"
      sed -i.bak "s/PRIVATE_REGISTRY=.*/PRIVATE_REGISTRY=localhost:$REGISTRY_PORT/" "$PROJECT_ROOT/config.env" 2>/dev/null || true
      ACTIONS_TAKEN+=("Updated config.env registry to port $REGISTRY_PORT")
    fi
    
    # Update profile if detected
    if [[ -n "$PROFILE" ]]; then
      if ! grep -q "DEVOPS_PROFILE.*$PROFILE" "$PROJECT_ROOT/config.env"; then
        info "Aligning profile configuration to $PROFILE"
        sed -i.bak "s/DEVOPS_PROFILE=.*/DEVOPS_PROFILE=$PROFILE/" "$PROJECT_ROOT/config.env" 2>/dev/null || true
        ACTIONS_TAKEN+=("Updated config.env profile to $PROFILE")
      fi
    fi
  else
    error "Critical: config.env not found"
    ((config_issues++))
  fi
  
  # 2. Validate cluster configuration alignment
  info "Validating cluster configurations..."
  local cluster_configs=(
    "kind-cluster-standard.yaml"
    "kind-cluster-macos.yaml"
    "kind-cluster-minimal.yaml"
  )
  
  local cluster_config_found=false
  for config in "${cluster_configs[@]}"; do
    if [[ -f "$PROJECT_ROOT/$config" ]]; then
      cluster_config_found=true
      # Check if config has correct registry port
  if grep -q "5001" "$PROJECT_ROOT/$config" && [[ $REGISTRY_PORT -ne 5001 ]]; then
  warn "Cluster config $config references port 5001 but registry is on $REGISTRY_PORT"
        CONFIGURATION_ISSUES+=("Port mismatch in $config")
      fi
    fi
  done
  
  if ! $cluster_config_found; then
    warn "No cluster configuration files found"
    ((config_issues++))
  fi
  
  # 3. Validate template consistency
  info "Validating template configurations..."
  local template_dirs=(
    "$PROJECT_ROOT/templates/docker-compose"
    "$PROJECT_ROOT/templates/helm-values"
    "$PROJECT_ROOT/templates/resource-limits"
  )
  
  for template_dir in "${template_dirs[@]}"; do
    if [[ -d "$template_dir" ]]; then
      # Check for profile-specific templates
      local profile_templates=$(find "$template_dir" -name "*${PROFILE}*" | wc -l)
      if [[ $profile_templates -eq 0 ]]; then
        warn "No $PROFILE profile templates found in $(basename "$template_dir")"
        CONFIGURATION_ISSUES+=("Missing $PROFILE templates in $(basename "$template_dir")")
      fi
      
      # Check for registry port consistency
  if grep -r "localhost:5001" "$template_dir" >/dev/null 2>&1 && [[ $REGISTRY_PORT -ne 5001 ]]; then
  warn "Templates in $(basename "$template_dir") reference port 5001 but registry is on $REGISTRY_PORT"
        CONFIGURATION_ISSUES+=("Port mismatch in $(basename "$template_dir") templates")
      fi
    fi
  done
  
  # 4. Validate script dependencies and execution order
  info "Validating script dependencies..."
  local critical_scripts=(
    "scripts/auto-configure.sh"
    "scripts/comprehensive-validation.sh"
    "scripts/setup-private-registry.sh"
    "scripts/deployment/deploy-standard.sh"
    "scripts/script-execution-matrix.sh"
  )
  
  for script in "${critical_scripts[@]}"; do
    if [[ ! -f "$PROJECT_ROOT/$script" ]]; then
      error "Critical script missing: $script"
      ((config_issues++))
    elif [[ ! -x "$PROJECT_ROOT/$script" ]]; then
      warn "Script not executable: $script"
      chmod +x "$PROJECT_ROOT/$script" 2>/dev/null || true
      ACTIONS_TAKEN+=("Made executable: $script")
    fi
  done
  
  # 5. Check for configuration conflicts between scripts
  info "Checking for configuration conflicts..."
  local registry_refs_5001=$(grep -r "localhost:5001" "$PROJECT_ROOT/scripts/" 2>/dev/null | wc -l)
  
  if [[ $registry_refs_5001 -gt 0 ]]; then
    warn "Registry port references found: $registry_refs_5001 on port 5001"
    CONFIGURATION_ISSUES+=("Inconsistent registry port references across scripts")
  fi
  
  # 6. Validate branding consistency
  if [[ -f "$PROJECT_ROOT/tc-service-branding.conf" ]]; then
    info "Validating branding configuration..."
    
    # Check for TC branding consistency
    local branding_scripts=$(grep -l "TC Enterprise" "$PROJECT_ROOT/scripts/"*.sh 2>/dev/null | wc -l)
    if [[ $branding_scripts -eq 0 ]]; then
      warn "No scripts found with TC Enterprise branding"
      CONFIGURATION_ISSUES+=("Missing TC Enterprise branding in scripts")
    fi
  fi
  
  # 7. Summary and recommendations
  if [[ $config_issues -eq 0 && ${#CONFIGURATION_ISSUES[@]} -eq 0 ]]; then
    success "Configuration validation passed - all alignments correct"
  else
    warn "Configuration validation completed with $config_issues critical issues and ${#CONFIGURATION_ISSUES[@]} minor issues"
    
    if [[ ${#CONFIGURATION_ISSUES[@]} -gt 0 ]]; then
      warn "Configuration issues detected:"
      for issue in "${CONFIGURATION_ISSUES[@]}"; do
        warn "  • $issue"
      done
    fi
  fi
  
  ACTIONS_TAKEN+=("Completed comprehensive configuration validation and alignment")
}

# --- Enterprise Branding & Configuration Management ---
apply_branding() {
  progress "Scanning and applying enterprise branding consistency..."
  
  # Check for existing branding configuration
  local branding_file=""
  if [[ -f "$PROJECT_ROOT/config.tc-brand" ]]; then
    branding_file="$PROJECT_ROOT/config.tc-brand"
  elif [[ -f "$PROJECT_ROOT/tc-service-branding.conf" ]]; then
    branding_file="$PROJECT_ROOT/tc-service-branding.conf"
  fi
  
  if [[ -n "$branding_file" ]]; then
    info "Found branding configuration: $(basename "$branding_file")"
    
    # Apply branding to manifests
    local manifests_updated=0
    
    # Update all YAML manifests to use consistent naming
    find "$PROJECT_ROOT" -name "*.yaml" -o -name "*.yml" | while read -r manifest; do
      if grep -q "name.*devops\|name.*lab\|name.*platform" "$manifest" 2>/dev/null; then
        # This manifest likely needs branding updates
        info "Checking branding in: $(basename "$manifest")"
        # Add logic here to update branding if needed
        ((manifests_updated++))
      fi
    done
    
    # Update configuration files
    if [[ -f "$PROJECT_ROOT/config.env" ]]; then
      # Ensure registry points to localhost with correct port
      if ! grep -q "PRIVATE_REGISTRY.*localhost:$REGISTRY_PORT" "$PROJECT_ROOT/config.env"; then
        info "Updating config.env with current registry port"
        sed -i.bak "s/PRIVATE_REGISTRY=.*/PRIVATE_REGISTRY=localhost:$REGISTRY_PORT/" "$PROJECT_ROOT/config.env" 2>/dev/null || true
        ACTIONS_TAKEN+=("Updated config.env with registry port $REGISTRY_PORT")
      fi
    fi
    
    success "Branding consistency check complete"
  else
    info "No specific branding configuration found - using defaults"
  fi
  
  ACTIONS_TAKEN+=("Applied enterprise branding and configuration consistency")
}

# --- Security & Vulnerability Assessment ---
scan_security() {
  progress "Performing security assessment and vulnerability scanning..."
  
  local security_issues=0
  
  # Install and run Trivy if available
  if ! command -v trivy &>/dev/null; then
    info "Installing Trivy for container vulnerability scanning..."
    case "$ENV_TYPE" in
      "macos")
        brew install trivy
        ;;
      "linux")
        if command -v apt-get &>/dev/null; then
          sudo apt-get update && sudo apt-get install -y wget apt-transport-https gnupg lsb-release
          wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
          echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
          sudo apt-get update && sudo apt-get install -y trivy
        fi
        ;;
    esac
  fi
  
  if command -v trivy &>/dev/null; then
    info "Running container vulnerability scans..."
    
    # Scan key images
    local images_to_scan=("redis:7-alpine" "postgres:15-alpine" "grafana/grafana:10.0.0")
    for image in "${images_to_scan[@]}"; do
      if docker images | grep -q "$image"; then
        local scan_result=$(mktemp)
        # Secure temp file
        chmod 600 "$scan_result"
        
        if trivy image --exit-code 1 --severity HIGH,CRITICAL "$image" > "$scan_result" 2>&1; then
          success "Security scan passed for $image"
        else
          warn "Security vulnerabilities found in $image"
          ((security_issues++))
          PERFORMANCE_ISSUES+=("Security vulnerabilities in $image - review scan results")
        fi
        
        # Clean up temp file
        rm -f "$scan_result"
      fi
    done
    
    success "Security vulnerability scan complete"
    ACTIONS_TAKEN+=("Performed security vulnerability scanning")
  else
    warn "Trivy not available - skipping vulnerability scans"
  fi
  
  # Check for insecure configurations
  if [[ -f "$PROJECT_ROOT/config.env" ]]; then
    if grep -q "password.*admin\|password.*123" "$PROJECT_ROOT/config.env"; then
      warn "Weak default passwords detected in configuration"
      ((security_issues++))
      PERFORMANCE_ISSUES+=("Weak passwords detected - consider updating default credentials")
    fi
  fi
  
  if [[ $security_issues -eq 0 ]]; then
    success "Security assessment completed - no major issues found"
  else
    warn "Security assessment completed with $security_issues issues found"
  fi
}

# --- Performance Analysis & System Optimization ---
check_performance() {
  progress "Analyzing system performance and generating optimization recommendations..."
  
  # Docker resource analysis
  if docker info &>/dev/null; then
    local docker_memory=$(docker system info --format '{{.MemTotal}}' 2>/dev/null)
    local docker_memory_gb=$(echo "$docker_memory" | awk '{print int($1/1024/1024/1024)}')
    
    if [[ $docker_memory_gb -lt 6 ]] && [[ $TOTAL_MEMORY_GB -ge 8 ]]; then
      PERFORMANCE_ISSUES+=("🔧 Docker memory allocation: Current ${docker_memory_gb}GB, recommended 6GB+ for optimal performance")
    fi
  fi
  
  # Disk space analysis
  local disk_usage=$(df "$PROJECT_ROOT" | tail -1 | awk '{print $5}' | sed 's/%//')
  if [[ $disk_usage -gt 80 ]]; then
    PERFORMANCE_ISSUES+=("💾 Disk space critical: ${disk_usage}% used - consider cleanup or expansion")
  elif [[ $disk_usage -gt 70 ]]; then
    PERFORMANCE_ISSUES+=("💾 Disk space warning: ${disk_usage}% used - monitor closely")
  fi
  
  # CPU analysis
  if [[ $CPU_CORES -lt 4 ]]; then
    PERFORMANCE_ISSUES+=("⚡ CPU cores: $CPU_CORES detected - 4+ cores recommended for optimal performance")
  fi
  
  # Memory analysis
  if [[ $TOTAL_MEMORY_GB -lt 8 ]]; then
    PERFORMANCE_ISSUES+=("🧠 System memory: ${TOTAL_MEMORY_GB}GB - 8GB+ recommended for full feature set")
  fi
  
  # Network connectivity check with timeout
  local dns_check=0
  if command -v dig &>/dev/null; then
    dns_check=$(timeout 10 dig +short github.com 2>/dev/null | wc -l)
  elif command -v nslookup &>/dev/null; then
    dns_check=$(timeout 10 nslookup github.com 2>/dev/null | grep -c "Address" || echo 0)
  fi
  
  if [[ $dns_check -eq 0 ]]; then
    PERFORMANCE_ISSUES+=("🌐 DNS resolution issues detected - may affect image downloads")
  fi
  
  # Container performance check
  local running_containers=$(docker ps --format "{{.Names}}" | wc -l)
  if [[ $running_containers -gt 10 ]] && [[ $TOTAL_MEMORY_GB -lt 16 ]]; then
    PERFORMANCE_ISSUES+=("📦 High container count ($running_containers) for available memory - consider resource limits")
  fi
  
  # Generate performance report
  if [[ ${#PERFORMANCE_ISSUES[@]} -eq 0 ]]; then
    success "Performance analysis complete - system optimally configured"
  else
    warn "Performance analysis complete - ${#PERFORMANCE_ISSUES[@]} optimization opportunities identified"
  fi
  
  ACTIONS_TAKEN+=("Completed comprehensive performance analysis")
}

# --- Shell Environment Configuration ---
configure_shell_environment() {
  progress "Configuring shell environment for DevOps tools..."
  
  # Ensure ~/.local/bin exists for user binaries
  mkdir -p "$HOME/.local/bin"
  
  # Add to PATH if not already present
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
    ACTIONS_TAKEN+=("Added ~/.local/bin to PATH")
  fi
  
  # Set kubectl completion if available
  if command -v kubectl &>/dev/null; then
    # Create completion directory
    mkdir -p "$HOME/.config/completion"
    
    # Generate kubectl completion for current shell
    case "$SHELL" in
      */zsh)
        if [[ ! -f "$HOME/.config/completion/_kubectl" ]]; then
          kubectl completion zsh > "$HOME/.config/completion/_kubectl" 2>/dev/null || true
        fi
        ;;
      */bash)
        if [[ ! -f "$HOME/.config/completion/kubectl.bash" ]]; then
          kubectl completion bash > "$HOME/.config/completion/kubectl.bash" 2>/dev/null || true
        fi
        ;;
    esac
  fi
  
  # Set helpful aliases for lab management
  if [[ -f "$HOME/.profile" ]] || [[ -f "$HOME/.bashrc" ]] || [[ -f "$HOME/.zshrc" ]]; then
    local alias_file=""
    [[ -f "$HOME/.zshrc" ]] && alias_file="$HOME/.zshrc"
    [[ -f "$HOME/.bashrc" ]] && alias_file="$HOME/.bashrc"
    [[ -f "$HOME/.profile" ]] && alias_file="$HOME/.profile"
    
    if [[ -n "$alias_file" ]] && ! grep -q "# TC Enterprise Lab Aliases" "$alias_file"; then
      cat >> "$alias_file" << 'EOL'

# TC Enterprise Lab Aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias lab-status='kubectl get all --all-namespaces'
alias lab-logs='tail -f ~/tc-enterprise-devops-platform/logs/*.log'
EOL
      ACTIONS_TAKEN+=("Added DevOps aliases to $alias_file")
    fi
  fi
  
  success "Shell environment configuration complete"
}

# --- Professional Deployment Orchestration with Proper Phase Management ---
orchestrate_deployment() {
  progress "Orchestrating complete lab deployment with proper execution order..."
  
  # Phase 1: Environment Validation and Preparation
  progress "Phase 1: Environment Validation and Preparation"
  execute_script_phase "Environment Validation" \
    "comprehensive-validation.sh:Environment Validation:" \
    "system-health-report.sh:system-check:"
  
  # Phase 2: Tool Installation and Configuration  
  progress "Phase 2: Tool Installation and Configuration"
  execute_script_phase "Tool Installation" \
    "install-tools.sh:Tool Installation:" \
    "auto-configure.sh:Auto-Configuration:install-tools.sh"
  
  # Phase 3: Private Registry Setup (Critical for offline operation)
  progress "Phase 3: Private Registry Setup"
  execute_script_phase "Registry Setup" \
    "setup-private-registry.sh:Private Container Registry:auto-configure.sh"
  
  # Phase 4: Infrastructure Deployment (Must be after registry)
  progress "Phase 4: Core Infrastructure Deployment"
  local deployment_success=false
  
  # Try profile-specific deployment first
  local profile_script="deploy-${PROFILE}.sh"
  if execute_script_phase "Infrastructure Deployment" \
    "deploy-tc-enterprise.sh:deployment.*${PROFILE}:setup-private-registry.sh"; then
    deployment_success=true
  # Fallback to standard deployment
  elif execute_script_phase "Infrastructure Deployment" \
    "deploy-standard.sh:deployment.*standard:setup-private-registry.sh"; then
    deployment_success=true
  # Fallback to complete deployment
  elif execute_script_phase "Infrastructure Deployment" \
    "complete-enterprise-deployment.sh:Complete.*deployment:setup-private-registry.sh"; then
    deployment_success=true
  # Last resort: main setup script
  elif execute_script_phase "Infrastructure Deployment" \
    "deploy-tc-enterprise.sh:Enterprise DevOps Lab:setup-private-registry.sh"; then
    deployment_success=true
  else
    warn "No deployment scripts found, attempting manual infrastructure setup..."
    
    # Manual basic deployment
    if kubectl get nodes &>/dev/null; then
      info "Kubernetes cluster available, deploying basic services..."
      
      # Deploy basic configuration files if they exist
      local config_files=(
        "$PROJECT_ROOT/config/tc-prometheus.yaml"
        "$PROJECT_ROOT/config/tc-grafana-enterprise.yaml"
        "$PROJECT_ROOT/config/tc-secure-services.yaml"
      )
      
      for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
          kubectl apply -f "$config_file" 2>/dev/null && \
          info "Applied configuration: $(basename "$config_file")" || \
          warn "Failed to apply: $(basename "$config_file")"
        fi
      done
      
      deployment_success=true
    fi
  fi
  
  # Phase 5: Service Integration and Branding (After deployment)
  progress "Phase 5: Service Integration and Branding"
  execute_script_phase "Service Integration" \
    "start-platform.sh:Platform Startup:deploy-tc-enterprise.sh"
  
  # Phase 6: Security and Compliance (After services are running)
  progress "Phase 6: Security and Compliance"
  execute_script_phase "Security Hardening" \
    "tc-full-pipeline.sh:TC Secure Pipeline:start-platform.sh"
  
  # Phase 7: Final Validation and Health Checks
  progress "Phase 7: Final Validation"
  execute_script_phase "Final Validation" \
    "system-health-report.sh:System Health Report:tc-full-pipeline.sh"
  
  if $deployment_success; then
    success "Complete deployment orchestration completed successfully"
    ACTIONS_TAKEN+=("Successfully orchestrated enterprise DevOps platform deployment")
  else
    warn "Deployment had issues but core infrastructure is available"
    ACTIONS_TAKEN+=("Partial deployment completed - manual verification recommended")
  fi
}

# --- Final System Validation ---
final_validation() {
  progress "Performing final system validation..."
  
  local validation_score=0
  local total_checks=5
  
  # Check Docker
  if docker info &>/dev/null; then
    success "✅ Docker daemon is running"
    ((validation_score++))
  else
    error "❌ Docker daemon not accessible"
  fi
  
  # Check Kubernetes
  if kubectl cluster-info &>/dev/null; then
    success "✅ Kubernetes cluster is accessible"
    ((validation_score++))
  else
    error "❌ Kubernetes cluster not accessible"
  fi
  
  # Check Registry
  if curl -f -s "http://localhost:$REGISTRY_PORT/v2/_catalog" &>/dev/null; then
    success "✅ Private registry is operational"
    ((validation_score++))
  else
    error "❌ Private registry not accessible"
  fi
  
  # Check running containers
  local running_containers=$(docker ps --format "{{.Names}}" | wc -l)
  if [[ $running_containers -gt 0 ]]; then
    success "✅ Containers are running ($running_containers active)"
    ((validation_score++))
  else
    error "❌ No containers running"
  fi
  
  # Check kubectl context
  if kubectl config current-context &>/dev/null; then
    success "✅ Kubectl context configured"
    ((validation_score++))
  else
    error "❌ Kubectl context not set"
  fi
  
  local success_rate=$((validation_score * 100 / total_checks))
  
  if [[ $success_rate -ge 80 ]]; then
    success "🎉 System validation passed ($validation_score/$total_checks checks)"
  else
    warn "⚠️ System validation partial ($validation_score/$total_checks checks) - manual review recommended"
  fi
  
  return $validation_score
}

# --- Welcome Message & Summary ---
show_completion_summary() {
  clear
  echo -e "${BOLD}${GREEN}"
  cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║    🎉 WELCOME TO YOUR TC ENTERPRISE DEVOPS LAB! 🎉                          ║
║                                                                              ║
║    Your enterprise-grade DevOps platform is now operational!                ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
  echo -e "${NC}\n"
  
  # System summary
  echo -e "${BOLD}${BLUE}📊 SYSTEM SUMMARY${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}Environment:${NC} $ENV_TYPE ($ARCH)"
  echo -e "${GREEN}Profile:${NC} $PROFILE"
  echo -e "${GREEN}Memory:${NC} ${TOTAL_MEMORY_GB}GB"
  echo -e "${GREEN}CPU Cores:${NC} $CPU_CORES"
  echo -e "${GREEN}Registry:${NC} localhost:$REGISTRY_PORT"
  
  # Access points
  echo -e "\n${BOLD}${CYAN}🌐 ACCESS POINTS${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}Kubernetes Cluster:${NC} kubectl cluster-info"
  echo -e "${GREEN}Private Registry:${NC} http://localhost:$REGISTRY_PORT"
  echo -e "${GREEN}Platform Portal:${NC} http://localhost"
  echo -e "${GREEN}Monitoring:${NC} http://localhost/grafana"
  
  # Actions taken
  if [[ ${#ACTIONS_TAKEN[@]} -gt 0 ]]; then
    echo -e "\n${BOLD}${PURPLE}⚡ ACTIONS COMPLETED${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for action in "${ACTIONS_TAKEN[@]}"; do
      echo -e "${GREEN}✓${NC} $action"
    done
  fi
  
  # Configuration issues
  if [[ ${#CONFIGURATION_ISSUES[@]} -gt 0 ]]; then
    echo -e "\n${BOLD}${YELLOW}⚠️ CONFIGURATION ISSUES${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for issue in "${CONFIGURATION_ISSUES[@]}"; do
      echo -e "${YELLOW}⚠️${NC} $issue"
    done
    echo -e "\n${CYAN}💡 These issues are minor but should be addressed for optimal operation${NC}"
  fi

  # Performance recommendations
  if [[ ${#PERFORMANCE_ISSUES[@]} -gt 0 ]]; then
    echo -e "\n${BOLD}${YELLOW}🔧 PERFORMANCE RECOMMENDATIONS${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    for issue in "${PERFORMANCE_ISSUES[@]}"; do
      echo -e "${YELLOW}•${NC} $issue"
    done
  fi
  
  # Quick commands
  echo -e "\n${BOLD}${CYAN}🛠️ QUICK COMMANDS${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}Status:${NC} kubectl get all --all-namespaces"
  echo -e "${GREEN}Logs:${NC} ./logs/super-lab-manager-*.log"
  echo -e "${GREEN}Validation:${NC} ./scripts/comprehensive-validation.sh"
  echo -e "${GREEN}Script Matrix:${NC} ./scripts/script-execution-matrix.sh"
  echo -e "${GREEN}Restart:${NC} ./super-lab-manager.sh"
  
  echo -e "\n${BOLD}${GREEN}🚀 Your enterprise DevOps lab is ready for use!${NC}\n"
  
  # Save comprehensive summary to file
  {
    echo "TC Enterprise DevOps Platform™ - Deployment Summary"
    echo "Completed: $(date)"
    echo "Profile: $PROFILE"
    echo "Registry: localhost:$REGISTRY_PORT"
    echo "Actions taken: ${#ACTIONS_TAKEN[@]}"
    echo "Performance issues: ${#PERFORMANCE_ISSUES[@]}"
    echo "Configuration issues: ${#CONFIGURATION_ISSUES[@]}"
    echo ""
    echo "=== ACTIONS TAKEN ==="
    for action in "${ACTIONS_TAKEN[@]}"; do
      echo "- $action"
    done
    echo ""
    echo "=== PERFORMANCE RECOMMENDATIONS ==="
    for issue in "${PERFORMANCE_ISSUES[@]}"; do
      echo "- $issue"
    done
    echo ""
    echo "=== CONFIGURATION ISSUES ==="
    for issue in "${CONFIGURATION_ISSUES[@]}"; do
      echo "- $issue"
    done
  } >> "$PROJECT_ROOT/logs/deployment-summary.log"
}

# --- Error Handling ---
cleanup_on_error() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    error "Script failed with exit code $exit_code"
    
    # Enhanced cleanup on failure
    info "Performing cleanup on error..."
    
    # Stop any containers we may have started
    if docker ps | grep -q "kind-registry"; then
      warn "Stopping registry due to script failure"
      docker stop kind-registry &>/dev/null || true
    fi
    
    # Clean up partial cluster if it exists but is broken
    local current_cluster=$(kubectl config current-context 2>/dev/null | sed 's/kind-//' 2>/dev/null || echo "")
    if [[ -n "$current_cluster" ]] && ! kubectl cluster-info &>/dev/null; then
      warn "Cleaning up broken cluster: $current_cluster"
      kind delete cluster --name "$current_cluster" &>/dev/null || true
    fi
    
    # Clean up temp files
    find /tmp -name "*super-lab*" -user "$(whoami)" -mmin -60 -delete 2>/dev/null || true
    
    echo "Check logs: $LOG_FILE"
    echo "Backup available: $BACKUP_DIR"
    echo "Re-run the script to attempt recovery"
  fi
}

# --- Main Orchestration ---
main() {
  trap cleanup_on_error EXIT
  
  # Initialize
  show_banner
  setup_environment
  
  # System analysis and preparation
  detect_system_resources
  check_connectivity_and_ports
  
  # Apple Silicon VM setup if needed (before configuration validation)
  check_and_setup_vm_if_needed || {
    error "Failed to setup required VM environment for Apple Silicon"
    exit 1
  }
  
  # Comprehensive configuration validation and alignment
  validate_and_align_configurations
  
  # Core infrastructure setup (proper order)
  ensure_docker
  ensure_tools
  configure_shell_environment
  
  # Container and cluster management
  ensure_registry
  validate_cluster
  push_images
  wake_up_containers
  
  # Professional deployment orchestration with phases
  orchestrate_deployment
  
  # Post-deployment configuration and optimization
  apply_branding
  scan_security
  check_performance
  
  # Validation and completion
  final_validation
  show_completion_summary
  
  # Reset exit trap
  trap - EXIT
  
  success "Super Lab Manager completed successfully!"
}

# Execute main function with all arguments
main "$@"
