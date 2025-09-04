#!/bin/bash
set -euo pipefail

# Enterprise DevOps Lab - System Resource Detection & Auto-Configuration
# Automatically adapts to any hardware environment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] INFO:${NC} $1"
}

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Detect CPU architecture
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64|amd64)
            echo "amd64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        armv7l)
            echo "armv7"
            ;;
        *)
            echo "$arch"
            ;;
    esac
}

# Get system resources
get_system_resources() {
    local os=$(detect_os)
    local resources=()
    
    case $os in
        "macos")
            # macOS resource detection
            local total_memory_bytes=$(sysctl -n hw.memsize)
            local total_memory_gb=$((total_memory_bytes / 1024 / 1024 / 1024))
            local cpu_cores=$(sysctl -n hw.ncpu)
            local cpu_brand=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
            ;;
        "linux")
            # Linux resource detection
            local total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
            local total_memory_gb=$((total_memory_kb / 1024 / 1024))
            local cpu_cores=$(nproc)
            local cpu_brand=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | xargs)
            ;;
        *)
            # Default fallback
            local total_memory_gb=8
            local cpu_cores=4
            local cpu_brand="Unknown"
            warn "Unknown OS, using default resource values"
            ;;
    esac
    
    echo "$total_memory_gb $cpu_cores $cpu_brand"
}

# Calculate optimal resource allocation
calculate_resources() {
    local memory_gb=$1
    local cpu_cores=$2
    local config=()
    
    # Memory-based configuration tiers
    if [ $memory_gb -ge 32 ]; then
        # High-end: 32GB+ RAM
        config[0]="large"           # profile
        config[1]=3                 # control_plane_nodes
        config[2]=3                 # worker_nodes
        config[3]="2Gi"            # pod_memory_limit
        config[4]="1000m"          # pod_cpu_limit
        config[5]=100               # max_pods_per_node
        config[6]="1Gi"            # kube_reserved_memory
        config[7]="500m"           # kube_reserved_cpu
        config[8]="512Mi"          # system_reserved_memory
        config[9]="250m"           # system_reserved_cpu
    elif [ $memory_gb -ge 16 ]; then
        # Medium: 16-31GB RAM
        config[0]="medium"
        config[1]=1                 # single control plane for stability
        config[2]=2                 # two workers for workload distribution
        config[3]="1Gi"
        config[4]="750m"
        config[5]=75
        config[6]="768Mi"
        config[7]="300m"
        config[8]="512Mi"
        config[9]="200m"
    elif [ $memory_gb -ge 8 ]; then
        # Standard: 8-15GB RAM
        config[0]="standard"
        config[1]=1
        config[2]=1
        config[3]="512Mi"
        config[4]="500m"
        config[5]=50
        config[6]="512Mi"
        config[7]="200m"
        config[8]="256Mi"
        config[9]="100m"
    else
        # Minimal: <8GB RAM
        config[0]="minimal"
        config[1]=1
        config[2]=0                 # control plane only, no separate workers
        config[3]="256Mi"
        config[4]="250m"
        config[5]=30
        config[6]="256Mi"
        config[7]="100m"
        config[8]="128Mi"
        config[9]="50m"
    fi
    
    # CPU-based adjustments
    if [ $cpu_cores -le 2 ]; then
        # Low CPU: reduce resource reservations
        config[7]=$((${config[7]%m} / 2))m  # halve CPU reservations
        config[9]=$((${config[9]%m} / 2))m
    fi
    
    echo "${config[@]}"
}

# Generate dynamic KIND cluster configuration
generate_kind_config() {
    local profile=$1
    local control_plane_nodes=$2
    local worker_nodes=$3
    local pod_memory_limit=$4
    local pod_cpu_limit=$5
    local max_pods=$6
    local kube_reserved_memory=$7
    local kube_reserved_cpu=$8
    local system_reserved_memory=$9
    local system_reserved_cpu=${10}
    
    local arch=$(detect_arch)
    local config_file="kind-cluster-${profile}.yaml"
    
    cat > "$config_file" << EOF
# Enterprise KIND Cluster Configuration
# Profile: ${profile} | Arch: ${arch} | Auto-generated on $(date)
# Resources: ${control_plane_nodes} control plane(s), ${worker_nodes} worker(s)

kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: enterprise-devops-${profile}
nodes:
EOF

    # Generate control plane nodes
    for i in $(seq 1 $control_plane_nodes); do
        local node_suffix=""
        if [ $control_plane_nodes -gt 1 ]; then
            node_suffix="-$i"
        fi
        
        cat >> "$config_file" << EOF
  # Control Plane Node${node_suffix}
  - role: control-plane
    kubeadmConfigPatches:
    - |
      kind: InitConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "node-role.kubernetes.io/control-plane=true,profile=${profile}"
          max-pods: "${max_pods}"
          kube-reserved: "cpu=${kube_reserved_cpu},memory=${kube_reserved_memory}"
          system-reserved: "cpu=${system_reserved_cpu},memory=${system_reserved_memory}"
          cgroup-driver: "systemd"
          container-runtime-endpoint: "unix:///run/containerd/containerd.sock"
    - |
      kind: ClusterConfiguration
      etcd:
        local:
          dataDir: /var/lib/etcd
          serverCertSANs:
          - localhost
          - 127.0.0.1
      apiServer:
        extraArgs:
          enable-admission-plugins: NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook
          max-requests-inflight: "$((max_pods * 4))"
          max-mutating-requests-inflight: "$((max_pods * 2))"
          audit-log-maxage: "30"
          audit-log-maxbackup: "3"
          audit-log-maxsize: "100"
      controllerManager:
        extraArgs:
          node-monitor-grace-period: "10s"
          node-monitor-period: "5s"
          pod-eviction-timeout: "30s"
          terminated-pod-gc-threshold: "100"
      scheduler:
        extraArgs:
          bind-timeout-seconds: "10"
    extraPortMappings:
    - containerPort: 80
      hostPort: 8080
      protocol: TCP
    - containerPort: 443
      hostPort: 8443
      protocol: TCP
    - containerPort: 30000
      hostPort: 30000
      protocol: TCP
    - containerPort: 30001
      hostPort: 30001
      protocol: TCP
    - containerPort: 30002
      hostPort: 30002
      protocol: TCP
EOF
    done

    # Generate worker nodes
    for i in $(seq 1 $worker_nodes); do
        cat >> "$config_file" << EOF
  # Worker Node $i
  - role: worker
    kubeadmConfigPatches:
    - |
      kind: JoinConfiguration
      nodeRegistration:
        kubeletExtraArgs:
          node-labels: "node-type=worker,workload=general,profile=${profile}"
          max-pods: "${max_pods}"
          kube-reserved: "cpu=${kube_reserved_cpu},memory=${kube_reserved_memory}"
          system-reserved: "cpu=${system_reserved_cpu},memory=${system_reserved_memory}"
          cgroup-driver: "systemd"
          container-runtime-endpoint: "unix:///run/containerd/containerd.sock"
EOF
    done

    # Add networking and feature gates
    cat >> "$config_file" << EOF

# Network Configuration
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/12"
  disableDefaultCNI: false
  kubeProxyMode: "iptables"

# Feature Gates (compatible across Kubernetes versions)
featureGates:
  EphemeralContainers: true
  CronJobTimeZone: true
  PodAndContainerStatsFromCRI: true
  GracefulNodeShutdown: true
  NodeSwap: false

# Container runtime configuration
containerdConfigPatches:
- |
  [plugins."io.containerd.grpc.v1.cri".containerd]
    snapshotter = "overlayfs"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
EOF

    echo "$config_file"
}

# Generate resource limit templates
generate_resource_templates() {
    local profile=$1
    local pod_memory_limit=$2
    local pod_cpu_limit=$3
    
    # Create templates directory
    mkdir -p templates/resource-limits
    
    # Generate LimitRange template
    cat > "templates/resource-limits/limitrange-${profile}.yaml" << EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits-${profile}
  namespace: default
spec:
  limits:
  - default:
      memory: "${pod_memory_limit}"
      cpu: "${pod_cpu_limit}"
    defaultRequest:
      memory: "$((${pod_memory_limit%Mi} / 4))Mi"
      cpu: "$((${pod_cpu_limit%m} / 4))m"
    type: Container
  - max:
      memory: "$((${pod_memory_limit%Mi} * 2))Mi"
      cpu: "$((${pod_cpu_limit%m} * 2))m"
    min:
      memory: "64Mi"
      cpu: "50m"
    type: Container
EOF

    # Generate ResourceQuota template
    cat > "templates/resource-limits/resourcequota-${profile}.yaml" << EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota-${profile}
  namespace: default
spec:
  hard:
    requests.cpu: "$((${pod_cpu_limit%m} * 10))m"
    requests.memory: "$((${pod_memory_limit%Mi} * 10))Mi"
    limits.cpu: "$((${pod_cpu_limit%m} * 20))m"
    limits.memory: "$((${pod_memory_limit%Mi} * 20))Mi"
    pods: "50"
    services: "10"
    persistentvolumeclaims: "10"
EOF

    # Generate NetworkPolicy template
    cat > "templates/resource-limits/networkpolicy-${profile}.yaml" << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-${profile}
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace-${profile}
  namespace: default
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: default
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: default
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
EOF
    
    info "Generated resource templates for $profile profile"
}

# Generate Helm values templates
generate_helm_templates() {
    local profile=$1
    local pod_memory_limit=$2
    local pod_cpu_limit=$3
    
    mkdir -p templates/helm-values
    
    # Prometheus values
    cat > "templates/helm-values/prometheus-${profile}.yaml" << EOF
# Prometheus configuration for ${profile} profile
prometheus:
  prometheusSpec:
    resources:
      requests:
        memory: "$((${pod_memory_limit%Mi} / 2))Mi"
        cpu: "$((${pod_cpu_limit%m} / 2))m"
      limits:
        memory: "${pod_memory_limit}"
        cpu: "${pod_cpu_limit}"
    retention: 7d
    retentionSize: 10GB
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 20Gi

grafana:
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "200m"
      
alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        memory: "128Mi"
        cpu: "50m"
      limits:
        memory: "256Mi"
        cpu: "100m"
EOF

    # ArgoCD values
    cat > "templates/helm-values/argocd-${profile}.yaml" << EOF
# ArgoCD configuration for ${profile} profile
global:
  image:
    tag: "v2.8.4"

controller:
  resources:
    requests:
      memory: "$((${pod_memory_limit%Mi} / 2))Mi"
      cpu: "$((${pod_cpu_limit%m} / 2))m"
    limits:
      memory: "${pod_memory_limit}"
      cpu: "${pod_cpu_limit}"

server:
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "200m"

repoServer:
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "200m"
EOF

    # Redis values
    cat > "templates/helm-values/redis-${profile}.yaml" << EOF
# Redis configuration for ${profile} profile
master:
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"

replica:
  replicaCount: 1
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"

sentinel:
  enabled: true
  resources:
    requests:
      memory: "64Mi"
      cpu: "50m"
    limits:
      memory: "128Mi"
      cpu: "100m"
EOF

    info "Generated Helm values templates for $profile profile"
}

# Generate Docker Compose templates
generate_docker_compose_templates() {
    local profile=$1
    local memory_gb=$2
    
    mkdir -p templates/docker-compose
    
    # Calculate memory limits for Docker containers
    local redis_memory="256m"
    local postgres_memory="512m"
    local vault_memory="256m"
    
    if [ $memory_gb -ge 16 ]; then
        redis_memory="512m"
        postgres_memory="1g"
        vault_memory="512m"
    elif [ $memory_gb -ge 32 ]; then
        redis_memory="1g"
        postgres_memory="2g"
        vault_memory="1g"
    fi
    
    cat > "templates/docker-compose/infrastructure-${profile}.yaml" << EOF
# Infrastructure Docker Compose for ${profile} profile
# Memory limits optimized for ${memory_gb}GB system

version: '3.8'

services:
  # Redis HA Setup
  redis-master:
    image: localhost:5000/redis:7-alpine
    container_name: redis-master-${profile}
    deploy:
      resources:
        limits:
          memory: ${redis_memory}
        reservations:
          memory: 128m
    ports:
      - "6379:6379"
    volumes:
      - redis_master_data:/data
    networks:
      - devops-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

  redis-replica:
    image: localhost:5000/redis:7-alpine
    container_name: redis-replica-${profile}
    deploy:
      resources:
        limits:
          memory: ${redis_memory}
        reservations:
          memory: 128m
    ports:
      - "6380:6379"
    command: redis-server --replicaof redis-master 6379
    depends_on:
      redis-master:
        condition: service_healthy
    volumes:
      - redis_replica_data:/data
    networks:
      - devops-network

  # PostgreSQL HA
  postgres:
    image: localhost:5000/postgres:15-alpine
    container_name: postgres-${profile}
    deploy:
      resources:
        limits:
          memory: ${postgres_memory}
        reservations:
          memory: 256m
    environment:
      POSTGRES_DB: devops_db
      POSTGRES_USER: devops_user
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD:-changeme123}
      PGDATA: /var/lib/postgresql/data/pgdata
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - devops-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U devops_user -d devops_db"]
      interval: 10s
      timeout: 5s
      retries: 3

  # HashiCorp Vault
  vault:
    image: localhost:5000/vault:1.15.0
    container_name: vault-${profile}
    deploy:
      resources:
        limits:
          memory: ${vault_memory}
        reservations:
          memory: 128m
    cap_add:
      - IPC_LOCK
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: \${VAULT_ROOT_TOKEN:-dev-token-123}
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    ports:
      - "8200:8200"
    networks:
      - devops-network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8200/v1/sys/health"]
      interval: 10s
      timeout: 5s
      retries: 3

volumes:
  redis_master_data:
  redis_replica_data:
  postgres_data:

networks:
  devops-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF

    info "Generated Docker Compose template for $profile profile"
}

# Generate deployment scripts
generate_deployment_scripts() {
    local profile=$1
    local config_file=$2
    
    mkdir -p scripts/deployment
    
    # Main deployment script
    cat > "scripts/deployment/deploy-${profile}.sh" << 'EOF'
#!/bin/bash
set -euo pipefail

# Auto-detected or overridden by config.env
PROFILE="${DEVOPS_PROFILE:-standard}"
CONFIG_FILE="kind-cluster-${PROFILE}.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load configuration variables
if [ -f "$ROOT_DIR/config.env" ]; then
    source "$ROOT_DIR/config.env"
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites for ${PROFILE} profile..."
    
    local missing_tools=()
    
    for tool in docker kubectl kind helm; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please run: ./scripts/install-tools.sh"
        exit 1
    fi
    
    log "All prerequisites satisfied"
}

# Deploy infrastructure
deploy_infrastructure() {
    log "Deploying infrastructure with ${PROFILE} profile..."
    
    # Start Docker Compose infrastructure
    if [ -f "$ROOT_DIR/templates/docker-compose/infrastructure-${PROFILE}.yaml" ]; then
        log "Starting external infrastructure..."
        cd "$ROOT_DIR"
        docker-compose -f "templates/docker-compose/infrastructure-${PROFILE}.yaml" up -d
        sleep 10
    fi
    
    # Create KIND cluster
    log "Creating Kubernetes cluster..."
    if kind get clusters | grep -q "enterprise-devops-${PROFILE}"; then
        warn "Cluster enterprise-devops-${PROFILE} already exists, deleting..."
        kind delete cluster --name "enterprise-devops-${PROFILE}"
    fi
    
    kind create cluster --config "$ROOT_DIR/$CONFIG_FILE" --wait 5m
    
    # Apply resource limits
    log "Applying resource limits..."
    kubectl apply -f "$ROOT_DIR/templates/resource-limits/limitrange-${PROFILE}.yaml"
    kubectl apply -f "$ROOT_DIR/templates/resource-limits/resourcequota-${PROFILE}.yaml"
    kubectl apply -f "$ROOT_DIR/templates/resource-limits/networkpolicy-${PROFILE}.yaml"
    
    log "Infrastructure deployment complete!"
}

# Deploy monitoring stack
deploy_monitoring() {
    log "Deploying monitoring stack..."
    
    # Add Helm repositories
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    # Install kube-prometheus-stack
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --values "$ROOT_DIR/templates/helm-values/prometheus-${PROFILE}.yaml" \
        --wait
    
    log "Monitoring stack deployed!"
}

# Deploy GitOps
deploy_gitops() {
    log "Deploying GitOps stack..."
    
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update
    
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --values "$ROOT_DIR/templates/helm-values/argocd-${PROFILE}.yaml" \
        --wait
    
    log "GitOps stack deployed!"
}

# Main execution
main() {
    log "Starting deployment with ${PROFILE} profile..."
    check_prerequisites
    deploy_infrastructure
    deploy_monitoring
    deploy_gitops
    
    log "🎉 Enterprise DevOps Lab deployment complete!"
    log "Access your services:"
    log "  - Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    log "  - ArgoCD: kubectl port-forward -n argocd svc/argocd-server 8080:80"
    log "  - Prometheus: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
}

main "$@"
EOF

    # Replace template variables
    sed -i '' "s/{{PROFILE}}/$profile/g" "scripts/deployment/deploy-${profile}.sh"
    sed -i '' "s/{{CONFIG_FILE}}/$config_file/g" "scripts/deployment/deploy-${profile}.sh"
    chmod +x "scripts/deployment/deploy-${profile}.sh"
    
    # Cleanup script
    cat > "scripts/deployment/cleanup-${profile}.sh" << EOF
#!/bin/bash
set -euo pipefail

PROFILE="$profile"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "\${GREEN}[\$(date +'%H:%M:%S')]\${NC} \$1"; }
warn() { echo -e "\${YELLOW}[\$(date +'%H:%M:%S')] WARNING:\${NC} \$1"; }

log "Cleaning up \${PROFILE} profile deployment..."

# Delete KIND cluster
if kind get clusters | grep -q "enterprise-devops-\${PROFILE}"; then
    log "Deleting Kubernetes cluster..."
    kind delete cluster --name "enterprise-devops-\${PROFILE}"
fi

# Stop Docker Compose
if [ -f "templates/docker-compose/infrastructure-\${PROFILE}.yaml" ]; then
    log "Stopping external infrastructure..."
    docker-compose -f "templates/docker-compose/infrastructure-\${PROFILE}.yaml" down -v
fi

# Clean up Docker resources
log "Cleaning up Docker resources..."
docker system prune -f --volumes

log "🧹 Cleanup complete for \${PROFILE} profile!"
EOF

    chmod +x "scripts/deployment/cleanup-${profile}.sh"
    
    info "Generated deployment scripts for $profile profile"
}

# Main execution
main() {
    log "🚀 Enterprise DevOps Lab - Auto-Configuration System"
    log "Detecting system resources and generating optimal configuration..."
    
    # System detection
    local os=$(detect_os)
    local arch=$(detect_arch)
    local resources=($(get_system_resources))
    local memory_gb=${resources[0]}
    local cpu_cores=${resources[1]}
    local cpu_brand="${resources[2]} ${resources[3]:-} ${resources[4]:-}"
    
    log "System Information:"
    log "  - OS: $os"
    log "  - Architecture: $arch"
    log "  - Memory: ${memory_gb}GB"
    log "  - CPU Cores: $cpu_cores"
    log "  - CPU: $cpu_brand"
    
    # Calculate optimal configuration
    local config=($(calculate_resources $memory_gb $cpu_cores))
    local profile=${config[0]}
    local control_plane_nodes=${config[1]}
    local worker_nodes=${config[2]}
    local pod_memory_limit=${config[3]}
    local pod_cpu_limit=${config[4]}
    local max_pods=${config[5]}
    local kube_reserved_memory=${config[6]}
    local kube_reserved_cpu=${config[7]}
    local system_reserved_memory=${config[8]}
    local system_reserved_cpu=${config[9]}
    
    log "Optimal Configuration Profile: $profile"
    log "  - Control Planes: $control_plane_nodes"
    log "  - Workers: $worker_nodes"
    log "  - Pod Memory Limit: $pod_memory_limit"
    log "  - Pod CPU Limit: $pod_cpu_limit"
    log "  - Max Pods per Node: $max_pods"
    
    # Generate all configuration files
    log "Generating configuration files..."
    
    local kind_config=$(generate_kind_config \
        "$profile" "$control_plane_nodes" "$worker_nodes" \
        "$pod_memory_limit" "$pod_cpu_limit" "$max_pods" \
        "$kube_reserved_memory" "$kube_reserved_cpu" \
        "$system_reserved_memory" "$system_reserved_cpu")
    
    generate_resource_templates "$profile" "$pod_memory_limit" "$pod_cpu_limit"
    generate_helm_templates "$profile" "$pod_memory_limit" "$pod_cpu_limit"
    generate_docker_compose_templates "$profile" "$memory_gb"
    generate_deployment_scripts "$profile" "$kind_config"
    
    # Create system info file
    cat > "system-info-${profile}.json" << EOF
{
    "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
    "system": {
        "os": "$os",
        "architecture": "$arch",
        "memory_gb": $memory_gb,
        "cpu_cores": $cpu_cores,
        "cpu_brand": "$cpu_brand"
    },
    "profile": {
        "name": "$profile",
        "control_plane_nodes": $control_plane_nodes,
        "worker_nodes": $worker_nodes,
        "pod_memory_limit": "$pod_memory_limit",
        "pod_cpu_limit": "$pod_cpu_limit",
        "max_pods_per_node": $max_pods
    },
    "files_generated": {
        "kind_config": "$kind_config",
        "resource_templates": "templates/resource-limits/",
        "helm_values": "templates/helm-values/",
        "docker_compose": "templates/docker-compose/",
        "deployment_scripts": "scripts/deployment/"
    }
}
EOF
    
    log "✅ Configuration generation complete!"
    log ""
    log "📁 Generated Files:"
    log "  - KIND Config: $kind_config"
    log "  - Templates: templates/ directory"
    log "  - Scripts: scripts/deployment/"
    log "  - System Info: system-info-${profile}.json"
    log ""
    log "🚀 To deploy your lab:"
    log "  ./scripts/deployment/deploy-${profile}.sh"
    log ""
    log "🧹 To cleanup:"
    log "  ./scripts/deployment/cleanup-${profile}.sh"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
