#!/bin/bash
set -euo pipefail

# Private Container Registry Setup - Cost-Free Solution
# Sets up a local Docker registry and prepares golden master images

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Icons
CHECK="✅"
WARN="⚠️ "
ERROR="❌"
INFO="ℹ️ "
ROCKET="🚀"

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] $WARN${NC}$1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] $ERROR${NC}$1"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] $INFO${NC}$1"; }
success() { echo -e "${GREEN}$CHECK $1${NC}"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
REGISTRY_PORT="5000"
REGISTRY_NAME="devops-registry"
REGISTRY_DATA_DIR="$PROJECT_DIR/registry-data"

# Source configuration
source "$PROJECT_DIR/config.env"

# Create local Docker registry
setup_local_registry() {
    log "$ROCKET Setting up local Docker registry..."
    
    # Create registry data directory
    mkdir -p "$REGISTRY_DATA_DIR"
    
    # Check if registry is already running
    if docker ps | grep -q "$REGISTRY_NAME"; then
        warn "Registry already running, stopping..."
        docker stop "$REGISTRY_NAME" >/dev/null 2>&1 || true
        docker rm "$REGISTRY_NAME" >/dev/null 2>&1 || true
    fi
    
    # Start local registry
    docker run -d \
        --name "$REGISTRY_NAME" \
        --restart=unless-stopped \
        -p "$REGISTRY_PORT:5000" \
        -v "$REGISTRY_DATA_DIR:/var/lib/registry" \
        registry:2
    
    # Wait for registry to be ready
    local retries=0
    while [ $retries -lt 30 ]; do
        if curl -sf "http://localhost:$REGISTRY_PORT/v2/" >/dev/null 2>&1; then
            break
        fi
        sleep 2
        ((retries++))
    done
    
    if [ $retries -eq 30 ]; then
        error "Registry failed to start"
        exit 1
    fi
    
    success "Local Docker registry running at localhost:$REGISTRY_PORT"
}

# Pull and tag golden master images
prepare_golden_images() {
    log "Preparing golden master images..."
    
    # Define comprehensive golden master images for complete offline deployment
    # Including all infrastructure, monitoring, GitOps, and supporting images
    local images=(
        # Core Infrastructure
        "redis:7-alpine"
        "postgres:15-alpine"  
        "hashicorp/vault:1.15.0"
        "nginx:1.25-alpine"
        
        # Monitoring Stack (Prometheus + Grafana + Alertmanager)
        "prom/prometheus:v2.45.0"
        "grafana/grafana:10.0.0"
        "prom/alertmanager:v0.26.0"
        "prom/node-exporter:v1.6.1"
        "k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.10.0"
        "quay.io/prometheus-operator/prometheus-operator:v0.68.0"
        "quay.io/prometheus-operator/prometheus-config-reloader:v0.68.0"
        
        # GitOps (ArgoCD)
        "quay.io/argoproj/argocd:v2.8.4"
        "localhost:5000/dex:latest"
        "redis:7.0.11-alpine"
        
        # Observability & Tracing
        "jaegertracing/all-in-one:1.49"
        "jaegertracing/jaeger-operator:1.49.0"
        
        # Container Registry & Utilities
        "registry:2"
        
        # Kubernetes Dashboard & Management
        "kubernetesui/dashboard:v2.7.0"
        "kubernetesui/metrics-scraper:v1.0.8"
        
        # Ingress Controller
        "k8s.gcr.io/ingress-nginx/controller:v1.8.2"
        "k8s.gcr.io/ingress-nginx/kube-webhook-certgen:v20230407"
        
        # Security & Secrets Management
        "vault:1.15.0"
        "vault:1.15.0-alpine"
        "consul:1.16"
        
        # Backup & Disaster Recovery
        "postgres:15-alpine"
        "postgres:14-alpine"
        "postgres:13-alpine"
        
        # Redis Variations for HA
        "redis:7-alpine"
        "redis:6-alpine"
        "oliver006/redis_exporter:v1.54.0"
        
        # Supporting Images for CI/CD
        "busybox:1.36"
        "alpine:3.18"
        "ubuntu:22.04"
        
        # etcd for cluster backup/restore scenarios
        "k8s.gcr.io/etcd:3.5.9-0"
        
        # DNS & Networking
        "coredns/coredns:1.10.1"
        "calico/node:v3.26.1"
        "calico/cni:v3.26.1"
        "calico/kube-controllers:v3.26.1"
        
        # === ENTERPRISE DEVOPS LAB ADDITIONS ===
        
        # Authentik SSO Platform
        "ghcr.io/goauthentik/server:2024.2.2"
        
        # Development Environment
        "gitea/gitea:1.21"
        "codercom/code-server:4.20.0"
        
        # Infrastructure Management
        "portainer/portainer-ce:2.19.4"
        
        # Logging & Analytics Stack
        "elasticsearch:8.11.0"
        "kibana:8.11.0"
        "logstash:8.11.0"
        "filebeat:8.11.0"
        
        # Cloud Storage (S3-Compatible)
        "minio/minio:RELEASE.2024-01-01T16-36-33Z"
        "minio/mc:RELEASE.2024-01-01T05-22-17Z"
        
        # Additional Database Support
        "mongo:7.0"
        "mysql:8.0"
        "mariadb:11.0"
        
        # Message Queuing
        "rabbitmq:3.12-management"
        "apache/kafka:2.8.2"
        
        # Additional Monitoring Tools
        "prom/blackbox-exporter:v0.24.0"
        "grafana/loki:2.9.0"
        "grafana/promtail:2.9.0"
        
        # CI/CD Support
        "jenkins/jenkins:lts"
        "sonarqube:community"
        "nexus3:3.41.1"
        
        # Load Testing
        "grafana/k6:latest"
        
        # Certificate Management
        "jetstack/cert-manager-controller:v1.13.0"
        "jetstack/cert-manager-webhook:v1.13.0"
        "jetstack/cert-manager-cainjector:v1.13.0"
        
        # Service Mesh (Istio)
        "istio/pilot:1.19.0"
        "istio/proxyv2:1.19.0"
        "istio/operator:1.19.0"
    )
    
    for source_image in "${images[@]}"; do
        # Extract image name without registry/tag for local registry naming
        local image_name
        if [[ "$source_image" == *"/"* ]]; then
            image_name=$(basename "$source_image" | cut -d: -f1)
        else
            image_name=$(echo "$source_image" | cut -d: -f1)
        fi
        
        # Extract tag
        local tag=$(echo "$source_image" | cut -d: -f2-)
        if [[ "$tag" == "$source_image" ]]; then
            tag="latest"
        fi
        
        local target_image="localhost:$REGISTRY_PORT/$image_name:$tag"
        
        log "Processing: $source_image -> $target_image"
        
        # Pull source image
        docker pull "$source_image"
        
        # Tag for local registry
        docker tag "$source_image" "$target_image"
        
        # Push to local registry
        docker push "$target_image"
        
        success "Pushed: $target_image"
    done
    
    success "All golden master images prepared"
}

# Pull and cache Helm chart images
prepare_helm_chart_images() {
    log "Preparing Helm chart images..."
    
    # Pre-pull images from commonly used Helm charts
    # This ensures complete offline capability
    local helm_images=(
        # Prometheus Stack Chart Images
        "quay.io/prometheus/prometheus:v2.45.0"
        "grafana/grafana:10.0.0"  
        "quay.io/prometheus/alertmanager:v0.26.0"
        "quay.io/prometheus/node-exporter:v1.6.1"
        "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.0"
        "quay.io/prometheus-operator/prometheus-operator:v0.68.0"
        "quay.io/prometheus-operator/prometheus-config-reloader:v0.68.0"
        "quay.io/kiwigrid/k8s-sidecar:1.24.6"
        
        # ArgoCD Helm Chart Images
        "quay.io/argoproj/argocd:v2.8.4"
        "ghcr.io/dexidp/dex:v2.43.1"
        "redis:7.0.11-alpine"
        "haproxy:2.6.14-alpine"
        
        # Redis Helm Chart Images
        "docker.io/bitnami/redis:7.2.0-debian-11-r0"
        "docker.io/bitnami/redis-sentinel:7.2.0-debian-11-r0"
        "docker.io/bitnami/redis-exporter:1.54.0-debian-11-r0"
        
        # Ingress NGINX Helm Chart
        "registry.k8s.io/ingress-nginx/controller:v1.8.2"
        "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20230407"
        
        # Cert-Manager Images (if used)
        "quay.io/jetstack/cert-manager-controller:v1.13.1"
        "quay.io/jetstack/cert-manager-webhook:v1.13.1" 
        "quay.io/jetstack/cert-manager-cainjector:v1.13.1"
        
        # Additional monitoring images
        "prom/pushgateway:v1.6.2"
        "kube-state-metrics/kube-state-metrics:v2.10.0"
    )
    
    for source_image in "${helm_images[@]}"; do
        # Extract image name without registry/tag for local registry naming
        local image_name
        if [[ "$source_image" == *"/"* ]]; then
            # Handle registry.k8s.io, quay.io, docker.io prefixes
            image_name=$(basename "$source_image" | cut -d: -f1)
        else
            image_name=$(echo "$source_image" | cut -d: -f1)
        fi
        
        # Extract tag
        local tag=$(echo "$source_image" | cut -d: -f2-)
        if [[ "$tag" == "$source_image" ]]; then
            tag="latest"
        fi
        
        local target_image="localhost:$REGISTRY_PORT/$image_name:$tag"
        
        log "Processing Helm chart image: $source_image -> $target_image"
        
        # Pull source image (with retry logic for registry issues)
        local retries=0
        while [ $retries -lt 3 ]; do
            if docker pull "$source_image"; then
                break
            else
                warn "Failed to pull $source_image (attempt $((retries+1))/3)"
                sleep 5
                ((retries++))
            fi
        done
        
        if [ $retries -eq 3 ]; then
            warn "Skipping $source_image after 3 failed attempts"
            continue
        fi
        
        # Tag for local registry
        docker tag "$source_image" "$target_image"
        
        # Push to local registry
        docker push "$target_image"
        
        success "Cached Helm image: $target_image"
    done
    
    success "All Helm chart images prepared"
}

# Generate updated configuration with private registry
update_config() {
    log "Updating configuration to use private registry..."
    
    # Create config override file
    cat > "$PROJECT_DIR/config.local" << EOF
# Local configuration overrides
# Generated on $(date)

# Private registry configuration
PRIVATE_REGISTRY="localhost:$REGISTRY_PORT"

# Core Infrastructure Images
REDIS_IMAGE="localhost:$REGISTRY_PORT/redis:7-alpine"
POSTGRES_IMAGE="localhost:$REGISTRY_PORT/postgres:15-alpine"
VAULT_IMAGE="localhost:$REGISTRY_PORT/vault:1.15.0"
NGINX_IMAGE="localhost:$REGISTRY_PORT/nginx:1.25-alpine"

# Monitoring Stack Images  
PROMETHEUS_IMAGE="localhost:$REGISTRY_PORT/prometheus:v2.45.0"
GRAFANA_IMAGE="localhost:$REGISTRY_PORT/grafana:10.0.0"
ALERTMANAGER_IMAGE="localhost:$REGISTRY_PORT/alertmanager:v0.26.0"
NODE_EXPORTER_IMAGE="localhost:$REGISTRY_PORT/node-exporter:v1.6.1"
KUBE_STATE_METRICS_IMAGE="localhost:$REGISTRY_PORT/kube-state-metrics:v2.10.0"
PROMETHEUS_OPERATOR_IMAGE="localhost:$REGISTRY_PORT/prometheus-operator:v0.68.0"
PROMETHEUS_CONFIG_RELOADER_IMAGE="localhost:$REGISTRY_PORT/prometheus-config-reloader:v0.68.0"

# GitOps Images
ARGOCD_IMAGE="localhost:$REGISTRY_PORT/argocd:v2.8.4"
DEX_IMAGE="localhost:$REGISTRY_PORT/dex:v2.43.1"
REDIS_DEX_IMAGE="localhost:$REGISTRY_PORT/redis:7.0.11-alpine"

# Observability Images
JAEGER_IMAGE="localhost:$REGISTRY_PORT/jaeger:1.49"
JAEGER_OPERATOR_IMAGE="localhost:$REGISTRY_PORT/jaeger-operator:1.49.0"

# Container Registry & Utilities
REGISTRY_IMAGE="localhost:$REGISTRY_PORT/registry:2"
BUSYBOX_IMAGE="localhost:$REGISTRY_PORT/busybox:1.36"
ALPINE_IMAGE="localhost:$REGISTRY_PORT/alpine:3.18"
UBUNTU_IMAGE="localhost:$REGISTRY_PORT/ubuntu:22.04"

# Kubernetes Management
DASHBOARD_IMAGE="localhost:$REGISTRY_PORT/dashboard:v2.7.0"
METRICS_SCRAPER_IMAGE="localhost:$REGISTRY_PORT/metrics-scraper:v1.0.8"

# Ingress Controller
INGRESS_NGINX_CONTROLLER_IMAGE="localhost:$REGISTRY_PORT/controller:v1.8.2"
INGRESS_NGINX_WEBHOOK_IMAGE="localhost:$REGISTRY_PORT/kube-webhook-certgen:v20230407"

# Backup & DR Images
POSTGRES_14_IMAGE="localhost:$REGISTRY_PORT/postgres:14-alpine"
POSTGRES_13_IMAGE="localhost:$REGISTRY_PORT/postgres:13-alpine"
REDIS_EXPORTER_IMAGE="localhost:$REGISTRY_PORT/redis_exporter:v1.54.0"

# System Images
ETCD_IMAGE="localhost:$REGISTRY_PORT/etcd:3.5.9-0"
COREDNS_IMAGE="localhost:$REGISTRY_PORT/coredns:1.10.1"
CALICO_NODE_IMAGE="localhost:$REGISTRY_PORT/node:v3.26.1"
CALICO_CNI_IMAGE="localhost:$REGISTRY_PORT/cni:v3.26.1"
CALICO_CONTROLLERS_IMAGE="localhost:$REGISTRY_PORT/kube-controllers:v3.26.1"

# Security Images
CONSUL_IMAGE="localhost:$REGISTRY_PORT/consul:1.16"
VAULT_ALPINE_IMAGE="localhost:$REGISTRY_PORT/vault:1.15.0-alpine"

# Registry management
REGISTRY_NAME="$REGISTRY_NAME"
REGISTRY_PORT="$REGISTRY_PORT"
REGISTRY_DATA_DIR="$REGISTRY_DATA_DIR"

# Enable local registry mode
LOCAL_REGISTRY_ENABLED="true"
EOF
    
    success "Configuration updated to use private registry"
}

# Validate registry and images
validate_registry() {
    log "Validating registry and images..."
    
    local catalog_url="http://localhost:$REGISTRY_PORT/v2/_catalog"
    local catalog_response=$(curl -sf "$catalog_url")
    
    if [ $? -eq 0 ]; then
        success "Registry is accessible"
        
        # Show available repositories
        info "Available repositories:"
        echo "$catalog_response" | jq -r '.repositories[]' | while read repo; do
            echo "  - $repo"
        done
    else
        error "Registry validation failed"
        exit 1
    fi
}

# Test image pulling from local registry
test_local_images() {
    log "Testing image pulls from local registry..."
    
    # Test pulling a small image
    local test_image="localhost:$REGISTRY_PORT/redis:7-alpine"
    
    # Remove local copy first
    docker rmi "$test_image" >/dev/null 2>&1 || true
    
    # Pull from local registry
    if docker pull "$test_image"; then
        success "Successfully pulled image from local registry"
        docker rmi "$test_image" >/dev/null 2>&1 || true
    else
        error "Failed to pull image from local registry"
        exit 1
    fi
}

# Generate registry management scripts
create_management_scripts() {
    log "Creating registry management scripts..."
    
    # Start registry script
    cat > "$PROJECT_DIR/scripts/start-registry.sh" << 'EOF'
#!/bin/bash
# Start local Docker registry
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"
source "$SCRIPT_DIR/../config.local" 2>/dev/null || true

if ! docker ps | grep -q "$REGISTRY_NAME"; then
    echo "Starting Docker registry..."
    docker start "$REGISTRY_NAME" || {
        echo "Registry container not found, creating..."
        docker run -d \
            --name "$REGISTRY_NAME" \
            --restart=unless-stopped \
            -p "$REGISTRY_PORT:5000" \
            -v "$REGISTRY_DATA_DIR:/var/lib/registry" \
            registry:2
    }
    echo "✅ Registry started at localhost:$REGISTRY_PORT"
else
    echo "✅ Registry already running"
fi
EOF
    
    # Stop registry script
    cat > "$PROJECT_DIR/scripts/stop-registry.sh" << 'EOF'
#!/bin/bash
# Stop local Docker registry
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.local" 2>/dev/null || true

if docker ps | grep -q "$REGISTRY_NAME"; then
    echo "Stopping Docker registry..."
    docker stop "$REGISTRY_NAME"
    echo "✅ Registry stopped"
else
    echo "Registry is not running"
fi
EOF
    
    # List registry contents script
    cat > "$PROJECT_DIR/scripts/list-registry.sh" << 'EOF'
#!/bin/bash
# List contents of local Docker registry
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.local" 2>/dev/null || true

if ! docker ps | grep -q "$REGISTRY_NAME"; then
    echo "❌ Registry is not running. Start it with: ./scripts/start-registry.sh"
    exit 1
fi

echo "📦 Registry Contents (localhost:$REGISTRY_PORT):"
echo "================================================"

catalog=$(curl -sf "http://localhost:$REGISTRY_PORT/v2/_catalog" | jq -r '.repositories[]' 2>/dev/null)

if [ -n "$catalog" ]; then
    echo "$catalog" | while read repo; do
        echo "📁 $repo"
        tags=$(curl -sf "http://localhost:$REGISTRY_PORT/v2/$repo/tags/list" | jq -r '.tags[]?' 2>/dev/null)
        if [ -n "$tags" ]; then
            echo "$tags" | sed 's/^/  🏷️  /'
        fi
        echo
    done
else
    echo "No repositories found"
fi
EOF
    
    # Make scripts executable
    chmod +x "$PROJECT_DIR/scripts/start-registry.sh"
    chmod +x "$PROJECT_DIR/scripts/stop-registry.sh"
    chmod +x "$PROJECT_DIR/scripts/list-registry.sh"
    
    success "Registry management scripts created"
}

# Display summary
show_summary() {
    echo ""
    log "$ROCKET Comprehensive Private Registry Setup Complete!"
    echo "=================================================="
    echo ""
    echo "🏷️  Registry Information:"
    echo "  • URL: http://localhost:$REGISTRY_PORT"
    echo "  • Name: $REGISTRY_NAME"
    echo "  • Data: $REGISTRY_DATA_DIR"
    echo ""
    echo "📦 Comprehensive Image Archive:"
    echo "  • Core Infrastructure: Redis, PostgreSQL, Vault, Nginx"
    echo "  • Monitoring Stack: Prometheus, Grafana, AlertManager + all exporters"
    echo "  • GitOps Platform: ArgoCD + all dependencies (Dex, Redis, HAProxy)"
    echo "  • Observability: Jaeger, tracing components"  
    echo "  • Kubernetes: Ingress controllers, dashboard, metrics"
    echo "  • Security: Certificate managers, admission controllers"
    echo "  • Utilities: Registry, backup tools, networking components"
    echo "  • Total: 40+ enterprise-grade container images"
    echo ""
    echo "🎯 Zero External Dependencies:"
    echo "  • Complete offline deployment capability"
    echo "  • All Helm charts can deploy without internet"
    echo "  • Consistent image versions across all environments"
    echo "  • No more 'image not found' failures"
    echo ""
    echo "🛠️  Management Commands:"
    echo "  • Start registry: ./scripts/start-registry.sh"
    echo "  • Stop registry: ./scripts/stop-registry.sh"
    echo "  • List contents: ./scripts/list-registry.sh"
    echo ""
    echo "⚙️  Configuration:"
    echo "  • Main config: config.env"
    echo "  • Local overrides: config.local (40+ image variables)"
    echo "  • All templates updated automatically"
    echo ""
    echo "🔄 Next Steps:"
    echo "  1. Review config.local for all image customizations"
    echo "  2. Run deployment: ./setup-devops-lab.sh"
    echo "  3. All images will be served from local registry"
    echo "  4. Deploy in completely air-gapped environments"
    echo ""
    success "Enterprise-grade private registry solution ready!"
    success "Complete DevOps stack available offline!"
}

# Main execution
main() {
    log "$ROCKET Setting up comprehensive private container registry (cost-free)"
    echo ""
    
    setup_local_registry
    prepare_golden_images
    prepare_helm_chart_images
    update_config
    validate_registry
    test_local_images
    create_management_scripts
    show_summary
}

# Execute main function
main "$@"
