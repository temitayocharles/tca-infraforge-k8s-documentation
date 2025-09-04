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
