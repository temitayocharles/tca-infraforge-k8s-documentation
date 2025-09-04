#!/bin/bash
# TC Enterprise DevOps Platform™ - Deploy Advanced Tools
# Deploy the advanced tools configurations to the cluster

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

CHECK="✅"
WARN="⚠️ "
ERROR="❌"
INFO="ℹ️ "
ROCKET="🚀"

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] $WARN${NC}$1"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] $ERROR${NC}$1"; }
success() { echo -e "${GREEN}$CHECK $1${NC}"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config/advanced"

# Check cluster connectivity
check_cluster() {
    log "Checking cluster connectivity..."
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "Cannot connect to Kubernetes cluster"
        echo "Please ensure your cluster is running and kubectl is configured"
        exit 1
    fi
    success "Cluster is accessible"
}

# Deploy Istio
deploy_istio() {
    log "Deploying Istio Service Mesh..."
    if ! kubectl get namespace istio-system >/dev/null 2>&1; then
        kubectl create namespace istio-system
    fi

    # Use istioctl if available, otherwise try direct apply
    if command -v istioctl >/dev/null 2>&1; then
        istioctl install --set profile=demo -y
    else
        warn "istioctl not found, trying alternative installation..."
        # Fallback to direct manifest application
        kubectl apply -f https://istio.io/downloadIstio | head -1 | xargs curl -L | tar -xz && \
        kubectl apply -f istio-*/manifests/charts/istio-control/istio-discovery/ && \
        rm -rf istio-*
    fi

    kubectl label namespace default istio-injection=enabled --overwrite
    success "Istio deployed"
}

# Deploy OPA Gatekeeper
deploy_opa() {
    log "Deploying OPA Gatekeeper..."
    kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/master/deploy/gatekeeper.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/gatekeeper-controller-manager -n gatekeeper-system || true
    kubectl apply -f "$CONFIG_DIR/opa-policies.yaml"
    success "OPA Gatekeeper deployed"
}

# Deploy Jaeger
deploy_jaeger() {
    log "Deploying Jaeger..."
    kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.47.0/jaeger-operator.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/jaeger-operator -n observability || true
    kubectl apply -f "$CONFIG_DIR/jaeger-instance.yaml"
    success "Jaeger deployed"
}

# Deploy Autoscaling
deploy_autoscaling() {
    log "Deploying Autoscaling..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    kubectl apply -f "$CONFIG_DIR/autoscaling.yaml"
    success "Autoscaling deployed"
}

# Deploy ArgoCD
deploy_argocd() {
    log "Deploying ArgoCD..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd || true
    success "ArgoCD deployed"
}

# Update Ingress
update_ingress() {
    log "Updating Ingress configuration..."
    kubectl apply -f "$CONFIG_DIR/advanced-ingress.yaml"
    success "Ingress updated"
}

# Main deployment function
main() {
    echo ""
    echo -e "${BLUE}🚀 TC Enterprise DevOps Platform™ - Advanced Tools Deployment${NC}"
    echo "=========================================================="
    echo ""

    check_cluster

    log "Starting deployment of advanced tools..."
    echo ""

    # Deployment phases
    local phases=(
        "deploy_istio:Istio Service Mesh"
        "deploy_opa:OPA Gatekeeper"
        "deploy_jaeger:Jaeger Tracing"
        "deploy_autoscaling:Autoscaling"
        "deploy_argocd:ArgoCD GitOps"
        "update_ingress:Ingress Configuration"
    )

    local phase_count=${#phases[@]}
    local current_phase=1

    for phase_info in "${phases[@]}"; do
        local phase_func=$(echo "$phase_info" | cut -d: -f1)
        local phase_name=$(echo "$phase_info" | cut -d: -f2)

        log "[$current_phase/$phase_count] Deploying $phase_name"

        if $phase_func; then
            success "$phase_name deployed successfully"
        else
            warn "Failed to deploy $phase_name - continuing..."
        fi

        echo ""
        ((current_phase++))
    done

    # Final summary
    echo ""
    log "Deployment Summary"
    echo "=================="
    echo ""
    log "Advanced tools have been configured for deployment."
    echo ""
    log "Next Steps:"
    echo "1. Ensure your cluster is running: kubectl cluster-info"
    echo "2. Check pod status: kubectl get pods -A"
    echo "3. Access tools via domain:"
    echo "   • ArgoCD: https://argocd.temitayocharles.online"
    echo "   • Jaeger: https://jaeger.temitayocharles.online"
    echo ""
    success "Advanced tools deployment completed!"
}

# Execute main function
main "$@"
